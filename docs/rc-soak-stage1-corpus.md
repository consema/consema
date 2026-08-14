# RC soak 阶段 1 — 每格式真实 corpus 抽检巡检流程

- 依据：`docs/rc-1.0.0-candidate.md` §4 阶段 1（"每格式真实 corpus 抽检巡检
  §22.7"）与 §4.1（2026-08-10 已完成一轮：钉版 12 文件 digest 12/12 一致；
  508 核对一致（增补前——2026-08-12 P2-B 向量补强至 519 后该计数为 519）；regressions 空数组符合预期；9 家族来源与覆盖足够；4 条观察见
  §4.2）与 §4.2（巡检观察记录体例）；`docs/five-element-review-1.0.0.md:63`
  （钉版 corpus 12 文件，digest 登记）；`docs/pilot-go-0.19.0.md` §1（语料登记表）。
- 目标：RC soak 阶段对真实 corpus 的**抽检巡检**——四类核对（钉版 digest /
  519 计数 / regressions / 家族来源覆盖）+ 观察记录（P2 级，照 rc-candidate §4.2
  的 4 条观察体例：编号、出处、判定）。
- **本手册只含命令与记录模板；执行本身不在本准备批次内。**

## 1. 巡检范围（四项）

| 项 | 内容 | 对照权威 |
|---|---|---|
| 1 | 钉版 12 文件 digest 核对（fixtures 层真实语料） | pilot-go-0.19.0.md §1 语料登记表（16 位 sha256 前缀 + 字节数） |
| 2 | 519 计数核对（18 套向量 + 聚合 digest） | fc-manifest-0.13.0.json `digests.conformance_suite`（suites=18 / cases=519 / aggregate_sha256=`cfd6e296da5b22b62d37b076d35bf6bbf58b0678ceddb37eea51a8b47200ab6a`）；conformance/README.md 的 18 套 suite 清单段（合计 519 个 case） |
| 3 | regressions 检查（fuzz 回归输入数组） | conformance/corpora/mutation-v1.json `regressions`（空数组符合预期；新增条目必须可追溯） |
| 4 | 9 家族来源与覆盖 | conformance/fixtures/ 九目录 + 各家族 README 来源/许可证声明（conformance/README.md:35-43 夹具清单——hcl/plist/xml 三家已补全） |

## 2. 命令清单（在母仓检出执行）

### 2.1 钉版 12 文件 digest 核对

```powershell
$f = 'conformance\fixtures'
$files = @(
  'real-world\package.json', 'real-world\tsconfig.jsonc',
  'real-world\vscode-settings.jsonc', 'real-world\application.json5',
  'toml\application.toml', 'yaml\compose-services.yaml',
  'ini\desktop-settings.ini', 'properties\build-tool.properties',
  'xml\app-server-config.xml', 'plist\xml\com.example.preferences.plist',
  'hcl\tf\main.tf', 'properties\continuation-heavy.properties')
foreach ($rel in $files) {
  $p = Join-Path $f $rel
  $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
  '{0,-55} {1,5} {2}' -f $rel, (Get-Item -LiteralPath $p).Length, $h.Substring(0, 16)
}
```

预期（pilot-go-0.19.0.md §1，2026-08-12 实测逐字节一致）：

| 文件 | 字节 | SHA-256（前 16） |
|---|---|---|
| real-world/package.json | 424 | 06d760863d6c0c66 |
| real-world/tsconfig.jsonc | 428 | c3fa961d9eae747c |
| real-world/vscode-settings.jsonc | 396 | 0fa1b8e135e81fc9 |
| real-world/application.json5 | 410 | 30c07b89db0fecd9 |
| toml/application.toml | 541 | 8ba14205b3686d98 |
| yaml/compose-services.yaml | 594 | 9deb02681e671038 |
| ini/desktop-settings.ini | 177 | b01f173b34c8e412 |
| properties/build-tool.properties | 208 | 3c988cf59c074434 |
| xml/app-server-config.xml | 508 | 221ebb7eeadcdc12 |
| plist/xml/com.example.preferences.plist | 1321 | accc38fd6b871e77 |
| hcl/tf/main.tf | 1139 | 1c9a57fc4f6b7358 |
| properties/continuation-heavy.properties | 246 | 7a52a560b88e734c |

（logback.xml 在 pilot 表中为"—"行：W3 的 text 编辑目标、不在 12 文件注册内，
照 rc-candidate §4.2 观察 1 的判定接受。）

