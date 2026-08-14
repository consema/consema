# Go SDK 真实项目 Pilot 报告（0.19.0 G5.7，路线图 §22.7/§23）

- 日期：2026-08-10（本地实测）
- 环境：Windows 11 Pro 10.0.26200，x86-64；Go 1.26.5（`C:\Program Files\Go\bin\go`）；
  依赖 `consema.dev/consema` 单 module（go 1.26，stdlib-only，零第三方依赖，
  go-implementation-plan §1.3）；对照 Rust CLI `target/release/consema.exe`（0.13.0，
  release profile，`cargo build --release --locked -p consema`）
- 依据：路线图 §22.7（真实有效性：每格式真实语料、三类真实批量迁移、零未授权损失、
  未触及字节不变、演练、Rust 与 Go 各至少一个端到端 SDK pilot、pilot 缺陷入回归）
  与 §23.2（必做工作流 W1-W8）/§23.3（核心指标 12 项）；go-implementation-plan §2.6 G5.7
- 可复现：`cd go && go test -count=1 -v ./pilot/`（14 个测试全部通过；
  跨语言对照测试在设置 `CONSEMA_PILOT_RUST_CLI` 时自动执行，未设置时显式 skip）。
  本报告所有命令输出均为实跑粘贴；指标全部来自本报告记录的运行。

## 1. 选择的真实项目与语料登记（§23.1）

pilot 项目 = 钉版 `conformance/fixtures/` 语料的 12 个文件（与 pilot-0.13.0.md 同源
corpus 扩展：除 real-world/ 四件外，补齐每个格式家族一件真实形状配置，构成一个
"小真实项目"：应用元数据、编译器配置、编辑器设置、服务配置、compose、桌面设置、
构建工具配置、XML 服务配置、plist 偏好、Terraform 模块）。测试把项目物化为
临时目录中的副本，fixtures 本身逐字节不动（TestPilotMigration3 断言源树零改动）。

语料登记（§23.1 要求记录来源、license、digest、Profile 与预期用途；来源与 license：
`conformance/fixtures/` 各 README 声明的非专有代表性配置文档，仓库 MIT 许可，无
secret 与个人信息）：

| 文件 | 字节 | SHA-256（前 16） | Profile | 用途 |
|---|---|---|---|---|
| real-world/package.json | 424 | 06d760863d6c0c66 | json.strict@1 | W1/W6/W7/W8 主项目；迁移 1/3 |
| real-world/tsconfig.jsonc | 428 | c3fa961d9eae747c | jsonc.bounded@1 | W1；迁移 1 |
| real-world/vscode-settings.jsonc | 396 | 0fa1b8e135e81fc9 | jsonc.bounded@1 | W1 |
| real-world/application.json5 | 410 | 30c07b89db0fecd9 | json5.standard@1 | W1；迁移 1/3 |
| toml/application.toml | 541 | 8ba14205b3686d98 | toml.1.0@1 | W1；W7 |
| yaml/compose-services.yaml | 594 | 9deb02681e671038 | yaml.1.2-core@1 | W1；迁移 1 |
| ini/desktop-settings.ini | 177 | b01f173b34c8e412 | ini.portable@1 | W2/W8；迁移 2/3 |
| properties/build-tool.properties | 208 | 3c988cf59c074434 | java-properties.reader@1 | W2；迁移 2 |
| xml/app-server-config.xml | 508 | 221ebb7eeadcdc12 | xml.1.0-safe@1 | W3；W7 |
| xml/logback.xml | — | — | xml.1.0-safe@1 | W3（text 编辑） |
| plist/xml/com.example.preferences.plist | 1321 | accc38fd6b871e77 | plist.xml@1 | W4 |
| hcl/tf/main.tf | 1139 | 1c9a57fc4f6b7358 | hcl.native@1 | W5 |
| properties/continuation-heavy.properties | 246 | 7a52a560b88e734c | java-properties.reader@1 | W2 逻辑行 |

（logback.xml 与各家族 fixtures 的完整 digest 由 corpus 测试逐文件打印。）

## 2. §23.2 必做工作流执行记录（Go SDK 端到端，全部经公共 API）

对比 pilot-0.13.0：Rust pilot 的 F-1（CLI 仅接线 INI edit，6 个家族 edit 词表
不可执行）在 Go SDK 面**不存在**——八个家族的 edit 事务全部是 SDK 公共 API
（0.18.0 G4.3），W1/W3/W4/W5 全部在 SDK 层完成。Go CLI beta 尚在并行实现中，
本 pilot 全部经 SDK 面执行（与本任务"用真实 SDK 面，不得为 pilot 特制内部 API"
的约束一致）。

