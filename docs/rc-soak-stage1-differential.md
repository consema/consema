# RC soak 阶段 1 — 五语言 differential 追加运行流程

- 依据：`docs/rc-1.0.0-candidate.md` §4 阶段 1（"双语言 differential corpus 追加运行
  §17.4"）与 §4.1（P2-7：四 harness 已复跑 83/83+108/108+68/68，**追加 corpus 待 C-2
  关账后随收口执行**）；`docs/five-language-ci-design.md` §3（差分 harness 五语言扩展）
  与 §10（实施实况）；`docs/six-repo-split-2026-08-12.md` §2/§6（六仓布局与
  conformance 仲裁层）。
- 目标：五语言差分 harness 在 RC soak 阶段的**追加运行**——C-2 关账后一键重跑
  全部 12 个 verify 脚本，验证五语言与 Rust 锚的全部差分面（字节 parity /
  normalized 双向 / protocol exchange 双向）在当前 release-candidate 代码状态下
  依然全绿，并记录结果。
- **本手册只含流程与记录模板；执行本身不在本准备批次内。**

## 1. 六仓检出布局（跨仓 checkout 说明）

本机六仓并排检出（six-repo-split-2026-08-12.md §1）：`C:\Users\franck\Documents\`
下六个仓库：

| 仓库 | 角色 | 关键路径（检出根下） |
|---|---|---|
| `consema`（母仓） | 规范/conformance 仲裁/证据权威 | `conformance/`（vectors 18 套 508 cases、fixtures、corpora、**differential case 集单一权威**）、`docs/fc-manifest-0.13.0.json` |
| `consema-rs` | Rust 参考实现（差分 Rust 锚侧） | `Cargo.toml`（workspace 根）、`consema-conformance/`（四个 emit 例子）、`target/` |
| `consema-go` | Go 实现 | `go/`、`scripts/go-verify-*.ps1` |
| `consema-ts` | TypeScript 实现 | `typescript/`、`scripts/ts-verify-*.ps1` |
| `consema-py` | Python 实现 | `python/`、`scripts/python-verify-*.ps1` |
| `consema-kt` | Kotlin 实现 | `kotlin/`、`scripts/kotlin-verify-*.ps1` |

要点：

- **case 集单一权威** = 母仓 `conformance/differential/`：`cases.json`（byte-parity 68）、
  `normalized/cases.json`（108）、`protocol-exchange/cases.json`（83）
  （five-language-ci-design.md §3.5，2026-08-12 迁移；母仓与 consema-rs 的
  conformance/ 内容逐字节一致——母仓维护、consema-rs 镜像快照，本机实测
  `cases.json` 0 差异）。
- **Rust 锚侧** = `consema-rs` 检出：四个 Rust 例子
  （`emit_parity_bytes.rs` / `emit_normalized_results.rs` / `emit_protocol_exchange.rs`
  / `emit_conformance_reports.rs`，`consema-conformance/examples/`）只消费 case 文件
  与输出目录，语言无关。
- **母仓 `scripts/` 下仍保留拆分前的 12 个 verify 脚本**（引用 `go/`、`typescript/`、
  `kotlin/`、`crates/consema-conformance/` 等已不存在路径，不可运行）——**执行一律用
  各语言仓自带的 `scripts/L-verify-*.ps1`**（拆分批次已适配多仓模式，新增
  `-RustWorkspace` 参数）。

## 2. 前置条件

| 项 | 要求 |
|---|---|
| 六仓检出 | §1 布局齐全；各语言仓工作树干净（`git status` 无本地改动） |
| 工具链 | cargo（或 `$env:CONSEMA_CARGO`）、go、node（或 `$env:CONSEMA_NODE`）、python 3.12（或 `$env:CONSEMA_PYTHON`）、JDK 17 + kotlinc（或 `$env:CONSEMA_JAVA_HOME` / `$env:CONSEMA_KOTLINC`，默认 `C:\Users\franck\tools\jdk17\jdk-17.0.20+8` / `C:\Users\franck\kotlinc\kotlinc`） |
| pwsh | Windows PowerShell 5.1 或 pwsh 均可（脚本兼容） |
| 环境 | 与 fuzz 驱动错峰（本机 24/7 驱动占 CPU；C-2 关账后执行最干净） |

## 3. 执行流程（每个语言仓）

### 3.1 provision 语言无关数据（照 CI 多仓 checkout 模式）

CI 的 `go-differential` / `ts-differential` / `python-differential` /
`kotlin-differential` job（各仓 ci-*.yml）的模式：把规范仓的 `conformance/` 与
`docs/fc-manifest-0.13.0.json` 复制进语言仓工作树根——语言侧测试与 verify 脚本
按仓库相对路径解析。本地等价步骤（对每个语言仓 L）：

```powershell
$spec = 'C:\Users\franck\Documents\consema'           # 规范仓（单一权威）
$lang = 'C:\Users\franck\Documents\consema-go'        # 依次换 go/ts/py/kt
Copy-Item -LiteralPath "$spec\conformance" -Destination "$lang\conformance" -Recurse -Force
New-Item -ItemType Directory -Force "$lang\docs" | Out-Null
Copy-Item -LiteralPath "$spec\docs\fc-manifest-0.13.0.json" `
          -Destination "$lang\docs\fc-manifest-0.13.0.json" -Force
```

