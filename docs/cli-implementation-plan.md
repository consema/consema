# Consema 0.12.0 CLI 实现计划（Rust SDK + CLI 产品集成）

> **拆分后路径注记（2026-08-14 波 2）**：本文为 2026-08 拆仓前撰写的 0.12.0 规划记录，
> 文中 `crates/consema*` 为拆分前单仓布局路径，六仓拆分后对应物为
> `consema-rs/consema*`；按 G76 处置约定，历史规划文档以本节注记统一标注。

- 对应规范：路线图《Consema 1.0.0 产品路线图与双语言落地设计》§10（产品级 CLI）、§14.11（0.12.0 范围与硬门禁）、§12.3 第 13 项（CLI machine protocol 与 batch apply 须 RFC-first）、§15（Feature-Complete Gate 中与 CLI 相关的门禁）、§1（CLI 不是第三个实现）；RFC 0015（本计划 M1 产出，CLI machine protocol 与 batch apply，规划编号对应路线图 §27 R-17）
- 目标版本：0.12.0（对齐路线图 §14.11）
- 先例：`docs/hcl-implementation-plan.md`（0.11.0）与 `docs/plist-implementation-plan.md`（0.10.0）的多 agent 文件域计划体例；consema-rs 的 `consema/`（拆分前 `crates/consema/`；facade，0.8.0，lib-only 602 行 + conversion.rs 2147 行）；consema-rs 的 `consema-protocol/`（拆分前 `crates/consema-protocol/`；semantic-model v1-v6、canonical JSON/PVCE 双传输、typed payload decoders）
- 语义权威顺序（沿用 `docs/IMPLEMENTATION.md`）：永久不变量 → 已接受 RFC → 语言无关 conformance vectors → 本实现计划与 Rust API → 第三方行为仅为实现细节

本文是只读调研产出的执行计划；除本文外本次不修改任何仓库文件。所有行数估计为 Rust 源码（含该模块内测试）规模级，参考 consema-xml 各模块实际行数（parser 2649、edit 2490）与 hcl/plist 计划的估计惯例。

---

## 0. 总体结构

### 0.1 现状核查（本计划调研结论）

- **仓库中不存在任何 CLI 代码**：`crates/*/src/bin/` 仅有 `crates/consema-conformance/src/bin/` 下两个上游 suite 测试适配器（`consema-toml-test-decoder.rs`、`consema-yaml-test-adapter.rs`），不是产品 CLI；全 workspace 无 `main.rs`、无 `[[bin]]`、无 clap/structopt 等参数解析依赖。
- `crates/consema` 是 lib-only 可发布 facade crate（`crates/consema/Cargo.toml`），`pub use` 全部 13 个 backend crate 并通过 `Document::parse_*`/`as_*` 与 `convert_*` 提供统一语义入口（`crates/consema/src/lib.rs`、`conversion.rs`）。
- 仓库无 `.github/`：CI 是本地门禁（`scripts/verify-package-archives.ps1` 打包验证 + 各 oracle 脚本 + cargo 门禁）。
- 依赖政策：`deny.toml` 的 `[sources]` 仅 crates.io 钉版、`[bans]` 禁多版本/通配；workspace 只钉版 7 个直接依赖（`Cargo.toml:21-28`）。CLI 计划因此**零新外部依赖**（§5）。
- `docs/IMPLEMENTATION.md` §13（0.8.0 明确边界，第 451-453 行）明示"文件系统原子替换"未实现——0.12.0 是首次实现文件系统写入的版本，且按路线图 §6（第 497-508 行）只属于 CLI/application 层，不得塞回 Document 核心。

### 0.2 命令面（路线图 §10 第 783-818 行，11 个正式命令）

```text
consema inspect         只读文件事实（字节/digest/编码事实/候选格式/歧义），从不猜测
consema capabilities    facade 能力清单（格式家族/Profile/查询域/操作/错误码）
consema query           native/lossless 查询（请求经 core.query-definition@1 输入）
consema project         显式投影请求 → PortableValue/PortableGraph/报告/provenance
consema materialize     显式物化请求 → 新 Document/报告/provenance
consema convert         投影 + 物化两阶段显式组合（跨格式）
consema edit            单文件结构编辑（默认 dry-run；写入需 --write）
consema plan            批量计划：逐文件 EditPlan/SourcePatch + batch-plan manifest
consema apply           批量应用：前置条件重验 + 同目录原子替换 + batch-result manifest
consema conformance     内嵌 CLI 自检子集；完整语言无关 suite 保持仓库级执行
consema explain         诊断码/契约/Profile/能力的权威解释（人类 + 机器）
```

0.12.0 交付（§14.11）列出的 inspect/query/project/materialize/convert/plan/apply/explain 是核心八命令；capabilities、edit、conformance 亦属 §10"至少提供"清单，全部 11 个在 0.12.0 完成（§15.1"CLI 全部正式命令完成"是 0.13.0 门禁的前提输入）。

### 0.3 模块拓扑

关键决策：**CLI 二进制作为 `crates/consema`（facade crate）的 `[[bin]]` 目标**，bin 代码全部位于 `src/bin/consema/`（目录式 bin，私有模块树），只允许依赖同包 lib 的 public API。两个理由：

1. 路线图 §1（第 131-135 行）把正式 `consema` CLI 列为产品交付物，facade crate 就是"产品"crate；bin 内置于其中保持可发布归档数不变（14 个，`scripts/verify-package-archives.ps1` 覆盖面不变），`cargo install consema` 同时获得 SDK 与 CLI。
2. **同包 bin 无法访问 lib 的私有项**——"CLI 与 SDK 使用同一语义入口"（§14.11 硬门禁）由此在编译期强制执行：CLI 需要什么语义入口，就必须走 facade 的 public API；facade 缺什么就补什么公共 API（M10 评审），绝不绕道 backend crate（硬门禁）。

```text
crates/consema/
├── Cargo.toml                       # 增加 [[bin]] name = "consema"；零新外部依赖
├── src/lib.rs                       # 既有 facade（语义权威入口，本计划不重写，仅按需补公共 API）
├── src/conversion.rs                # 既有（不动）
└── src/bin/consema/                 # CLI（application 层，模块树私有）
    ├── main.rs                      # 入口：命令派发、exit code、stdout/stderr 分流
    ├── args.rs                      # 自研参数解析（无 clap，§5.1）
    ├── output.rs                    # 人类可读渲染 + redaction 挂钩 + 规范 JSON 缩进
    ├── registry.rs                  # 格式家族/Profile/查询域/操作/错误码清单（facade 枚举，§3.1）
    ├── detect.rs                    # 文件事实 + 置信度 + 歧义（§3.2，从不猜测）
    ├── inspect.rs                   # consema inspect
    ├── capabilities.rs              # consema capabilities
    ├── explain.rs                   # consema explain
    ├── query_cmd.rs                 # consema query
    ├── project_cmd.rs               # consema project
    ├── materialize_cmd.rs           # consema materialize
    ├── convert_cmd.rs               # consema convert
    ├── edit_cmd.rs                  # consema edit（dry-run 默认；--write 显式）
    ├── plan.rs                      # consema plan：batch-plan manifest 生成（只读）
    ├── apply.rs                     # consema apply：原子写 + 前置条件重验 + 中断恢复
    ├── fsio.rs                      # 同目录临时文件 + 原子替换 + 权限/symlink 政策（§4.1）
    ├── manifest.rs                  # batch-plan/batch-result 状态机（消费 protocol v7 类型）
    ├── redact.rs                    # secret 检测与脱敏（presentation-only，§4.4）
    └── conformance_cmd.rs           # consema conformance（内嵌自检子集）

crates/consema-protocol/             # M2：semantic-model v7 新增 CLI 稳定 payload
    ├── cli.rs                       # 信封 + batch manifest 类型 + typed decoders
    └── ...（ContractRegistry::v7() / ErrorCodeRegistry::v7() / RegistryManifest::v7()）
```