### 2.2 519 计数 + 聚合 digest

```powershell
# 18 套向量 / 519 cases（照 go-verify-shared-conformance.ps1 [1/6] 的算法：
# 文件名 Ordinal 排序、逐文件 sha256 小写、"{basename}:{digest}" 以 \n 连接
# 无尾换行、再 sha256；口径 = 规范 checkout 字节（LF））
$names = @(Get-ChildItem 'conformance\vectors' -Filter '*.json' | ForEach-Object { $_.Name })
[System.Array]::Sort($names, [System.StringComparer]::Ordinal)
$lines = @(); $total = 0
foreach ($name in $names) {
  $path = Join-Path 'conformance\vectors' $name
  $v = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
  $total += @($v.cases).Count
  $lines += "$name`:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant())"
}
$agg = [System.BitConverter]::ToString(
  [System.Security.Cryptography.SHA256]::Create().ComputeHash(
    [System.Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $lines)))).Replace('-', '').ToLowerInvariant()
"suites=$($names.Count) cases=$total aggregate=$agg"
```

预期：`suites=18 cases=519 aggregate=cfd6e296da5b22b62d37b076d35bf6bbf58b0678ceddb37eea51a8b47200ab6a`
（注意 CRLF 工作树会使逐文件 digest 不同——须在规范 checkout（`git config
core.autocrlf false` / LF）下核对，照 consema-go/scripts/go-verify-shared-conformance.ps1
的 CRLF 注记段（行号可能漂移，以注记语义为锚））。

### 2.3 regressions 检查

```powershell
$m = Get-Content 'conformance\corpora\mutation-v1.json' -Raw -Encoding UTF8 | ConvertFrom-Json
"regressions=$($m.regressions.Count) fixtures=$($m.fixtures.Count)"
# 有新增条目时逐条列出：format / profile / bytes 前 16 位 / note
```

预期：`regressions=0 fixtures=46`；任何新增条目必须与 fuzz 发现记录
（fuzz-evidence-0.13.0.md §6 新发现协议 / corpora/README.md 回归工作流）对应。

### 2.4 9 家族来源与覆盖

```powershell
Get-ChildItem 'conformance\fixtures' -Directory | Select-Object -ExpandProperty Name
# 各家族 README（hcl/ini/json5/plist/properties/real-world/toml/xml/yaml）
# 的来源/许可证声明抽查（conformance/README.md:35-43 夹具清单）
```

预期：`real-world json5 toml yaml ini properties xml plist hcl` 九目录齐备。

## 3. 结果记录模板（照 rc-candidate §4.2 观察体例）

```markdown
## RC soak 阶段 1 — 每格式真实 corpus 抽检巡检记录（YYYY-MM-DD）

- 环境：<机器/OS>；母仓 HEAD <commit>；checkout 形态：<规范 LF / CRLF 工作树>
- 四类核对：
  1. 钉版 12 文件 digest：<N>/12 一致（不符项逐条列出：文件 + 实测 vs 登记）
  2. 519 核对：<suites>/18、<cases>/519 一致；aggregate <一致/不符>
  3. regressions：<N> 条（空数组符合预期 / 新增条目逐条对应发现记录）
  4. 9 家族来源与覆盖：<N> 目录齐备；来源/许可证声明抽查 <通过/发现>
- 观察记录（P2 级，照 §4.2 体例：编号 + 出处 + 判定）：
  1. <观察内容——附 file:line 出处>——<接受/处置建议>
  2. …
- 结论：<巡检通过；或列出需处置项与 judgment>
```

诚实记录体例：digest/计数只写本次实际计算值；与登记不符先复核命令口径
（如 CRLF 工作树 digest 差异属预期，须标注 checkout 形态），再判断是否真漂移；
漂移即事件，按 conformance/README.md 变更纪律（同批五处更新）处置。

## 4. 相关文件

- `docs/pilot-go-0.19.0.md` §1（12 文件语料登记）
- `docs/fc-manifest-0.13.0.json`（conformance_suite：18/519/aggregate cfd6e296…）
- `conformance/README.md`（18 套 519 cases、fixtures 家族说明、变更纪律）
- `conformance/corpora/README.md`（mutation 语料与 regressions 工作流）
- `docs/rc-1.0.0-candidate.md` §4.1/§4.2（首轮巡检记录与观察体例）