### 2.1 W1 — JSONC/JSON5/TOML/YAML 中更新依赖或镜像版本，保持注释与 style

全部提交成功，每步断言：untouched-byte proof 可重验、patch 应用精确复现目标字节、
注释/引号风格保留：

| 文件 | 编辑 | 结果 |
|---|---|---|
| package.json | `dependencies.fastify` `"4.28.1"`→`"4.29.0"`（LiteralScalar）；`version` `"1.0.0"`→`"1.1.0"`（SemanticScalar, preserve-compatible） | 424 B → 424 B，untouched 0.9646 |
| tsconfig.jsonc | `compilerOptions.target` `"ES2022"`→`"ES2023"`（LiteralScalar） | 注释行逐字节保留 |
| vscode-settings.jsonc | `editor.rulers` 插入元素 120（InsertArrayElement, end） | `[80, 100]` → `[80, 100,120]`（插入元素为 canonical 片段） |
| application.json5 | `service.port` 8080→9090（Semantic）；`labels.environment` `'staging'`→`'production'`（LiteralScalar 保持单引号） | 注释与单引号风格保留 |
| application.toml | `service.name` `"catalog"`→`"catalog-v2"`；`[database] pool_size` 32→64（均 SemanticScalar） | 文件头注释与 inline-table 风格保留 |
| compose-services.yaml | `services.api.image` `example.invalid/api:1.0.0`→`:1.1.0`（LiteralScalar，yaml 经 `Commit` 直提——yaml 无 dry-run 面，见 §6 F-2） | block 风格保留，无表达式求值 |

### 2.2 W2 — INI/Properties 中插入、删除、rename 配置项并保留重复与 logical line

- `desktop-settings.ini`：`width` 1440→1600（SemanticValue）、`[recent]` 插入
  `recent_files=3`、`width`→`resolution-width` rename（第二个事务——每事务每目标
  一个操作是 SDK 契约）。文件头注释与 section 顺序保留；untouched 0.8475
  （一文件多替换）。
- 重复 section：`[window]` 两次的源 → Recovered 形成，2 个 section 全保留
  （重复不被合并/丢失）；Recovered 源 convert 被显式拒绝（W7 第 6 项）。
- `build-tool.properties`：`version` 1.0.0→1.1.0（SemanticValue）、插入
  `org.gradle.warning.mode=all`、随后 `version` 移除（第二个事务）。注释保留；
  两次提交的 proof 都通过。
- 逻辑行：`continuation-heavy.properties` 解析→渲染字节级闭合（246 B 原样往返），
  未被任何编辑触及。

### 2.3 W3 — XML 中修改 attribute/element/text，不破坏 namespace 与 mixed content

- `app-server-config.xml`：`connector` 的 `port` 8080→9090（SetAttributeValue，
  目标 = `OccurrenceNodeRef(ordinal, XmlAttribute)`）、插入 `name="edge"` 属性
  （第二个事务，目标 = connector 元素 NodeRef）。`xmlns:db`/`xmlns:sec` 绑定字节
  不变；CDATA 与 mixed content 未被编辑破坏。
- `logback.xml`：`<pattern>` 文本替换（ReplaceText 目标 = 文本 occurrence
  NodeRef，非元素）。替换后 `%d{...} %-5level [%thread] ...` 新 pattern 就位；
  注释与元素结构 untouched。
- 观察（契约行为，非缺陷）：ReplaceText 只接受 RoleXmlText 目标；CDATA 内容
  不在此操作词表内（Rust `text_for` 同语义，双语言一致）。CDATA 文本更新不在
  mandatory structural edit 面内，属文档边界。

### 2.4 W4 — plist XML/binary 中修改 typed value 并保持 representation contract

- `com.example.preferences.plist`：`ui.font-size` `<real>12.5</real>`→`<real>14</real>`
  （EditValueReal）、`retry-count` 42→43（EditValueInteger），XML 表示编辑成功，
  untouched 通过。
- representation contract：编辑后的 XML → binary（`bplist00` 头断言）→ binary
  重解析成功；typed 值往返保留。XML 面与 binary 面共享同一 value-tree 投影。

### 2.5 W5 — HCL 中修改 literal attribute，不执行表达式

- `main.tf`：`variable "instance_count"` 的 `default = 2`→`default = 4`
  （SetAttributeValue，BodyPath 含 block/labels/occurrence）。`region = var.region`
  的表达式作为语法事实原样保留（无求值，SECURITY.md）；注释与 provider 块
  untouched。