模块依赖方向（单向）：

```text
bin ──> consema lib public API ──> backend crates（经 facade 再导出）
bin ──> consema::protocol（v7 payloads、encode_json/encode_pvce、decode_json/decode_pvce）
bin 绝不直接依赖任何 backend crate（硬门禁 1）
```

需求 → 模块映射（路线图章节 → bin 模块）：

| 需求来源 | 模块 |
|---|---|
| §10 命令面、§14.11 硬门禁 | main.rs + args.rs + output.rs（派发、exit code、stdout/stderr、人类输出） |
| §10 机器可读结果 + versioned schema、§11.2 双语言一致 | consema-protocol cli.rs（M2，v7 payloads） |
| §14.11 全格式 registry 与 auto-detection 安全边界 | registry.rs + detect.rs |
| §10 inspect/explain 语义 | inspect.rs + explain.rs + capabilities.rs |
| §10 query/project/materialize/convert | query_cmd.rs / project_cmd.rs / materialize_cmd.rs / convert_cmd.rs |
| §10 批量 manifest、写入前重验 digest、原子替换、中断恢复 | plan.rs + apply.rs + fsio.rs + manifest.rs |
| §10 secret 脱敏、§19.2 presentation-only | redact.rs + output.rs |
| §10 默认只读/dry-run、显式确认参数 | args.rs（--write/--apply/--output 政策）+ 每命令接线 |
| §10 conformance 命令 | conformance_cmd.rs + 仓库级向量（§8） |

## 1. crate 拓扑与复用决策

### 1.1 直接复用（零修改）

| 共享件 | 复用方式 | 备注 |
|---|---|---|
| `consema::Document`（facade） | 直接复用 | `parse_*`/`as_*`/`render`/`profile`/`formation_status`/`diagnostics`/`snapshot_identity`（lib.rs），全部格式的同一语义入口 |
| `consema::convert_*`（8 个） | 直接复用 | 跨格式转换的组合层（conversion.rs），CLI convert 命令的整个实现 |
| `consema::protocol` 全部既有 payload | 直接复用 | QueryResultMessage/ProjectionResultMessage/MaterializationResultMessage/ConversionReportMessage/EditPlanMessage/SourceSnapshotMessage/SourcePatchMessage/Completion/DiagnosticMessage（protocol lib.rs）——CLI 机器输出直接包装这些消息 |
| `ProtocolMessage::to_json/to_pvce`、`encode_json/decode_json`、`encode_pvce/decode_pvce` | 直接复用 | canonical JSON 与 PVCE/1 双传输（protocol value_transport.rs）；机器输出与请求输入的传输层 |
| `core.query-definition@1` | 直接复用 | query 命令的请求输入（IMPLEMENTATION.md 第 257 行：固定字段 PortableValue schema + PVCE/1 传输）；`query_definition_message`/`query_definition_from_message`（protocol query.rs） |
| `ProjectionRequestMessage` / `MaterializationRequestMessage(V2)` | 直接复用 | project/materialize 命令的请求输入（protocol projection.rs、materialization.rs） |
| `ContractRegistry` / `ErrorCodeRegistry` / `RegistryManifest` / `ProfileDescriptor` / `CapabilityDeclaration` | 直接复用 | capabilities/explain 命令与 registry.rs 的数据源（protocol contract.rs、registry.rs、registry_manifest.rs） |
| `Document::snapshot_identity`、`SourceSnapshot` digest 事实 | 直接复用 | inspect 的 digest 报告；plan/apply 的前置条件事实 |
| `ParseLimits`/`ProtocolLimits` 等全部上限类型 | 直接复用 | 每命令的解析/传输预算，CLI 层只做文件读取上限（§7 R-9） |
| `EditPlan` / `SourcePatch` / `UntouchedByteProof` / `dry_run` 等价契约 | 直接复用 | edit/plan 命令的规划核心（IMPLEMENTATION.md 第 261-263 行：dry-run 与 commit 相同 replacements 与 target digest；plan 不是文件写入授权） |
| `unsafe_code = forbid`、`missing_docs = warn`、clippy pedantic workspace lint | 沿用 | bin 模块同样受 workspace lint 约束（Cargo.toml:36-50） |

### 1.2 需要扩展的复用点（semantic-model v7，M2）

| 共享件 | 扩展方式 |
|---|---|
| `ContractRegistry` | 新增 `v7()`：38 条 v6 记录保持不变，追加 CLI 稳定 payload 契约（候选：`core.cli-output@1`、`core.batch-plan@1`、`core.batch-result@1`，最终名单由 RFC 0015 冻结） |
| `ErrorCodeRegistry` | 新增 `v7()`：v6 的 166 条冻结不变，追加 `cli.*` 错误族（usage/data/limit/precondition/interrupted 类，命名模式 §2.3） |
| `RegistryManifest` | `current()` 指向 v7（v6 先例：IMPLEMENTATION.md 第 443-445 行） |
| `ConversionReport` 的 `protocol_report`/`protocol_materialization_result` | 直接复用（conversion.rs），CLI 机器输出不需重复实现两阶段报告外部化 |
| facade public API | 按需小增：若 CLI 需要统一的格式枚举/查询域清单入口而 facade 未暴露，在 facade 补薄层（M4/M10 评审），**不改写既有 API** |

v7 是 additive：v1-v6 的 contract/error arrays、manifest 与 frozen constructors 精确不变（v4/v5/v6 先例，IMPLEMENTATION.md 第 365-377 行）。HCL 计划预留的"`core.hcl-query-result@1` 留给后续 semantic-model 版本"（hcl-implementation-plan.md §1.2）与 v7 不冲突：CLI payload 在 v7 先行，格式级 wire 契约仍按各自 RFC 排期。

### 1.3 依赖

`crates/consema/Cargo.toml` 增加（**零新外部依赖**）：

```toml
[[bin]]
name = "consema"
path = "src/bin/consema/main.rs"
```

- bin 不需要任何新 `[dependencies]`：只用 std + 同包 lib。dev-dependencies 亦不新增（e2e 测试用 `env!("CARGO_BIN_EXE_consema")` 启动已构建的二进制，§8.3）。
- `deny.toml` 与 workspace 依赖政策不变。
- 版本号：`version.workspace = true`，0.12.0 发布时随 workspace 提升（当前 0.8.0；0.9.0-0.11.0 在 CHANGELOG Unreleased 下，hcl-implementation-plan.md §1.4 先例）。

## 2. 命令面与 machine-readable protocol

