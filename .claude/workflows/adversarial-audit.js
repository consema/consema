export const meta = {
  name: 'adversarial-audit',
  description: '全仓全内容对抗性正反对打：9 镜头穷尽攻击 → 逐条辩护复验 → loop-until-dry 打不穿才停',
  phases: [
    { title: 'Load', detail: 'stateFile 持久化状态加载（跨轮去重上下文，可选）' },
    { title: 'Attack', detail: '9 镜头并行穷尽渗透（六仓 + 跨仓交叉 + 伪证伪门禁 + 逻辑安全可复现）' },
    { title: 'Verify', detail: '每条 fresh 发现独立辩护复验，打不掉的进确认集' },
  ],
}
// 对抗性审计工作流：全仓全内容正反对打，直到打不穿。
// 每轮循环常设阶段（stability-standard 记忆）。用法：
//   Workflow({ name: 'adversarial-audit', args: {
//     repos: [{name:'consema', path:'C:\\Users\\franck\\Documents\\consema'}, ... 六仓],
//     knownFindings: [{repo, file, line, severity, element, claim, evidence}],  // 已确认清单（历史轮）
//     seen: [key...],  // 全部已见 key（去重集）
//     dryTarget: 3     // 连续几轮零新确认视为打不穿
//   }})
// 返回 { confirmed, seen, rounds }。
//   —— 跨轮续打（持久化状态，推荐）：args 加 stateFile 指向 loop-state JSON
//      （含 confirmed/seen 两键）。脚本启动时 spawn 一个 loader agent 读取该文件、
//      把 confirmed 归并为模式组级 knownFindings（跨轮去重上下文），seen 留空由
//      运行内自建。args.knownFindings 显式传入时优先于 stateFile。
//   —— 已知限制：Workflow args 为内联 JSON，大型清单无法直接内联（约 200KB 上限
//      之下没问题）；超过则走 stateFile。
//
// —— 已验证调用方式（2026-08-13 C8 收尾阶段实测）——
//   (a) 通过 Skill（adversarial-audit）入口调用（本机验证可用）。
//   (b) Workflow 工具用内联 script 参数：本文件内容即权威脚本，可直接整体复制为
//       Workflow({ script: '<本文件全文>', args: {...} }) 内联脚本，或经 scriptPath 重放本文件。
//   注：「Workflow 按 name 调用在本机曾报 export 解析错误，未采用」——上方按 name
//       示例仅作 API 形状参考，未验证。

// 每个 attack prompt 需要的仓库清单文本
function repoListText(repos) {
  return repos.map(r => `- ${r.name}: ${r.path}`).join('\n')
}

function keyOf(f) {
  return `${f.repo}|${f.file}|${f.line}|${String(f.claim).slice(0, 80)}`
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          repo: { type: 'string', description: '仓库名（consema/consema-rs/consema-go/consema-ts/consema-py/consema-kt）' },
          file: { type: 'string', description: '仓库内相对路径' },
          line: { type: 'number', description: '锚定行号（无法精确定位给 0）' },
          severity: { type: 'string', enum: ['P0', 'P1', 'P2'] },
          element: { type: 'string', description: '违反维度：哲学统一/语义一致/逻辑自洽/真实有效/完整可靠/稳' },
          claim: { type: 'string', description: '问题描述（声称 vs 现实的矛盾点）' },
          evidence: { type: 'string', description: '实证：文件内容引用或你实测的命令输出（必须可复核）' },
        },
        required: ['repo', 'file', 'line', 'severity', 'element', 'claim', 'evidence'],
      },
    },
  },
  required: ['findings'],
}

const STATE_SCHEMA = {
  type: 'object',
  properties: {
    groups: {
      type: 'array',
      description: '历史确认集的模式组级去重上下文（≤60 组，每组一个根因一行）',
      items: {
        type: 'object',
        properties: {
          repo: { type: 'string', description: '主要涉及的仓库名（consema/consema-rs/consema-go/consema-ts/consema-py/consema-kt/cross）' },
          severity: { type: 'string', description: '组内最高 severity' },
          claim: { type: 'string', description: '根因一句话（含处置状态：已修复/文档化/遗留）' },
        },
        required: ['repo', 'claim'],
      },
    },
    notDry: { type: 'boolean', description: '历史波次是否未打穿' },
  },
  required: ['groups'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean', description: 'true=能实证反驳该发现（不是真问题）；false=不能反驳（发现成立或无法排除）' },
    reason: { type: 'string' },
    evidence: { type: 'string', description: '反驳或确认的实证依据' },
  },
  required: ['refuted', 'reason', 'evidence'],
}