注意：provision 产物是副本（一次性、可随时重建）；跑完后
`git -C $lang clean -fd conformance` 或留待下次刷新均可，**不得提交**。
不 provision 时脚本默认路径失败——这正是 CI 已修复的时序坑
（six-repo-split-2026-08-12.md §4 根因 1），手册如实要求先 provision。

### 3.2 运行 12 个 verify 脚本

每个脚本必须显式传 `-RustWorkspace`（本地并排布局下默认值
`<语言仓>\consema-rs` 不存在；CI 里它是嵌套 checkout，本地是并排检出）：

```powershell
# 每个语言仓、每个脚本一次；-RustWorkspace 指向并排的 consema-rs 检出
& "$lang\scripts\go-verify-byte-parity.ps1"            -RustWorkspace 'C:\Users\franck\Documents\consema-rs'
& "$lang\scripts\go-verify-normalized-differential.ps1" -RustWorkspace 'C:\Users\franck\Documents\consema-rs'
& "$lang\scripts\go-verify-protocol-exchange.ps1"       -RustWorkspace 'C:\Users\franck\Documents\consema-rs'
# （ts/python/kotlin 同构，脚本名前缀相应替换）
```

全量清单（12 个脚本 × 各 1 次 = 12 次执行）：

| 语言仓 | byte parity | normalized differential | protocol exchange |
|---|---|---|---|
| consema-go | `go-verify-byte-parity.ps1` | `go-verify-normalized-differential.ps1` | `go-verify-protocol-exchange.ps1` |
| consema-ts | `ts-verify-byte-parity.ps1` | `ts-verify-normalized-differential.ps1` | `ts-verify-protocol-exchange.ps1` |
| consema-py | `python-verify-byte-parity.ps1` | `python-verify-normalized-differential.ps1` | `python-verify-protocol-exchange.ps1` |
| consema-kt | `kotlin-verify-byte-parity.ps1` | `kotlin-verify-normalized-differential.ps1` | `kotlin-verify-protocol-exchange.ps1` |

每个脚本的内部流水线（照各脚本头部注释与 CI job 语义）：

1. 布局 sanity → case 集校验（manifest id + 计数 ≥40 下限；精确计数 68/108/83
   由语言侧完整性测试断言）→ `cargo build --locked -p consema-conformance --example …`
   （在 consema-rs 内，swatinem/rust-cache 等价于本地增量）→ Rust 例子 emit →
   语言侧测试/运行器在 golden 环境变量就位时执行（缺变量 documented skip）→
   reverse 方向闭合（normalized `--consume`、exchange `--verify`）→ summary 行解析。