### 2.1 命令语义（每条都对应路线图 §10 第 803-816 行的要求）

| 命令 | 只读/dry-run | 显式写入参数 | 机器输出 payload | 输入方式 |
|---|---|---|---|---|
| inspect | 是 | — | `core.cli-output@1` 信封 + 文件事实 | 文件路径 |
| capabilities | 是 | — | 信封 + 能力清单记录 | — |
| query | 是 | — | 信封 + `QueryResultMessage`/native 匹配 | `core.query-definition@1`（canonical JSON 或 PVCE 文件/stdin） |
| project | 是 | — | 信封 + `ProjectionResultMessage` + `ProjectionReportMessage` | `ProjectionRequestMessage` |
| materialize | 默认 stdout，不写文件 | `--output <path>` | 信封 + `MaterializationResultMessage(V2)` | `MaterializationRequestMessage(V2)` |
| convert | 默认 stdout | `--output <path>` | 信封 + `ConversionReportMessage` + target `SourceSnapshotMessage` | 源文件 + 两阶段请求 |
| edit | 是（dry-run 输出 `EditPlanMessage`/`SourcePatch`） | `--write` | 信封 + `EditPlanMessage` + `ChangeSet` 摘要 | 文件 + 编辑操作描述符 |
| plan | 是（plan manifest 只写 stdout 或 `--output`） | — | `core.batch-plan@1` | 文件清单 + 编辑操作 |
| apply | 否 | `--apply`（显式确认参数） | `core.batch-result@1` | `core.batch-plan@1` |
| conformance | 是 | — | 信封 + suite 报告 | 内嵌自检子集（§8.4） |
| explain | 是 | — | 信封 + 契约/错误码/Profile 记录 | code/contract 名 |

全局规则（§10 第 803-816 行逐条落实）：

- **默认只读或 dry-run**：没有任何命令在无显式参数时写目标文件（§22.6"CLI 默认 dry-run，写操作有 precondition"）。
- **写入必须显式确认参数**：统一 `--write`/`--apply`/`--output` 三档；`--apply` 只能消费先前 `plan` 产生的 batch-plan manifest，不接受裸操作（第 804 行）。
- **stdout 输出数据，stderr 输出诊断**（第 805 行）：所有 human 诊断、progress、redaction 提示走 stderr；stdout 在 `--json` 下只有一行规范 JSON（信封），非 `--json` 下只有命令结果数据。
- **CLI 的便利选择不能成为核心语义默认值**（第 818 行）：duplicate policy、lossy 授权、编码选择等全部由显式参数或请求 payload 给定，CLI 只要求用户选择、绝不替用户静默选择（§3.3 强制路径）。
- **不在 parse/query/project 中执行配置里的程序**（第 816 行、§19.2 第 1719-1732 行）：CLI 不新增任何求值、import、网络或环境读取路径。

### 2.2 exit code 分类（v1 candidate，RFC 0015 冻结；§15.6"冻结为 v1 candidate"）

| 分类 | 码 | 触发（稳定映射，禁止自由发挥） |
|---|---|---|
| success | 0 | 命令完成并输出完整结果——**包括** Recovered 状态报告、歧义事实报告、未授权损失报告（报告本身就是结果） |
| usage | 1 | 参数/语法错误、未知命令、`--format` 缺失或非法、`--apply` 无前置 plan |
| data | 2 | `FatalFormationFailure`、encoding source-contract 冲突、操作要求显式选择而用户未给（歧义不可解析） |
| limit | 3 | 任一资源上限（`ParseLimits`/`ProtocolLimits`/CLI 层文件大小上限等） |
| precondition | 4 | stale base digest、original-bytes 前置条件不匹配、编辑冲突、权限/磁盘失败、symlink 政策拒绝、apply 中断后不可继续项 |
| internal | 5 | 未分类内部错误（bug；报告模板含命令、文件、诊断码） |

设计要点：**exit code 表示"操作是否产出完整结果"，不代表数据的健康状态**——`consema inspect` 对 Recovered 文件退出 0（报告完整），而 `consema query` 对无法形成 Complete 文档的输入退出 2。分类函数是纯函数（M2 放 consema-protocol，向量可测，§8.2），bin 只做映射。用户中断（Ctrl+C）的码与恢复语义由 RFC 0015 冻结（graceful shutdown 先落 manifest 再退出）。

### 2.3 机器信封与错误分类（semantic-model v7）

机器输出统一为版本化信封（候选契约名 `core.cli-output@1`，RFC 0015 冻结最终名单）：

```text
core.cli-output@1（固定字段 PortableValue，双传输）：
  command（inspect/capabilities/query/...）
  exit_class（success/usage/data/limit/precondition/internal）
  product_version
  payload（命令专属：既有 protocol 消息或 CLI 记录）
  diagnostics（[DiagnosticMessage]）
  redaction（{redacted: bool, count: int}，§4.4）
```

- **CLI 机器 schema 必须是语言无关的语义模型 payload**：Go CLI（0.19.0）要产出同一 machine-readable output schema（§22.6），双语言一致性清单覆盖 projection/materialization report（§11.2）——只有走固定字段 PortableValue + canonical JSON/PVCE 双传输 + typed decoder 重验的老路，才能被语言无关向量证明（protocol-v1/v2 双传输等价 32 个 case 先例，IMPLEMENTATION.md 第 337 行）。
- 错误分类：CLI 层错误码进 `ErrorCodeRegistry::v7()`（`cli.usage.*`、`cli.detection.*`、`cli.write.*`、`cli.interrupted.*` 等，命名模式照 `hcl.parse.*@1` 先例）；格式层诊断继续使用既有 166 条 + 各格式本地 code 常量，CLI 只传递不改写。
- 每个 v7 payload 的 decoder 重新验证交叉约束（照 v6 先例：不能仅凭 schema discriminator 绕过，IMPLEMENTATION.md 第 443-445 行）。

### 2.4 人类输出

`output.rs`：每命令一个 human 渲染（表格/缩进文本），所有值先过 `redact.rs`；`--json` 时输出规范 JSON（复用 `encode_json`，另加自写的确定性缩进渲染，§5.2）。人类输出与机器输出永远一致的数据来源（同一 facade 调用结果，只是渲染不同）。

## 3. registry 与 auto-detection 安全边界

### 3.1 全格式 registry（§14.11）

`registry.rs` 是**facade 既有类型的薄枚举**，不是新 registry：

- 格式家族：8 个 `FormatFamilyId`（`consema-core`）；
- Profile：`consema::document::ProfileId` 的 id 清单（`ini.portable`、`java-properties.reader`、`xml.1.0-safe`、`plist.xml`、`hcl.native` 等，全部来自 facade/backend 既有常量，lib.rs 再导出）；
- 查询域：`QueryDomain` 既有构造器清单；
- 操作：各格式 `format_operation_registry()` 描述符；
- 错误码：`ErrorCodeRegistry::v7()` 清单 + 各格式本地 code 常量清单。

`consema capabilities` 输出该清单（含每个 Profile 的 capability 声明与 conformance 证据指向）；`consema explain` 输出单项权威解释（契约定义、错误码含义、Profile 结构规则）。数据全部派生自 SDK 自身类型——**CLI 对格式的任何知识都来自 facade，不重复声明**（§11 兼容性说明）。