// ── 9 镜头 ────────────────────────────────────────────────────────────────
const COMMON_RULES = `
对抗规则：
1) 穷尽挑错——你想到的任何角度都打：事实错误、自相矛盾、伪造声称、死引用/幻影文件、伪门禁/伪通过、静默 skip、逻辑漏洞、边界条件、时序依赖、竞态、非确定性、环境耦合、不可复现证据、跨仓不一致、单语言偏向、陈旧措辞、行号引用失效、占位符/残留。
2) 每条必须 file:line 锚定 + 实证（引用文件原文或你实测的命令输出，必须能让辩护方复核）。无法定位给 0 行。
3) 只报新问题：seen 集已覆盖的不要重复报（同 file:line 同 claim 实质）。若你的角度与已知发现相关但实质不同（不同位置/不同矛盾），可以报。
4) severity：P0=阻止 1.0.0 的事实错误/自相矛盾/必失败流程；P1=应修；P2=轻微。
5) 可以读任何文件、跑只读命令（git log/ls/test 等）验证。禁止修改任何文件。
6) 找不到问题也要尽力：宁可多报可疑点（辩护方会复核），不可漏报。`

function attackPrompt(args, lens) {
  return `${lens.brief}

六仓（目标范围）：\n${repoListText(args.repos)}

已确认发现清单（不要重复这些，但可以攻击它们的同类问题在其他位置的实例）：
${args.knownFindings.map(f => `- [${f.severity || '—'}] ${f.repo}${f.file ? ':' + f.file : ''}${f.line ? ':' + f.line : ''} ${f.claim}`).join('\n') || '(空)'}

已见 key 集（与上面清单对应，用于去重；不要产出 key 与之相同的发现）：
${args.seen.map(k => `- ${k}`).join('\n') || '(空)'}

${COMMON_RULES}`.trim()
}