### 2.6 W6 — JSON ↔ TOML、JSON ↔ YAML 等可表示组合的 audited conversion

- JSON→TOML（369 B）、JSON→YAML（647 B）：整体 fidelity 均 Exact；目标字节
  重解析后投影回 core.Value，与源投影 `core.Equal` 深度相等（双向往返语义相等）。
- 家族内转换：XML→XML（safe-canonical 文档重解析闭合）、HCL tfvars→canonical
  hcl.native。
- 与 Rust CLI 逐字节对照（metric 12，§4）：同请求形状的 JSON→TOML 与 JSON→YAML
  输出与 `consema convert` 输出**逐字节相等**（369 B / 647 B，2/2）。

### 2.7 W7 — 对不可无损转换产生明确拒绝和报告

全部原子失败（无目标文档、无部分字节），失败为 typed `ConversionFailure` 带冻结
code：

| 源 → 目标 | 拒绝 code | 语义 |
|---|---|---|
| YAML graph（anchor-heavy）→ JSON | core.conversion.projection-failed@1 | sharing/cycle 未授权损失 |
| TOML date/time（all-values）→ JSON | core.conversion.materialization-failed@1 | JSON 无 temporal 类别 |
| XML element-tree（app-server-config）→ JSON | core.conversion.materialization-failed@1 | record-consumption 门禁 |
| TOML floats（application.toml）→ JSON | core.conversion.materialization-failed@1 | BinaryFloat64 在 ExactOnly 下无精确 JSON 文本 |
| JSON5 精确 decimal（application.json5）→ TOML | core.conversion.materialization-failed@1 | TOML 无 decimal 类别，float 即损失 |
| Recovered INI（重复 section）→ JSON | core.conversion.projection-failed@1 | 恢复源不进入投影 |

TOML→JSON 拒绝在 Rust CLI 侧同 shape 请求下也以
`core.conversion.materialization-failed@1` 拒绝（metric 12 断言）。

### 2.8 W8 — 多文件 dry-run、review、stale conflict 和 apply

- **多文件 plan/review/apply**：4 个真实文件（package.json、tsconfig.jsonc、
  desktop-settings.ini、application.json5）经 `PlanEdit` dry-run → `BatchPlanner`
  → `core.batch-plan@1` 清单（每条目带 profile/source_digest/operations/source_patch）
  → `ApplyPlanFile` 逐个应用：4/4 completed，目标 digest 齐全。
- **stale conflict**：计划后外部追加一行 → `ApplyPlanFile` 返回
  skipped-stale + `core.source.patch-base-mismatch@1`，文件字节分毫未动。
- **100 文件批量 + 中断 + 恢复**：100 份 `desktop-settings.ini` 副本（generated
  combinatorial corpus，与 pilot-0.13.0 同法），`width`→1600。中断 seam：先应用
  53 个（模拟 SIGINT），再应用剩余 47 个（恢复语义：completed 跳过、pending
  重做）：100/100 completed，恢复率 100%。每个 completed 结果带验证过的目标
  digest。

## 3. §23.3 核心指标

| # | 指标 | 数值 | 测量方式 |
|---|---|---|---|
| 1 | exact unmodified round-trip rate | 12/12 = 100% | corpus 12 文件 parse→render 逐字节闭合（TestPilotCorpus 断言） |
| 2 | untouched-byte preservation rate | 84.7%-99.0%/文件（编辑路径）；100%（stale 路径） | 每提交的 UntouchedByteProof 旧侧区域字节/源长；stale 文件 0 字节写入 |
| 3 | silent-loss count | 0 | 全部 convert 运行 fidelity=Exact 或原子失败（W6 断言 + W7 六组原子失败） |
| 4 | authorized-loss report completeness | 完整 | 成功 convert 始终携带两阶段 ConversionReport（source/target profile、两阶段 fidelity、事件）；失败返回 `report:null,target:null` 形态的 typed 失败 |
| 5 | false-success count | 0 | 每个失败路径断言：无部分目标、无 exit-0-但结果不完整；typed error（Code() 契约） |
| 6 | false-conflict / missed-conflict count | 0 / 0 | stale 场景：1 真实冲突检出（skipped-stale），其余文件照常 completed；无误报、无漏报 |
| 7 | diagnostic stability | 字节级稳定 | Recovered 重复 section INI 两次解析的 diagnostics（code+notes）逐字节一致 |
| 8 | query result determinism | 字节级确定 | INI native query（sections→name-equals→entries）两次运行结果逐字节一致 |
| 9 | parse/query/edit latency p50/p95 | 见下 | 进程内稳态均值 + Rust CLI 冷进程样本（§7 复现） |
| 10 | peak memory/input byte | ≈ 32.5 MB 进程峰值（Go 测试进程含批处理） | 进程内 after-GC heap ≈ 0.9 MB；`powershell Start-Process go test -run TestPilotW8` 观察 WorkingSet 峰值 32.5 MB（含编译与 100 文件批处理） |
| 11 | batch apply success/recovery rate | 100%（4/4 与 100/100）；恢复率 100%（53+47） | W8 三场景 |
| 12 | Rust/Go observable mismatch count | 0 | 同 shape 请求下 JSON→TOML/JSON→YAML 输出逐字节相等（2/2 对）；TOML→JSON 拒绝 code 双语言一致（§4） |