### 3.2 auto-detection 只返回置信事实或歧义（§14.11 硬门禁）

`detect.rs` 对输入文件输出**事实清单**，每项带确定性标记：

| 事实类 | 内容 | 示例 |
|---|---|---|
| 字节事实 | 大小、SHA-256 digest | `sha256:<hex>` |
| 编码事实 | BOM 检测（无/UTF-8/UTF-16LE/UTF-16BE），不含猜测的 codepage | `bom: utf-16le` |
| 结构 marker 事实 | 前导字节可确定的签名（**只作事实，不作结论**） | `bplist00` 头；`<?xml`；首非空白 `{`/`[`；`[section]` 行；`key=value` 行；`%YAML`；`a = 1` 形 |
| 候选 Profile | 从 marker 可推出的候选集，**每个候选附理由** | `candidates: [ini.portable@1, java-properties.reader@1]`（`key=value` 行） |
| 歧义 | 候选集 > 1 时的一等结果 | `ambiguous: true, reasons: [...]` |

强制规则（对照 §3.3"默认不猜测"第 183-200 行与 §10 第 818 行）：

1. **永不输出单一"这是 X 格式"结论**；扩展名、magic、BOM 都只是事实（plist 先例：CHANGELOG 0.10.0"magic number 与 `.plist` 扩展名都不选择 Profile、representation 或 encoding"）。
2. **任何需要 parse 的命令必须显式 `--profile`/`--format`**；不提供"多方言都试一次"的自动尝试（INI 先例：IMPLEMENTATION.md 第 132 行"不提供'多方言都试一次'的自动检测"）。
3. 歧义时操作失败（exit 2，data 类），消息列出候选 + 理由 + 用法提示；`consema inspect` 本身报告歧义成功（exit 0，报告即结果）。
4. 检测事实不携带任何执行授权：detect 永不 parse、不打开文件之外的内容、无副作用。

### 3.3 显式选择的强制路径

- `--profile`（或 `--format`）在 parse 类命令上是**必选参数**，缺失即 usage 错误（exit 1），而不是"试试看"。
- 投影/物化/转换的 policy 参数（duplicate、lossy、encoding、EntryMapping/RequireObject 等）沿用各格式请求 payload 的显式字段；CLI 提供 `--policy` 帮助输出（来自 registry 描述符），但默认值只取 SDK 的保守默认（未授权 loss 即失败），CLI 不发明默认策略。

## 4. atomic write、batch manifest 与 secret redaction

文件系统写入是首次实现（IMPLEMENTATION.md 第 453 行 0.8.0 明确边界；路线图 §6 第 497-508 行：文件系统应用链条属于 CLI/application 层）。设计逐条对应 §10 第 809-815 行。

### 4.1 fsio.rs：同目录临时文件 + 原子替换（第 811-812 行）

- 写流程：目标同目录创建唯一临时文件（`{name}.consema-{pid}-{nonce}.tmp`）→ 写入渲染字节 → flush → 按 OS 语义原子替换（POSIX `rename`；Windows `std::fs::rename` 的 REPLACE_EXISTING 语义）→ 读回验证 target digest。
- **权限/所有者政策**：临时文件创建为受限权限（POSIX 0600）；替换前把目标文件既有权限/所有者（OS 支持时）复制到临时文件；Windows 只读属性与 ACL 行为在实现期实测并在 RFC 记录（跨平台验证是 0.13.0 门禁，§15.4）。
- **symlink 政策**（第 815 行）：写入路径默认拒绝 symlink/junction 目标（报告 `cli.write.symlink-policy@1`），`--follow-symlinks` 显式授权；inspect 报告 symlink 事实。
- **换行与编码政策**（第 815 行）：CLI 不转码、不改换行——读原始字节进 `SourceSnapshot`，写渲染后的原始字节（`Document::render()` 字节精确，IMPLEMENTATION.md 第 73 行）；UTF-16/ISO-8859-1 文件全程按 encoding 事实直通。
- **不声称跨文件系统多文件原子性**（第 812 行）：fsio 只承诺单文件原子替换；多文件事务不存在，`apply` 的"批量原子性"是 manifest 状态机的可恢复性，不是文件系统事务。
- 失败清理：临时文件残留由 `Drop`/退出钩子清理；中断时 manifest 先落盘（§4.2）。

### 4.2 batch manifest 状态机（第 809、813 行）

`core.batch-plan@1`（plan 产出，只读）：

```text
schema / product_version / command
files: [{ path, profile, source_digest（base 快照 digest）,
          operations（编辑摘要，human 视图已 redact）,
          source_patch（base_digest、encoding_facts、ordered replacements、target_digest）}]
```

`core.batch-result@1`（apply 产出）：

```text
files: [{ path, status: completed | failed | pending | skipped-stale,
          failure_code, target_digest, redacted: bool }]
```

- **写入前重验**（第 810 行、§26.6 第 2192 行"stale digest 和 original bytes 双 precondition"）：apply 每文件先重读文件、重算 digest 与 manifest 的 `source_digest` 比对（stale → `skipped-stale`，exit 4 分类），再逐 replacement 验证 original-bytes 前置条件（`SourcePatch` 语义，SECURITY.md 第 22 行），全部通过才写。
- **中断恢复**（第 813 行）：apply 在每文件写入**前**把该文件标记落盘（顺序：pending 状态先落 → 执行 → completed 后落），崩溃/中断后重跑 apply 用 manifest 判断：completed（digest 相符）跳过、failed 重报、pending 重做。manifest 的写入顺序是 R-5 风险点。
- dry-run/commit 等价（IMPLEMENTATION.md 第 318 行）：plan 的 replacements 与 target digest 必须与最终写入一致，apply 结束后重读验证 target digest。

### 4.3 请求/结果的外部化

`manifest.rs` 只做状态机与字节编码，具体规划/执行全部委托 SDK（EditTransaction dry_run → `EditPlan`/`SourcePatch`；apply 侧委托 `SourcePatch` 的字节验证逻辑）。CLI 不重新实现任何 digest、patch 或编辑语义（§11）。

### 4.4 redact.rs：secret 脱敏（第 814 行）

- **作用域**：只影响 review/debug/human/机器展示，**绝不删除 SourcePatch 应用所需的字节前置条件**（SECURITY.md 第 22 行明文）。
- **检测**：v1 保守键名模式集（RFC 0015 冻结清单）：`(?i)(password|passwd|secret|token|api[_-]?key|private[_-]?key|access[_-]?key|credential|auth)` 形键名 + 显式 `--redact-keys <glob>` 追加；值形状推断默认关闭（防误报），可由策略参数开启。
- **行为**：stderr 诊断、human 输出、plan 的 human 视图默认脱敏；机器输出中脱敏值替换为 `"$REDACTED$"` 占位并设 `redaction.redacted = true`（脚本可感知）；`--show-secrets` 显式取消（唯一通道）。
- 误报方向：宁可多脱敏不可漏脱敏（保守默认）；脱敏结果可复现、可测试（§8.2 向量 + hardening）。

## 5. 复用 vs 新写决策

### 5.1 参数解析：自写，不加 clap（推荐）