const LENSES = [
  {
    key: 'doc-master',
    brief: `镜头 1/9「母仓文档·规范·证据权威」：审计母仓 ${'consema'} 的全部文档内容——路线图、配置标准、RFC、fc-manifest、rc/soak/evidence 文档、CHANGELOG、CONTRIBUTING/RELEASING/SECURITY/support-policy、conformance/ 下全部、docs-site/、five-element-review 审计记录。穷尽找：版本/计数/digest/状态/日期自相矛盾（508 vs 519 类）、行号引用失效（含拆仓后行号偏移）、声称"已清零/已闭环"但实际残留、证据死链（commit SHA 不存在）、RFC 状态与冻结声明矛盾、单语言偏向（五语言同等地位违反）、路径归属陈旧（六仓拆分布局 vs 旧单仓路径）。`,
  },
  {
    key: 'repo-rs',
    brief: `镜头 2/9「consema-rs 仓全内容」：源码、测试、Cargo.toml 元数据、CI、fuzz 驱动（run_waves.ps1/ledger 指向母仓）、vendored conformance、README/CHANGELOG/SECURITY。穷尽找：事实与代码矛盾、伪门禁、死引用、版本/计数不一致、log 声称 vs 实际、环境耦合、非确定性测试、硬编码路径。`,
  },
  {
    key: 'repo-go',
    brief: `镜头 3/9「consema-go 仓全内容」：源码、测试（21 包）、ci-go.yml/release.yml、.gitignore（注意 go/conformance/** 是否被吞）、scripts/go-verify-*.ps1、README/CHANGELOG/SECURITY（注意 Rust 侧事实冒充）、go.mod、fuzz targets。穷尽找：伪门禁（gofmt -l 类）、干净 clone 可跑性、case 数守卫口径不一、死引用、版本一致性门禁缺口、跨仓路径陈旧（crates/ 引用）。`,
  },
  {
    key: 'repo-ts',
    brief: `镜头 4/9「consema-ts 仓全内容」：package.json/tsconfig/engines、src 全部 TS、npm 脚本、ci-typescript.yml/release.yml（注意 release 无 conformance provision 的必败问题是否已修）、scripts/ts-verify-*.ps1、README/CHANGELOG/SECURITY、typescript/README（"完整签名见此处"是否兑现）、runner.ts CLI 检测脆弱性、zero-dep 断言步骤。`,
  },
  {
    key: 'repo-py',
    brief: `镜头 5/9「consema-py 仓全内容」：pyproject.toml、src 全部 .py、pytest 套件、ci-python.yml（provision 复制粘贴、checkout 未钉 ref）、scripts/python-verify-*.ps1、README/CHANGELOG/SECURITY、BOM 残留、runner CLI 双 import warning、wheel 断言。`,
  },
  {
    key: 'repo-kt',
    brief: `镜头 6/9「consema-kt 仓全内容」：build.gradle.kts/gradle 配置、src 全部 Kotlin、生成 runner（519 套件）、ci-kotlin.yml（外部下载无校验和、job 名虚标、行号引用）、scripts/kotlin-verify-*.ps1、README/CHANGELOG/SECURITY（Rust 拷贝残留）、TestShim 死件、wrapper 双供给路径、README 快速开始未门禁。`,
  },
  {
    key: 'cross-repo',
    brief: `镜头 7/9「跨仓交叉一致性」：六仓互查——同一事实在六仓的表述必须一致：版本号（1.0.0-rc.1）、case 数 519/18 套、digest cfd6e296da5b…、差分 68/108/83、registry 8/16/21/16/187、CI job 数/名称、README 声称的 job 与各仓 ci.yml 实际定义、CHANGELOG 引用的 commit SHA 在他仓是否存在、SECURITY 声明（五仓是否还有 Rust 事实冒充）、路径归属（crates/、go/、python/、typescript/、kotlin/ 前缀是否该有）、版本统一政策（ts/py 0.14.0 残留）、门禁归属（母仓 vs 语言仓）。母仓 conformance 是唯一权威——任何语言仓自称权威/引用旧清单都是发现。`,
  },
  {
    key: 'fake-gates',
    brief: `镜头 8/9「伪证与伪门禁专打」：专找"声称存在但不存在/不可验证/永远不会红"的东西——(a) 伪门禁：退出码恒 0 的检查、断言不严、静默 skip 无提示、skip 通道复验器、condition 永不成立、死守卫正则；(b) 伪证据：不存在的文件/commit/路径被引用、不可复算的数字、声称"实测"但无依据、证据链断；（c) 幻影文件：CI 注释引用未落地的脚本/产物；（d) 伪通过：npm ls 在无 package.json 目录、gitignore 吞新文件、错误目录执行。六个仓全打。`,
  },
  {
    key: 'logic-sec-repro',
    brief: `镜头 9/9「逻辑·安全·可复现专打」：(a) 逻辑：脚本/CI/流程的边界条件、时序依赖、竞态、幂等性、失败路径处理（错误后是否继续）、exit code 检查；（b) 安全：依赖面（Cargo.lock/npm audit/pip-audit/gradle 声明 vs 实际）、外部输入处理、无校验和下载、证书/密钥处理、SECURITY.md 声称 vs 实际门禁；（c) 可复现：干净 checkout 能重放吗（未 provision 兄弟仓数据时）、硬编码本机路径、环境变量覆盖完整吗、非确定性（Math.random/Date.now/时间依赖测试）、并发 fuzz 账本一致性。六个仓全打。`,
  },
]