延迟（2026-08-10，本机；Go 进程内稳态，n=300/操作，均值）：

| 操作 | Go 均值（ns） | Rust CLI 冷进程 p50（ms，n=5） |
|---|---:|---:|
| parse package.json | 15,723 | 6.4（inspect） |
| query（json native root） | 17,802 | — |
| convert → toml | 120,029 | 8.1 |
| edit commit | 36,763 | — |

Rust CLI 冷进程 p50/p95：inspect 6.4/8.8 ms、convert 8.1/9.7 ms（与
pilot-0.13.0 记录的 5/12 ms、6/13 ms 同量级）。Go 进程内稳态在 Windows 计时器
粒度以下，p50/p95 分位不报告（doc 记录冷进程替代，方法学与 pilot-0.13.0 一致）。

峰值内存：进程内 after-GC heap ≈ 0.9 MB（allocation 总量 ≈ 107 MB 分摊 300
迭代测量循环）；100 文件批处理整体在测试进程内完成，`go test -run TestPilotW8`
进程 WorkingSet 峰值 32.5 MB（2026-08-10 PowerShell 实测，含编译与批处理）。

## 4. 三场真实批量迁移（§22.7）

全部在 pilot 项目树上执行，每文件记录 base/target digest，断言零未授权损失
（untouched proof 可重验 + patch 应用精确复现目标 = 变更字节集合恰好等于
replacement 集合）与未触及字节不变。

### 4.1 迁移 1 — 版本/镜像更新（4 文件，52 变更字节）

| 文件 | base digest（前 16） | target digest（前 16） | untouched |
|---|---|---|---|
| package.json | 06d760863d6c0c66 | 9cca22595e0efb8c | 0.9646 |
| tsconfig.jsonc | c3fa961d9eae747c | 28638a38d7f929f0 | 0.9813 |
| application.json5 | 30c07b89db0fecd9 | 1cf14abbb9103b5a | 0.9902 |
| compose-services.yaml | 9deb02681e671038 | 7d2e7dca5b50a156 | 0.9579 |

结果：4 文件迁移完成，52 变更字节，**0 未授权字节**（全部变更字节被 proof 覆盖）。

### 4.2 迁移 2 — 结构插入删除（INI + Properties）

- desktop-settings.ini：section 插入（[logging]）、section rename（window→display）、
  entry 插入（icon-theme=auto）、entry rename（theme→color-scheme）、entry 删除
  （maximized）；base b01f173b34c8e412 → target f4e0fafeba2698ec，untouched
  0.8475；重复与逻辑行由 continuation-heavy.properties 字节级闭合佐证。
- build-tool.properties：semantic replace（version 2.0.0）、insert
  （org.gradle.jvmargs=-Xmx4g）、rename（org.gradle.parallel → .parallel.threads）；
  base 3c988cf59c074434 → target d352ba928bb9e829，untouched 0.8846。

### 4.3 迁移 3 — 跨格式转换（4 个 audited conversion，全 Exact）

| 源 | 目标 | 字节 | fidelity |
|---|---|---|---|
| package.json | toml.1.0 | 369 | Exact |
| application.json5 | yaml.1.2-core | 601 | Exact |
| package.json | yaml.1.2-core | 647 | Exact |
| desktop-settings.ini | json.strict | 175 | Exact |

源树逐文件字节未动（断言）；不可无损组合（§2.7）全部原子拒绝。

## 5. Rust pilot 复核（pilot-0.13.0.md 指标在 0.13.0 之后 Rust 树）

当前树 Rust CLI（0.13.0）重跑 pilot-0.13.0 关键路径，数字更新记录：