仓库依赖政策（deny.toml `[sources]` 仅 crates.io 钉版）与零新依赖传统（plist base64/date 自写先例，plist-implementation-plan.md §3.2-3.3）下，clap 及其传递依赖不可接受。CLI 参数面固定且窄（11 个命令 × 少量子参数），自写确定性解析器约 250-350 行 + 测试，不引入任何解析歧义（无 shell 语义、无模糊匹配——`args.rs` 拒绝未知参数、拒绝缩写猜测）。

### 5.2 机器 JSON 输出：复用 protocol 传输 + 自写缩进渲染（推荐）

- 传输编码复用 `encode_json`/`encode_pvce`（canonical，protocol value_transport.rs）——**绝不引入 serde_json**（其宽松 JSON 语义与仓库 canonical JSON 纪律冲突）。
- 人类友好的缩进 JSON（`--json --pretty`）：自写确定性缩进器（~100 行），只对 canonical JSON 字节做纯格式化，不做解析重排——保持字节确定性（canonical 语义不变，仅空白）。

### 5.3 其余新写点（无复用歧义）

- **fsio**（§4.1）：同目录临时文件、原子替换、权限复制、只读属性处理，~400-600 行 + 失败注入测试（仓库无现成文件原子层；IMPLEMENTATION.md 明示未实现）。
- **redact**（§4.4）：模式匹配 + 展示替换，~200-350 行。
- **detect**（§3.2）：marker 表 + 事实装配，~300-450 行；候选/歧义表以向量定格（§8.2）。
- **human 输出**：每命令渲染器，~500-800 行。
- **e2e 测试**：`crates/consema/tests/cli_*.rs` 用 `env!("CARGO_BIN_EXE_consema")` 启动二进制（cargo 内建，零 dev-dependency），覆盖 exit code、stdout/stderr 分流、plan/apply 全流程、失败注入、中断恢复（§8.3）。

## 6. 里程碑拆分

10 个里程碑，按依赖排序。`M` 为必须串行（前驱产物直接输入），`‖` 为可并行（文件域隔离，互不 import 对方中间产物；仅依赖共享的 consema-protocol v7 与已完成里程碑的公共 API）。

与格式计划的差异：CLI 是 application 层，无 parser 级串行链；并行机会集中为**一波三路（M4‖M5‖M6）**+ 收口期 **M9‖M10**。M1（RFC）必须先于一切（§12.3 第 948 行 RFC-first）。

| # | 里程碑 | 依赖 | 并行性 | 预估行数 | 交付物 |
|---|---|---|---|---|---|
| M1 | RFC 0015（CLI machine protocol 与 batch apply） | — | 串行起点 | 1400-1800（文档） | `docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md`（§12.3 要求十件套：动机/非目标/数据模型/状态机/错误代数/资源限制/安全/版本/conformance/rejected alternatives） |
| M2 | semantic-model v7：CLI payloads + typed decoders + CLI error codes | M1 | 串行 | 1500-2100 | consema-protocol：`cli.rs`（`core.cli-output@1`/`core.batch-plan@1`/`core.batch-result@1` 类型 + decoder 重验）、`ContractRegistry::v7()`、`ErrorCodeRegistry::v7()`、`RegistryManifest::v7()`、exit-code 分类纯函数 |
| M3 | bin 骨架：args/dispatch/exit-code 接线/stdout-stderr | M2 | 串行 | 900-1300 | `src/bin/consema/main.rs` + `args.rs` + `output.rs` 骨架、workspace 门禁接线 |
| M4 | registry + capabilities + inspect + explain + detect | M3 | ‖ 与 M5/M6 并行 | 1800-2400 | `registry.rs`、`detect.rs`、`inspect.rs`、`capabilities.rs`、`explain.rs` |
| M5 | query/project/materialize/convert 命令 + `--json` + protocol 请求输入 | M2、M3 | ‖ 与 M4/M6 并行 | 1600-2200 | `query_cmd.rs`、`project_cmd.rs`、`materialize_cmd.rs`、`convert_cmd.rs`、机器输出接线 |
| M6 | redact + fsio 原子写引擎 | M3 | ‖ 与 M4/M5 并行 | 900-1300 | `redact.rs`、`fsio.rs`（含失败注入单元测试） |
| M7 | edit + plan：batch-plan v1 生成 | M2、M5 | 串行 | 1200-1700 | `edit_cmd.rs`（dry-run）、`plan.rs`、`manifest.rs`（plan 侧）、human 视图 redaction |
| M8 | apply：batch-result、中断恢复、e2e | M6、M7 | 串行 | 1400-2000 | `apply.rs`、`manifest.rs`（result 侧）、`tests/cli_plan_apply.rs`（stale/冲突/权限/磁盘/中断注入，§15.6） |
| M9 | conformance 命令 + cli-v1.json 向量 + runner + hardening | M2、M8 | ‖ M10 | 2000-2800 | `conformance_cmd.rs`、`conformance/vectors/cli-v1.json`、`crates/consema-conformance/src/cli_v1.rs`、`tests/cli_hardening.rs`、`tests/cli_e2e.rs` |
| M10 | 文档 + 发布门禁 | M2-M8 公共 API | ‖ M9 | 1500-2500（文档） | CHANGELOG 0.12.0、IMPLEMENTATION.md 更新（crate 边界表 + v7 章节）、cookbook/migration guide、全格式工作流示例、`docs/BENCHMARKS-0.12.0.md`、verify-package-archives 全量 |

总规模估计：bin 源码 9.5k-14k 行（对照 plist/hcl 计划 crate 规模的一半左右，application 层无 parser 权重），conformance 资产 2k-3.5k 行，文档另计。实施节奏：M1 → M2 → M3 → [M4 ‖ M5 ‖ M6] → M7 → M8 → [M9 ‖ M10]。

### M1 — RFC 0015（串行起点）

范围：`docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md`。冻结内容：11 命令的机器 schema（v7 payload 名单与固定字段）、exit code 分类表（§2.2）、batch-plan/batch-result 状态机（§4.2）、fsio 政策（临时文件命名/权限/只读/symlink/换行/编码，§4.1）、redaction v1 键名清单（§4.4）、检测事实与歧义语义（§3.2）、错误代数（`cli.*` 码族）、资源限制（CLI 层文件大小/批量上限）、安全（无副作用链、路径穿越、临时文件竞态）、版本（v7 additive）、conformance（§8 向量范围）与 rejected alternatives（含"全 CLI 本地 schema 不走 v7"与"引入 clap/tempfile 依赖"的反驳理由）。

验收门禁：RFC 十件套齐全（§12.3 第 950 行）；与 §10/§14.11/§15 逐条对照表；rejected alternatives 记录完整。

### M2 — semantic-model v7（串行）

范围：
- `crates/consema-protocol/src/cli.rs`：三个候选 payload 的固定字段 PortableValue 类型（复用 `ContractDescriptor`/`ProtocolMessage` 机制）+ typed decoders，decoder 重验交叉约束（command/exit_class/payload 一致性、digest 表示、状态机合法迁移、limits）。
- `ContractRegistry::v7()`（38 + N 条）、`ErrorCodeRegistry::v7()`（166 + `cli.*` 族）、`RegistryManifest::v7()`；`current()` 指向 v7。v1-v6 冻结断言沿用既有 conformance 测试。
- exit-code 分类纯函数（错误分类 → exit code 的 exhaustive 映射，§2.2）。