// ── 主流程：loop-until-dry ────────────────────────────────────────────────
async function run(args) {
  const seen = new Set(args.seen || [])
  const confirmed = []
  let dryStreak = 0
  let round = 0
  const dryTarget = args.dryTarget || 3
  const maxRounds = 12

  // 历史确认集（跨轮去重上下文）：显式传入优先；否则走 stateFile 加载
  let known = (args.knownFindings || []).slice()
  if (!known.length && args.stateFile) {
    log(`loading persisted state: ${args.stateFile}`)
    const st = await agent(`你是持久化审计状态的加载 agent。读取状态文件 ${args.stateFile}（JSON，含 confirmed 数组与 seen 数组——confirmed 是上一波已确认并已处置的发现）。任务：把 confirmed 归并成 ≤60 个模式根因组，作为本轮攻击者的「已确认清单」去重上下文。规则：同一根因的多实例并成一组；每组 repo 填主要涉及仓（多仓填 cross）、severity 填组内最高、claim 一句话写明根因+处置状态（已修复/文档化/遗留）。只读文件，禁止修改任何东西。`, {
      label: 'load:state', phase: 'Load', schema: STATE_SCHEMA, effort: 'low',
    })
    if (st && st.groups && st.groups.length) { known = st.groups; log(`state loaded: ${known.length} groups`) }
    else { log('state load returned nothing — starting without historical context') }
  }

  while (dryStreak < dryTarget && round < maxRounds) {
    round += 1
    log(`round ${round}: ${LENSES.length} 镜头攻击中（已确认 ${confirmed.length}，seen ${seen.size}）`)

    const roundArgs = { ...args, knownFindings: known.concat(confirmed), seen: [...seen] }
    const attacked = await parallel(LENSES.map(lens => () =>
      agent(attackPrompt(roundArgs, lens), {
        label: `attack:${lens.key}`,
        phase: 'Attack',
        schema: FINDINGS_SCHEMA,
        effort: 'high',
      }).then(r => ({ lens: lens.key, result: r }))
    ))

    const all = attacked.filter(Boolean).flatMap(x => (x.result && x.result.findings ? x.result.findings.map(f => ({ ...f, lens: x.lens })) : []))
    const fresh = all.filter(f => !seen.has(keyOf(f)))
    fresh.forEach(f => seen.add(keyOf(f)))
    log(`round ${round}: 攻击共报 ${all.length}，fresh ${fresh.length}`)

    if (!fresh.length) { dryStreak += 1; continue }

    const judged = await parallel(fresh.map(f => () =>
      agent(verifyPrompt(f, args), {
        label: `verify:${f.repo}:${f.file}:${f.line}`,
        phase: 'Verify',
        schema: VERDICT_SCHEMA,
        effort: 'high',
      }).then(v => ({ f, v }))
    ))

    const survivors = judged.filter(j => j.v && !j.v.refuted).map(j => ({ ...j.f, verdict: j.v }))
    survivors.forEach(s => confirmed.push(s))
    if (survivors.length) { dryStreak = 0 } else { dryStreak += 1 }
    log(`round ${round}: 确认 ${survivors.length} 条（累计 ${confirmed.length}），dryStreak ${dryStreak}/${dryTarget}`)
  }

  return { confirmed, seen: [...seen], rounds: round, dryStreak }
}

function verifyPrompt(f, args) {
  return `你是辩护方复验 agent。目标：实证核查下面这条对抗性发现是否成立。可以读文件、跑只读命令（git log/ls/test 等），禁止修改任何文件。

发现：
- repo: ${f.repo}（路径：${args.repos.find(r => r.name === f.repo)?.path || '未知，从母仓反查'}）
- file: ${f.file}（若 line 给 0 表示未锚定行号）
- line: ${f.line}
- severity: ${f.severity}（${f.element}）
- claim: ${f.claim}
- evidence: ${f.evidence}

辩护规则：
1) 逐项实证：去对应仓库打开文件、核对 claim 与 evidence 是否属实；需要复算/复跑的数字（digest、计数、退出码）实际验算。
2) 只有你能**实证反驳**（证明该发现所指的"问题"实际不存在/不成立/已被修好）才 refuted=true，reason 写明你的实证依据。
3) 无法排除、无法完全证实、或 claim 中的矛盾点确实存在，一律 refuted=false（发现成立），reason 写明你的核查过程与确认依据。
4) 特别小心：如果 claim 指出的是"伪门禁/伪通过/静默 skip"，请实际检查该处代码/CI 步骤的执行语义，不要只信注释。
5) 证据不足时倾向保留发现（refuted=false）——打不掉的才留，但理由必须真实。`
}

const result = await run(args)
log(`对抗结束：${result.rounds} 轮，确认 ${result.confirmed.length} 条，dryStreak ${result.dryStreak}/${args.dryTarget || 3}`)
return result