2. **必须断言"RUN 而非 SKIP"**（脚本内已实现；SKIP 即红）。

### 3.3 预期断言（全部脚本统一）

| 断言 | 预期 |
|---|---|
| byte parity summary | `byte parity: 68/68 equal (51 pvce, 17 pgce)` |
| normalized differential | forward `normalized-result differential: 108/108 equal`；reverse `reverse normalized-result differential: 108/108 equal` |
| protocol exchange | `protocol exchange: 40/40 accept cases and 43/43 reject cases verified`（合计 83/83） |
| 退出码 | 每个脚本 exit 0 |
| 完整性测试 | case 计数精确 68/108/83（单文件五处共钉，任何漂移即红，five-language-ci-design.md §3.5） |

### 3.4 分歧处置（§11.3 流程，禁止静默修复）

任何方向的分歧 = 发现：最小跨语言反例 → 按 roadmap §11.3 分类
（实现/测试/规范缺口）→ 语言无关 case 追加到母仓 `conformance/differential/`
对应 case 文件（追加纪律：schema 同既有条目、manifest id 不变、计数下限保持）→
语言无关缺陷（真 bug）另进 `conformance/corpora/mutation-v1.json` 的 `regressions`
数组（工作流照 conformance/corpora/README.md）。**绝不静默改 Rust 侧掩盖。**

## 4. 结果记录模板

```markdown
## RC soak 阶段 1 — differential 追加运行记录（YYYY-MM-DD）

- 环境：<机器/OS>；六仓 HEAD：consema <commit> / consema-rs <commit> /
  consema-go <commit> / consema-ts <commit> / consema-py <commit> / consema-kt <commit>；
  工具链：cargo <ver> / go <ver> / node <ver> / python <ver> / kotlinc <ver>+JDK <ver>
- 前置：provision conformance/ + fc-manifest 至各语言仓根（§3.1）；fuzz 驱动关账状态：<…>

| 语言 | 脚本 | 结果（exit / summary 行） |
|---|---|---|
| go | go-verify-byte-parity.ps1 | exit 0 / byte parity: 68/68 equal (51 pvce, 17 pgce) |
| go | go-verify-normalized-differential.ps1 | exit 0 / 108/108 forward + 108/108 reverse |
| go | go-verify-protocol-exchange.ps1 | exit 0 / 40/40 accept + 43/43 reject |
| ts | ts-verify-byte-parity.ps1 | exit 0 / … |
| ts | ts-verify-normalized-differential.ps1 | … |
| ts | ts-verify-protocol-exchange.ps1 | … |
| py | python-verify-byte-parity.ps1 | … |
| py | python-verify-normalized-differential.ps1 | … |
| py | python-verify-protocol-exchange.ps1 | … |
| kt | kotlin-verify-byte-parity.ps1 | … |
| kt | kotlin-verify-normalized-differential.ps1 | … |
| kt | kotlin-verify-protocol-exchange.ps1 | … |

- 差异/发现：<无，或逐条列：case id + 两侧值 + 分类 + 处置>
- 结论：五语言差分面在 1.0.0-rc.1 候选代码状态下全部一致（或列出未闭项）
```

诚实记录体例：只记实际输出；summary 行以脚本 stdout 原样粘贴；任何脚本
非零退出或 SKIP 视为未过，记录实际错误后按 §3.4 处置，不重跑掩盖。

## 5. 相关文件

- `docs/five-language-ci-design.md` §3/§10（harness 语义、CI 实况）
- `docs/six-repo-split-2026-08-12.md` §2/§6（六仓布局、conformance 仲裁层、多仓 checkout 模式）
- `docs/rc-1.0.0-candidate.md` §4.1（P2-7 基线：83/83+108/108+68/68）
- 各语言仓 `scripts/L-verify-*.ps1`（执行载体）
- 母仓 `conformance/differential/`（case 集单一权威）