验收门禁：`cargo test -p consema-protocol`；v1-v6 冻结断言全绿；新 payload 双传输（canonical JSON ↔ PVCE）round-trip 测试；非法状态迁移/篡改 payload 被 decoder 拒绝；exit 分类函数穷尽矩阵（每个错误族 → 码）；clippy/fmt/missing_docs。

### M3 — bin 骨架（串行）

范围：`main.rs`（命令派发表、全局 `--json`/`--profile`/`--output` 解析、exit code 接线、stderr 诊断通道）、`args.rs`（自写解析器 + 未知参数拒绝 + 帮助文本）、`output.rs` 骨架（human 渲染器注册表 + `--json` 信封输出 + `--json --pretty` 缩进器）。**占位命令不得出现**：M3 只接已实现的命令，未实现的命令不进入派发表（调用即"未知命令"exit 1），避免半成品假成功（§3.4 第 202-216 行"完成产物不能半成功"）。

验收门禁：`cargo test -p consema`（bin 单元测试）；`cargo build --bin consema`；参数矩阵测试（未知参数/缩写拒绝/帮助输出）；`env!("CARGO_BIN_EXE_consema")` 冒烟 e2e（`--help`、未知命令 exit 1、stdout/stderr 分流断言）；`cargo test --workspace`。

### M4 — registry + capabilities + inspect + explain + detect（‖ 并行）

范围：
- `registry.rs`：facade 类型枚举（§3.1）；`capabilities.rs` 输出清单（human 表 + 机器记录）。
- `detect.rs`：§3.2 事实表 + marker 判定 + 候选/歧义装配；**无 parse、无结论**。
- `inspect.rs`：文件事实报告（字节/digest/BOM/marker/候选/歧义 + `--profile` 时附加 parse 结果：formation status、诊断、结构计数）；`explain.rs`：从 registry + `ErrorCodeRegistry` 查词条。
- 本里程碑全部只读、无副作用（§19.2）。

验收门禁：检测事实向量矩阵（每类 marker 正例 + marker 碰撞歧义例：INI vs Properties、JSON vs JSON5、XML vs plist.xml、TOML 表 vs INI 区段）；`--profile` 缺失时 parse 类操作拒绝（usage exit 1）；inspect 对 Recovered 文件 exit 0 且报告完整；capabilities 清单与 facade 类型逐一相等断言（registry 与 SDK 不漂移）。

### M5 — query/project/materialize/convert（‖ 并行）

范围：四命令接线：
- 输入：`--request-file`/stdin 接受 canonical JSON 或 PVCE（`core.query-definition@1`/`ProjectionRequestMessage`/`MaterializationRequestMessage(V2)`），`decode_json`/`decode_pvce` 严格解码（拒绝非规范表示）。
- 执行：只调 facade（`as_*` 适配器 → 各文档 `query`/`project`/`materialize`；`convert_*`）；Recovered 文档的 project/materialize 拒绝沿用 SDK 语义（IMPLEMENTATION.md 第 285 行：Missing value、Recovered 文档、资源越界或 closure 不完整均整体失败）。
- 输出：机器 = 信封 + 既有 protocol 消息（`QueryResultMessage` 等）；human = `output.rs` 渲染。**机器输出必须与 SDK 直接 encode 字节相等**（§11 兼容性门禁的测试载体）。
- materialize/convert 的写文件仅经 `--output`（fsio 在 M6，故本里程碑先输出到 stdout/内存，不落盘）。

验收门禁：每命令 golden 用例（human + 机器双输出）；请求输入正反例（未知字段/重排字段/非规范表示被拒，照 protocol-v1/v2 向量体例）；机器输出字节相等断言（同操作 SDK encode == CLI --json）；Recovered 拒绝矩阵；exit code 分类矩阵。

### M6 — redact + fsio（‖ 并行）

范围：`redact.rs`（§4.4 模式集 + 展示替换 + `--show-secrets`/`--redact-keys`）；`fsio.rs`（§4.1 全部政策 + 失败清理 + 只读/权限处理）。本里程碑与命令无关，纯基础设施 + 单元测试。

验收门禁：redaction 矩阵（键名命中/误报方向/`$REDACTED$` 占位/机器 `redaction` 字段/`--show-secrets` 唯一通道/redaction 不触碰 patch 前置条件的断言——patch 应用前后字节不变）；fsio 失败注入（目标为目录、目标只读、临时目录不可写、rename 失败、中断残留清理）；同目录原子替换成功矩阵（内容替换后 digest 相符）；symlink 拒绝 + `--follow-symlinks`。

### M7 — edit + plan（串行）

范围：`edit_cmd.rs`（单文件 dry-run：EditTransaction → `EditPlanMessage` + `SourcePatch`；`--write` 留待 M8 接 fsio）；`plan.rs`（多文件批量：逐文件 parse → edit dry_run → 汇总 `core.batch-plan@1`，human 视图逐项 redact）；`manifest.rs` plan 侧（schema 编码 + 从 `--output` 或 stdout 落盘）。plan 全程只读（plan manifest 是产物，不是授权——IMPLEMENTATION.md 第 318 行）。

验收门禁：dry-run 等价断言（同一输入的 plan 与未来 commit 的 replacements/digest 一致，先在库内断言 dry_run 输出）；batch-plan golden 字节；多文件计划（含一个失败文件 → 该文件 `failed` 入 manifest，其余照常，**不整批失败也不伪装成功**，§3.4）；redaction 在 plan 视图的覆盖。

### M8 — apply（串行）

范围：`apply.rs`（读 plan → 逐文件：重读/重验 digest → original-bytes 前置条件（委托 `SourcePatch` 验证）→ fsio 写 → 读回验 target digest → 落 result manifest）；`manifest.rs` result 侧（completed/failed/pending/skipped-stale 状态机 + 中断恢复）；`tests/cli_plan_apply.rs` e2e：stale digest（plan 后改文件）、original-bytes 不匹配、编辑冲突、权限拒绝、目标只读、磁盘失败注入、**中断恢复**（apply 中途 kill 子进程 → 重跑 → completed 跳过/pending 重做）、symlink 政策；`edit_cmd.rs` 的 `--write` 复用同一引擎。

验收门禁（§15.6"patch/apply 具备中断、冲突、权限和磁盘错误测试"、§16.x e2e）：上述注入矩阵全绿；中断恢复状态机断言（manifest 顺序：pending 落盘先于写入）；跨文件互不影响断言；exit code 4 分类矩阵。

### M9 — conformance 命令 + 向量 + runner + hardening（‖ M10）