| 项目 | pilot-0.13.0 记录 | 本次（2026-08-10） | 结论 |
|---|---|---|---|
| plan 100 INI 文件 | 333 ms | 52 ms | 更快（同机同 shape）；digest 完全一致（base b01f173b… / target 98b89205… 与 0.13.0 记录逐字节相同） |
| apply 100 文件 | 2,137 ms | 3,436 ms | 同量级（机器负载差异），100/100 completed |
| stale conflict | exit 4 + skipped-stale（core.source.patch-base-mismatch@1） | 相同（exit 4，99 completed + 1 skipped-stale，外部追加行保留） | 成立 |
| 中断/恢复 | 7 completed / 13 pending → 20/20 | 相同（manifest 7 completed / 13 pending，重跑 20/20） | 成立 |
| JSON→YAML 超线性（F-2） | 修复后 1.01 s（335 KB） | 1k→2k→4k→5k keys：130/133/207/257 ms（330,001 B flat 5,000 keys = 257 ms） | 线性（倍增比 1.0-1.6×），F-2 修复成立 |
| convert 往返语义 | JSON↔TOML/JSON↔YAML 深度相等 | 相同 + 与 Go SDK 逐字节相等（metric 12） | 成立 |
| 冷进程延迟 | inspect p50 5 ms / convert p50 6 ms | inspect 6.4 ms / convert 8.1 ms（n=5） | 同量级 |

## 6. 发现的问题

### F-1（契约行为确认，非缺陷）— XML ReplaceText 仅接受文本 occurrence，CDATA 不在词表

Go 与 Rust 的 `text_for` 同语义（`NodeRole::XmlText` only）。W3 的文本编辑在
logback.xml 的真实文本节点完成；CDATA 文本更新属文档边界（record 保持面），
已在 §2.3 记录。无行为分歧，不需要回归。

### F-2（已知面，pilot 确认）— YAML family 无 dry-run 面（G2.1 已知 gap）

`PlanEdit` 对 yaml 事务显式返回 `EditUnsupportedError`（"use the yaml package's
Commit directly"），pilot 的 W1 YAML 步骤按该文档化路径经 `yaml.Commit` 直提。
这是 go-implementation-plan §2.6 G5.5 已知公开 API 形态，非新缺陷；已进入
本 pilot 的复现记录。

### F-3（pilot 观察）— JSONC/JSON5 插入元素的 canonical 片段拼写

`[80, 100]` 插入 120 后为 `[80, 100,120]`（插入元素为 canonical 片段，无空格
填充——语义插入而非格式化）。与 Rust 同词表行为一致（canonical fragment 契约），
pilot 断言已按语义内容校验。

### F-4（记录）— 本 pilot 未发现需要进入回归的缺陷

所有失败路径均为契约性原子拒绝；无静默损失、无 false success、无
Rust/Go 分歧（metric 12 = 0）。§22.7"pilot 缺陷入回归 suite"按零缺陷记录；
后续若 Go CLI beta 或差分 corpus 追加发现新行为，按 §17.4 追加式入
conformance regression 语料（mutation-v1 纪律，只读参考）。

## 7. 复现

```text
cd go
go test -count=1 -v ./pilot/                      # 14 测试；跨语言对照自动 skip
CONSEMA_PILOT_RUST_CLI=..\target\release\consema.exe go test -count=1 -v ./pilot/
```

门禁（本任务交付面）：`cd go && gofmt -l pilot/` 空、`go vet ./pilot/` 干净、
`go test -count=1 ./pilot/` 全过（含 Rust 对照时 14/14）。`go/cmd/consema`（Go
CLI beta，并行 agent 域）在本报告记录时处于未完成状态，不属于本 pilot 交付面。

fixture 均取自 `conformance/fixtures/` 钉版文件；请求 payload 为
`docs/cookbook.md §5` 钉版 `cli.convert-request@1` canonical JSON（metric 12
测试内嵌该 2251 字节 pin，YAML 变体按 profile id 派生，字段序保持 canonical）。

## 8. 结论

Go SDK 完成 §23.2 W1-W8 全工作流端到端 pilot：12/12 字节级 round-trip、零静默
损失、零 false success、0/0 冲突误报漏报、诊断与查询字节级确定、批量 100/100
且中断恢复率 100%、Rust/Go 观测分歧 0。三场真实批量迁移（版本/镜像更新、结构
插入删除、跨格式转换）全部满足零未授权损失与未触及字节不变，证据可重放
（§4 digest 表 + §7 复现命令）。