范围：
- `conformance/vectors/cli-v1.json`：suite `consema.cli.conformance@1`。case 覆盖：v7 信封双传输等价（canonical JSON ↔ PVCE 字节相等）；exit-code 分类矩阵（每错误族）；batch-plan/batch-result 状态迁移（含非法迁移负例）；redaction 展示策略（presentation-only 断言）；检测事实矩阵（marker → 事实/候选/歧义）。协议层向量由 `crates/consema-conformance/src/cli_v1.rs` 在库侧执行（照 plist_v1.rs 体例：SUITE 常量、include_str、capability 分派、suite id 检查、数据驱动）。
- `conformance_cmd.rs`：内嵌自检子集（信封 round-trip、exit 分类、redact 自检），输出 suite 报告（机器格式）；完整语言无关 suite 仍由 `cargo test -p consema-conformance` 执行（发布物不含仓库 fixtures——consema-conformance `publish = false` 先例，IMPLEMENTATION.md 第 65 行）。
- `tests/cli_hardening.rs`：路径穿越、超长路径、非法 UTF-8 文件名、超限文件、畸形 plan 输入、篡改 plan digest——不 panic、不写错目标。
- `tests/cli_e2e.rs`：§22.6 工作流示例（真实规模夹具批量 plan/apply，§10 全命令冒烟）。

验收门禁：全套 suite 计数 17 → 18 全绿；向量数据驱动（改期望必失败）；hardening 不 panic；e2e 全命令矩阵。

### M10 — 文档 + 发布（‖ M9）

范围：CHANGELOG 0.12.0（Unreleased 体例）；`docs/IMPLEMENTATION.md` 更新（crate 边界表 + semantic-model v7 章节 + CLI 章节：exit code/stdout-stderr/machine schema 冻结 v1 candidate 记录）；cookbook（每格式 inspect/query/project/edit 示例 + 每转换组合 loss policy 示例，§22.6 第 1926-1927 行）；migration guide；全格式真实工作流示例（§14.11 第 1318-1319 行）；facade public API 评审（CLI 暴露的缺口补公共 API）；`docs/BENCHMARKS-0.12.0.md`（CLI 冷启动、批 100 文件 plan/apply 基线，照 BENCHMARKS-0.9.0.md 体例）；`scripts/verify-package-archives.ps1` 对 14 个可发布 crate 全量（consema 现含 bin）。

验收门禁：文档评审；`cargo test --workspace` 全绿；发布门禁沿用仓库体例（conformance 全绿 + hardening + fixtures + benchmarks + verify-package-archives）。

## 7. 多 agent 并行化建议（文件域划分）

每个并行里程碑派发一个 agent，文件域互不重叠，仅共享已完成里程碑的公共 API：

| Agent | 文件域 | 里程碑 | 前置（公共 API 输入） |
|---|---|---|---|
| A | `docs/rfcs/0015-*.md` | M1 | 无（最先；只读调研成果即本计划 §2-§5 内容） |
| B | `crates/consema-protocol/src/cli.rs` + `contract.rs`/`error_registry.rs`/`registry_manifest.rs`（v7 增补） | M2 | M1 的 RFC 冻结名单 |
| C | `src/bin/consema/main.rs` + `args.rs` + `output.rs` 骨架 + `Cargo.toml` `[[bin]]` | M3 | M2 的 v7 类型与分类函数 |
| D | `registry.rs` + `detect.rs` + `inspect.rs` + `capabilities.rs` + `explain.rs` | M4 | M3 的派发与输出骨架 |
| E | `query_cmd.rs` + `project_cmd.rs` + `materialize_cmd.rs` + `convert_cmd.rs` | M5 | M2 的 codecs + M3 的骨架 |
| F | `redact.rs` + `fsio.rs` | M6 | M3 的骨架（独立，无需 M4/M5） |
| G | `edit_cmd.rs` + `plan.rs` + `manifest.rs`（plan 侧） | M7 | M2 + M5 的机器输出接线 |
| H | `apply.rs` + `manifest.rs`（result 侧）+ `tests/cli_plan_apply.rs` | M8 | M6 的 fsio + M7 的 plan 类型 |
| I | `conformance_cmd.rs` + `conformance/vectors/cli-v1.json` + `cli_v1.rs` + 两个测试 | M9 | M2 的 v7 + M8 的 manifest 状态机 |
| J | 文档 + CHANGELOG + IMPLEMENTATION + BENCHMARKS + 发布门禁 | M10 | M2-M8 全部公共 API（可与 I 同期） |

约束：
- D/E/F 三路并行时，`main.rs`、`args.rs`、`output.rs`、consema-protocol v7 为只读共享域；任何 API 调整须先经过 M3 稳定（M3 验收门禁含公共 API 冻结检查）。
- 向量 JSON 与 runner 必须同批（runner 是向量的唯一权威执行者，照 plist_v1.rs "vector data drives results" 体例）。
- e2e 测试（H）与向量（I）分工：H 覆盖进程级行为（exit code、fsio、中断恢复），I 覆盖库级协议语义——两类不可互替，缺一不得收口。

## 8. conformance 集成细节

### 8.1 向量套件命名

`consema.cli.conformance@1`（对齐 `consema.plist.conformance@1` 家族体例）：

```json
{
  "suite": "consema.cli.conformance@1",
  "profiles": [],
  "cases": [ ... ]
}
```

每 case：`id`（稳定）、`capability`（`cli.envelope@1`、`cli.exit-code@1`、`cli.batch-plan@1`、`cli.batch-result@1`、`cli.redaction@1`、`cli.detection@1`、`cli.limit@1`）、`input`（payload/预期/覆盖字段）、`expected`（双传输字节、状态迁移、exit class、redacted 标记）。

### 8.2 runner 模式

`crates/consema-conformance/src/cli_v1.rs` 对齐 plist_v1.rs 全模式：SUITE 常量 + include_str；`run_cli_v1()`/`run_cli_v1_json()`；suite id 校验；case id 去重；按 capability 分派处理器（协议层在库侧执行：v7 类型 decode → 重验 → 双传输比较；exit 分类走分类函数；状态机走 manifest 类型）。测试：全量通过（`report.passed.len()` 断言，与向量同批更新）、suite id 篡改失败、输入篡改失败。

### 8.3 e2e 测试（进程级，零 dev-dependency）

`crates/consema/tests/cli_*.rs` 通过 `env!("CARGO_BIN_EXE_consema")` 启动二进制：stdout/stderr 分流断言、exit code 矩阵、plan→apply 全流程、失败注入（stale/冲突/权限/磁盘/只读/中断）、机器输出与 SDK encode 字节相等（§11 门禁的自动载体）。

### 8.4 conformance 命令边界

`consema conformance` 在发布物中执行内嵌自检子集（信封 round-trip、exit 分类、redact 自检——不依赖仓库 fixtures）；输出 suite 报告（机器格式）。完整语言无关 suite 保持仓库级（`cargo test -p consema-conformance`）。职责边界写入 RFC 0015（发布物不含 conformance/vectors，consema-conformance `publish = false` 先例）。

## 9. 风险清单与实现阶段复核点

| # | 风险/复核点 | 说明与缓解 | 复核时机 |
|---|---|---|---|
| R-1 | 零新依赖约束 | args/pretty-JSON/fsio 全部自写；若实现中发现需要 tempfile 类功能，一律自写（§5）；RFC 0015 记录该决策与 rejected alternative | M3、M6 |
| R-2 | exit code 与 Recovered/歧义的关系 | "报告即成功"与"操作失败"两义要严格分开（§2.2）；分类函数穷尽矩阵防漂移 | M2、M8 |
| R-3 | Windows 原子替换与权限 | `std::fs::rename` REPLACE_EXISTING 语义 + 目标只读属性/ACL 行为需实测；只读属性处理写入 fsio 政策；跨平台完整验证是 0.13.0 门禁（§15.4），0.12.0 必须在 Windows 上可用 | M6、M8、M10 |
| R-4 | symlink/junction 政策跨平台 | Windows junction/reparse point 的读取与写入语义不同；inspect 报告事实、写入默认拒绝 | M4、M6 |
| R-5 | 中断恢复的 manifest 写入顺序 | 必须"先落 pending 再执行、后落 completed"；若先写文件后落 manifest，崩溃会造成 completed 漏记（重跑将重写）或 pending 误标；顺序以测试定格 | M8 |
| R-6 | redaction 边界 | 误报（正常值被脱敏）与漏报（secret 泄露）双方向：v1 只做键名保守匹配 + 占位符 + `redacted` 事实；绝不触碰 patch 前置条件（SECURITY.md 第 22 行） | M6、M9 |
| R-7 | 检测 marker 假阳性 | `[section]`/`key=value`/`<?xml` 等多格式碰撞——facts-only + 必选 `--profile` 保证假候选永不产生错误行为；歧义是报告不是猜测 | M4、M9 |
| R-8 | CLI/SDK 语义入口漂移 | 机器输出字节相等门禁（CLI --json == SDK protocol encode）作为常设测试；CLI 出现新格式知识（非 facade 来源）即失败 | M5 起每里程碑 |
| R-9 | 大文件/大批量资源预算 | CLI 层文件大小上限（RFC 冻结默认值 + `--max-bytes`）、批量文件数上限、plan manifest 大小预算；超限 = limit 分类（exit 3），不截断伪装成功（§3.4） | M5、M7、M8 |
| R-10 | 并发 apply 竞态 | 两个 apply 同时写同一文件：digest 前置条件重验是唯一防线；文档明示"无跨进程文件锁"（§4.1 不声称跨文件系统原子性） | M8 |
| R-11 | 编码处理 | UTF-16/ISO-8859-1 文件 raw bytes 直通 `SourceSnapshot`；CLI 层禁止任何转码/换行改写；inspect 的编码事实来自 encoding resolution 而非猜测 | M4、M5 |
| R-12 | v7 与冻结注册表 | additive 增补，v1-v6 冻结断言复用；`current()` 指向 v7 后旧 conformance 显式绑定旧 registry 的既有测试必须保持全绿 | M2 |
| R-13 | Go CLI 一致性 | machine schema 内不得出现 Rust 类型名或 process-local 身份（§15.2）；payload 全部走语义模型路径，CLI 二进制只是驱动 | M2、M10 |
| R-14 | conformance 命令职责边界 | 内嵌子集与仓库级 suite 的分工写入 RFC；发布物不引用仓库 fixtures；`consema conformance` 的 suite 报告格式同样走 v7 信封 | M9 |

## 10. 验收门禁总表（对照仓库既有体例）

| 门禁 | 体例来源 | 适用里程碑 |
|---|---|---|
| `cargo test -p consema` / `-p consema-protocol` + clippy `-D warnings` + fmt + missing_docs | 仓库开发门禁 | 每个里程碑 |
| `cargo test --workspace` | 发布门禁 | M3 起每个里程碑 |
| v1-v6 注册表冻结断言（v7 增补不破坏） | consema-protocol 既有 conformance | M2 |
| 新 payload 双传输等价（canonical JSON ↔ PVCE）+ decoder 篡改拒绝 | protocol-v1/v2 向量体例 | M2、M9 |
| 机器输出字节相等（CLI `--json` == SDK protocol encode） | §11 兼容性说明的自动载体 | M5 起每里程碑 |
| 检测事实/歧义矩阵数据驱动 | 向量数据驱动体例（改期望必失败） | M4、M9 |
| plan/apply 失败注入：stale digest、original bytes、冲突、权限、磁盘、只读、symlink、中断恢复 | §15.6、§16.x、§22.7 | M8 |
| e2e：exit code 矩阵 + stdout/stderr 分流 + 全命令冒烟 | `env!("CARGO_BIN_EXE_consema")` | M3 起每里程碑 |
| hardening 不 panic + 覆盖闭包 | tests/plist_hardening.rs 体例 | M9 |
| 全套 suite 计数（0.12.0：18 套全绿） | CHANGELOG/RELEASE 记录体例 | M10 |
| 打包/解包验证（14 个可发布 crate，consema 含 bin） | scripts/verify-package-archives.ps1 | M10 |
| 性能基线文档 BENCHMARKS-0.12.0.md（CLI 冷启动/批量 plan-apply） | docs/BENCHMARKS-0.9.0.md 等 | M10 |
| 临时文件权限与 redaction 跨平台验证 | §15.4——**0.12.0 实现并 Windows 验证；Linux/macOS 全量验证归 0.13.0** | M6、M8（0.12）/0.13 门 |
| M5/M7/M8 边界 API 评审（M10 移交 8 项：native 域 locator、provenance 空 map、project 报告 json/toml 限定、格式 code fallback、失败记录形态、java-properties 族前缀 bug、edit 词表 INI 限定、`edit --write` 未接线） | 逐项 disposition 已记录于 `docs/0.13.0-gate-plan.md` §4 M4（B-1..B-8）；修复项 B-6/B-8 为 0.13.0 优先 | M10（评审）+ 0.13.0 M4 |

## 11. 兼容性说明：CLI 不是第三个实现

路线图 §1（第 135 行）："CLI 是产品入口，但不是规范权威，也不是第三个实现。"本计划的强制执行机制：

1. **编译期强制**：bin 与 lib 同包，bin 只能访问 lib 的 public API（§0.3）。CLI 对格式的全部知识来自 facade 的 `Document`/`convert_*`/再导出类型——`src/bin/consema/` 中不存在任何 parse/query/project/materialize/edit/convert 的实现代码；每命令是"参数 → facade 调用 → 渲染"的薄驱动。
2. **语义入口测试**：机器输出字节相等门禁（CLI `--json` == 同操作 SDK protocol encode）证明 CLI 与 SDK 输出同一语义（§14.11 硬门禁"CLI 与 SDK 使用同一语义入口"）。
3. **registry 单一来源**：`registry.rs` 的清单派生自 SDK 类型（§3.1），CLI 不重复声明格式知识；capabilities 与 facade 类型逐一相等断言防漂移。
4. **便利性不改变核心语义**（§10 第 818 行）：duplicate/lossy/encoding 等政策一律由用户显式选择或请求 payload 给定，CLI 不发明默认策略（§3.3）。
5. **面向 Go 的契约**：CLI machine schema 是 semantic-model v7 语言无关 payload（§2.3），Go CLI（0.19.0，§22.6）实现的是同一协议——schema 是契约，Rust CLI 二进制只是该契约的第一个驱动。CLI 便利层（人类输出、脱敏展示、检测事实）不属于跨语言契约，不进入语义模型。
6. **CLI 文件 I/O 是 application operation**（§19.2、§24"CLI 文件读写不等于配置来源合并系统"）：fsio/plan/apply 全部在 bin 层，Document 核心与 backend crate 的"无副作用"不变量不受影响（§19.2）。
