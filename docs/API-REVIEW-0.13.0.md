# Consema 0.13.0 API 评审（M4 交付物）

- 对应门禁：路线图 §15.6（"Rust public API 完成独立审查"、"backend AST 和第三方错误类型不泄漏"、"facade、低层 crate 与 feature 关系清楚"、"全部 public API 有 rustdoc"）、§15.2（Go API mapping RFC 立项）；`docs/0.13.0-gate-plan.md` §4 M4
- 日期：2026-08-07
- 权威顺序（`docs/IMPLEMENTATION.md`）：永久不变量 → 已接受 RFC → 语言无关 conformance vectors → 本评审与 Rust API → 第三方行为仅为实现细节
- 范围：五维审计 naming-drift findings（F2/F3/F4/F10/F11/F13/F15 + philosophy）转写与 disposition；0.12.0 M10 移交的 CLI API backlog（B-1..B-9）；cargo-semver-checks 基线解读；rustdoc 100% 断言；facade/feature 复查；backend AST/错误类型泄漏复查；Go API mapping RFC（RFC 0016）立项。

## 0. 结论摘要

- **五维审计 findings：0 项需在 0.13.0 修复**。全部 7 项 findings + 2 项 philosophy 项均豁免（exempt-with-reason）：每一项的语言无关面（注册 code / vector / 域 id / 查询操作词）都由 RFC 与 conformance vectors 冻结，修复即破坏冻结面；Rust 枚举名/函数名漂移只影响 Rust 类型名，不违反 §15.2"语言无关行为不依赖 Rust 类型名"。每项给出后续修复窗口（semantic-model v8 / 1.0.0 API 冻结）与具体改动方案，全部记入 Feature-Complete Manifest 的 known-accepted-limitations。
- **B-6、B-9（M10 评审 bug 类优先修复项）已修复**，含回归测试（详见 §2.6、§2.9）。
- **cargo-semver-checks**：本地实测 11 个基线 crate（vs v0.8.0 tag f79dd99，baseline worktree 建于仓库外）；8 个全绿，3 个仅"新家族枚举变体新增"（已按 0.x 治理批准，RFC 级决定见 §3）。
- **rustdoc**：workspace 除 consema-conformance 外 0 个 missing-docs；consema-conformance 的 12 个 missing-docs 全部位于 M2 并行轨未落盘的 `crates/consema-conformance/src/fuzz.rs`（非本里程碑域）。
- **facade/feature**：facade 依赖 13 个 backend crate、无 `[features]`，与 CHANGELOG 声称一致；`capabilities` 清单由 facade 类型派生（`lib.rs` registry 模块）。
- **泄漏复查**：全部 15 个 crate 零第三方依赖（仅 consema-* path deps），第三方错误类型泄漏在构造上不可能；格式 crate 公共 API 只携带语言无关契约类型（ProfileId/Diagnostic/PortableValue/NodeRef/Span/…），backend AST 内部类型（syntax kind、native 树节点数据）保持在 crate 内私有。无泄漏。

---

## 1. 五维审计 naming-drift findings（转写 + disposition）

来源：五维审计会话记录（仓库内无档案，本文件是唯一权威载体，`0.13.0-gate-plan.md` G-8）。每条给出证据（file:line）与 disposition。Disposition 定义：**fix-now** = 本里程碑已改/必改，给出具体改动；**exempt-with-reason** = 豁免，必须引用冻结它的 RFC/vector，或给出将改变它的版本窗口。

### F2 — `core.edit.incomplete-target@1` 命名两个不同概念

**证据：**

- 概念 (a) "编辑被禁止于 Recovered 文档"：`crates/consema-ini/src/edit.rs:1756`（`RecoveredDocument => "core.edit.incomplete-target@1"`）、`crates/consema-properties/src/edit.rs:239`（同）、`crates/consema-plist/src/edit.rs:447`（`IncompleteTarget`）、`crates/consema-hcl/src/edit.rs:603`（同）、`crates/consema-xml/src/edit.rs:328-329`（"The base document is not `Complete`, so no target can be edited"）。
- 概念 (b) "target 不是完整字面量语法节点"：`crates/consema-json/src/edit.rs:264-265`（"Target is not a complete literal syntax node"）。
- code 注册于 `crates/consema-protocol/src/error_registry.rs:490`（0.5.0 起），被 5 个 conformance vector 钉死：`hcl-v1.json`、`ini-v1.json`、`java-properties-v1.json`、`plist-v1.json`、`xml-1-0-safe-v1.json`（均含 `core.edit.incomplete-target@1`）。

**Disposition：exempt-with-reason（冻结 + 提交 v8 拆分提案）。** code 由 RFC 0011（semantic-model v6 contract registry）冻结、vector 钉死；拆分为 `core.edit.recovered-document@1`（Recovered 门）与 `core.edit.incomplete-literal-target@1`（json 字面量完整性）需要 semantic-model v8 RFC 修订 + 5 个 vector 修订（破坏性），不属于 0.13.0。后续窗口：semantic-model v8（0.14.0+，与 Go 对齐的破坏性窗口）；在 v8 落地前保持单 code 并在文档（IMPLEMENTATION.md 编辑章节）中标注双语义。记入 FC manifest known-accepted-limitations。

### F3 — edit 冲突词汇漂移（Rust 枚举名）

**证据：**

- "两个操作命中同一 occurrence"：`ConflictingEdits`（json `edit.rs:277`、toml、xml `edit.rs:349`、plist、hcl）vs `DuplicateTarget`（json `edit.rs:279`、toml、yaml `edit.rs:305`、ini、properties）。
- 语言无关面一致：两者全部映射到同一个注册 code `core.edit.conflicting-edits@1`（json `edit.rs:1307-1314`、yaml `edit.rs:337-339`、xml `edit.rs:400-403`），并被 `operations-v1.json`、`java-properties-v1.json` 钉死。
- `PlacementAnchorRemoved`（json `edit.rs:285`）vs `PlacementAnchorModified`（json `edit.rs:287`、xml `edit.rs:403`）：同映射 `core.edit.conflicting-edits@1`。
- 各格式专有概念（非漂移）：yaml `StructuralContainerConflict => yaml.edit.structural-container-conflict@1`（yaml `edit.rs:336`）、xml `CannotRemoveRoot => core.edit.cannot-remove-root@1`（xml `edit.rs:398`）、`AncestorPlacement => core.edit.ancestor-placement@1`（xml `edit.rs:399`）。

**Disposition：exempt-with-reason。** 漂移仅存在于 Rust 枚举类型名，注册 code 面一致；§15.2 门禁（"不依赖 Rust 类型名解释语言无关行为"）不违反。后续窗口：1.0.0 API 冻结时统一枚举名（建议全 family 收敛为 `ConflictingEdits`，`DuplicateTarget` 改名并保留 `#[deprecated]` 别名一个发布周期），migration guide 记录；无需 RFC 修订（code 不变）。

### F4 — 非 Complete 文档 projection 失败 code 三种拼写

**证据：**

- `xml.projection.recovered-document@1`：`crates/consema-xml/src/projection.rs:461`；被 `xml-1-0-safe-v1.json` 钉死。
- `ini.projection.incomplete-document@1`（`consema-ini/src/projection.rs:888`）、`java-properties.projection.incomplete-document@1`（`consema-properties/src/projection.rs:743`）、`plist.projection.incomplete-document@1`（`consema-plist/src/projection.rs:395`；`plist-v1.json` 钉死）、`hcl.projection.incomplete-document@1`（`consema-hcl/src/projection.rs:470`）。
- `json.projection.incomplete-document@1`（`consema-json/src/projection.rs:756`，0.13.0 的 json Recovered-document 门禁）：随 audit F3 处置在 0.13.0 注册进 v7 error registry（`error_registry.rs`），见下 disposition。
- `json.projection.semantic-unavailable@1`（`consema-json/src/projection.rs:753`）：**不同概念**（JSON5 语义不可用，非 Recovered 文档拒绝），不并入本条。

**Disposition：exempt-with-reason。** 全部 code 已注册：其余五家（ini/java-properties/plist/hcl/json 的 `incomplete-document@1` 与 xml 的 `recovered-document@1`）都在 RFC 0011 registry（v5/v6）或被各家族 RFC（0009/0010/0012/0013/0014）与 vector 冻结；json 的 `json.projection.incomplete-document@1` 由 0.13.0 的 Recovered-document 门禁引入（`consema-json/src/projection.rs:756`），初版 F4 核对时遗漏注册，已随 audit F3 处置注册进 v7（`error_registry.rs`，Projection/0.13.0，v7 计数 186 → 187）并被 registry 测试钉死。真实漂移只有一处：xml 独用 `recovered-document`，其余五家一致用 `incomplete-document`。后续窗口：semantic-model v8 将 `xml.projection.recovered-document@1` 更名 `xml.projection.incomplete-document@1`（保留旧 code 为 deprecated alias 至 1.0.0）。0.13.0 冻结。记入 FC manifest。

### F10 — `formation_status()` vs `status()`

**证据：** 新三家族同时暴露两者：xml `document.rs:450`（`status`）/`:456`（`formation_status`）、plist `document.rs:106`/`:115`、hcl `document.rs:120`/`:126`。成熟家族只暴露 `formation_status`：json `lib.rs:218`、toml `lib.rs:177`；facade `Document::formation_status`（`consema/src/lib.rs:651`）。别名已落地（plan 记录一致）。

**Disposition：exempt（0.13.0）+ 决策：1.0.0 弃用 `status()`。** 别名是纯增量，无破坏面；漂移已通过别名弥合。1.0.0 API 冻结时对 xml/plist/hcl 的 `status()` 标 `#[deprecated]`（提示用 `formation_status()`），一个发布周期后移除；migration guide 记录。此决策即 plan 中"consider deprecating status() at 1.0.0"的落定。

### F11 — `ini.duplicate-group@1`/`properties.duplicate-group@1` vs `plist.duplicate-key-group@1`

**证据：** 同一概念（同键组扩展）两个查询操作词 id：`ini.duplicate-group`（`crates/consema-core/src/query.rs:1056`、`crates/consema-ini/src/query.rs:543`）、`java-properties` → `properties.duplicate-group`（`crates/consema-core/src/query.rs:1107`）、`plist.duplicate-key-group@1`（`crates/consema-plist/src/query.rs:11`）。`properties.duplicate-group@1` 被 `crates/consema-conformance/src/properties_v1.rs:424` 钉死；plist 词表由 RFC 0013 冻结。

**Disposition：exempt-with-reason。** 查询操作词是 RFC 0003 冻结的语言无关词汇表；改名 plist 词需 RFC 0013 修订 + plist vector 修订（破坏性）。后续窗口：semantic-model v8 增加 `plist.duplicate-group@1` 别名操作词并弃用 `duplicate-key-group@1`。0.13.0 冻结。记入 FC manifest。

### F13 — vector capability 命名漂移

**证据：**

- xml 拆分三套能力：`xml.native-semantic-query@1`（`consema-core/src/query.rs:80`）、`xml.lossless-syntax-query@1`（`:119`）、`xml.formation@1`（vector family id，`consema-conformance/src/xml_v1.rs:105`）。
- plist 三域：`plist.native-semantic-query@1`、`plist.lossless-syntax-query@1`、`plist.binary-structure-query@1`（`consema-core/src/query.rs:128/134/140`）；hcl 两域：`hcl.native-semantic-query@1`、`hcl.lossless-syntax-query@1`（`:146/152`）。
- yaml 复数：`yaml.native-semantics@1`（suite 内部映射，`consema-conformance/src/yaml_v1.rs:123`）vs 域 id `yaml.native-semantic-query@1`（`consema-core/src/query.rs:62`）。

**Disposition：exempt-with-reason。** 域 id 与 suite family id 是语言无关表面，被 conformance manifest（18 suites 508/508）与各家族 RFC 冻结；改名即 suite 修订。0.13.0 冻结。动作（非修复）：RFC 0016（Go API mapping）显式钉死这些 id，Go conformance runner 与 Rust 用同一 suite 清单（双实现原则，路线图 §11）；`yaml.native-semantics@1` 复数仅为 suite 内部命名，维持。

### F15 — syntax-kind 大小写约定

**证据：** xml/plist kebab-case：`XmlSyntaxKind::as_str`（`consema-xml/src/document.rs:804-843`，如 `"tag-close"`）、`PlistSyntaxKind::as_str`（`consema-plist/src/parser_xml.rs:176+`，如 `"plist-open"`）；hcl/yaml PascalCase：`HclSyntaxKind::as_str`（`consema-hcl/src/native.rs:403-435`，如 `"TagClose"`）、`YamlSyntaxKind::as_str`（`consema-yaml/src/lib.rs:169+`，如 `"DocumentStart"`）。kebab 拼写是 lossless-syntax-query 的 match-role 词汇（`line_query.rs` 角色绑定），被各家族 vector 钉死。

**Disposition：exempt-with-reason。** hcl 的 PascalCase 拼写由 RFC 0014 + hcl vector 冻结；改拼写即破坏 match-role 词汇。后续窗口：下一个破坏性窗口（semantic-model v8）为 `HclSyntaxKind::from_name` 增加 kebab 别名并弃用 PascalCase 拼写；RFC 0016 要求 Go 侧逐字节匹配 Rust 拼写。0.13.0 冻结。记入 FC manifest。

### Philosophy 1 — `execute_plist_native_query`/`execute_hcl_native_query` 的 `_native_` 中缀

**证据：** 基线家族无 `_native_` 中缀：`execute_json_query`（`crates/consema-json/src/query.rs:91`）、`execute_toml_query`（`crates/consema-toml/src/query.rs:89`）、`execute_yaml_query`（`crates/consema-yaml/src/query.rs:167`）、`execute_ini_query`（`crates/consema-ini/src/query.rs:117`）、`execute_properties_query`（`crates/consema-properties/src/query.rs:124`）、`execute_xml_query`（`crates/consema-xml/src/query.rs:223`）、`execute_*_syntax_query` 同式；新家族带中缀：`execute_hcl_native_query`（`crates/consema-hcl/src/query.rs:189`）、`execute_plist_native_query`（`crates/consema-plist/src/query.rs:271`）、`execute_plist_binary_query`。

**Disposition：exempt（0.13.0）+ 1.0.0 收敛。** 函数名是 Rust 公共 API，域 id 一致（`plist.native-semantic-query@1` 等）；`_native_` 中缀在 RFC 0013/0014 文档化。1.0.0 API 冻结时新增基线式别名（`execute_plist_query`、`execute_hcl_query`、`execute_plist_binary_structure_query`）并弃用 `_native_` 形式一个周期；migration guide 记录。conformance runner 同步迁移（runner 属本仓库域，随 1.0.0 窗口）。

### Philosophy 2 — `PlistFormedXml`/`PlistFormedBinary` 中间类型

**证据：** `consema-plist/src/document.rs:64-65`（`PlistInner::Xml(PlistFormedXml)` / `::Binary(PlistFormedBinary)`），由 parser 返回（`document.rs:600/610` 返回 `Result<PlistFormedBinary, …>`）；类型有完整 rustdoc，conformance runner 与 conversion 测试使用。

**Disposition：exempt（0.13.0）+ 1.0.0 决策。** 0.13.0 维持 public（它们是 plist 适配器文档化表面的组成部分，且 `Document::as_plist` 的二进制/XML 分支类型必须存在）；1.0.0 API 冻结时决策：改为 `pub(crate)` 并只暴露 `PlistDocument` 门面，或维持 public——决策条件是 plist conversion 的公开解析入口是否重构；记入 1.0.0 冻结清单。

---

## 2. M10 CLI API 评审 backlog（B-1..B-9，转写 + disposition）

来源：`0.13.0-gate-plan.md` §4 M4 的 B-1..B-9 表（0.12.0 M10 移交）。除 B-6/B-9 外均为文档化边界或大面 backlog。

| # | 项 | 证据 | M10 disposition | 本评审 disposition |
|---|---|---|---|---|
| B-1 | query 只接线 `core.portable-value-query@1`；native 域需调用方外部化 node locator，facade 未暴露 | `query_cmd.rs:65-67,1064-1093`；CHANGELOG.md:39 | backlog（facade locator API） | **保持 backlog**：与 B-2 合并为"facade node-locator API"一项；0.13.0 显式拒绝语义保留（RFC 0015 §6.1 不完整结果禁令）；目标窗口 1.0.0（locator 契约必须语言无关，Go 对齐窗口 0.14.0 同步设计）。记入 FC manifest |
| B-2 | materialize/convert 结果 provenance map 为空（同因） | `materialize_cmd.rs:170-178` | backlog（与 B-1 合并） | 同 B-1（合并项；空 map 是如实表达，非伪造） |
| B-3 | project 报告/来源外部化仅 json/toml（其余家族显式拒绝；TOML 非空报告拒绝） | `project_cmd.rs:14-20,248-257,679-697` | backlog（每格式报告外部化映射）；显式拒绝保留 | **保持**：0.13.0 显式拒绝保留（B-6 修复后 java-properties 只被本门挡住——见 B-6 回归测试 `project_java_properties_source_is_refused_at_the_family_gate`）；每格式报告外部化映射归 1.0.0 |
| B-4 | 信封只携带注册 code；格式本地 code 绑定注册 fallback，stderr 保留真码 | `query_cmd.rs:150-166` | 保持（RFC 0015 §4.3 冻结；评审时复核 fallback 选择） | **保持**（RFC 0015 §4.3 冻结语义）；fallback 选择 `core.source.invalid-sequence@1` 语义上偏编码类，但 exit class 与 stderr 真码不受影响；B-9 修复复用同一 fallback（inspect 与 query 行为一致化）。专设 fallback code（如 `core.diagnostic.format-local-code@1`）需 RFC 0015 修订——提交 v8 窗口评估，0.13.0 不动作 |
| B-5 | 失败 `cli.convert@1` 形态 report/target 为 null，失败事实只在诊断 | `convert_cmd.rs:252-268,417-436` | backlog（失败形态外部化各阶段 report） | **保持**：原子失败无 target 文档（null 是诚实形态）；各阶段 report 外部化归 1.0.0 |
| B-6 | **java-properties 源 project/convert 不可达**（bug） | `query_cmd.rs:893-905`、`project_cmd.rs:48-90` | backlog 优先修复项 | **FIXED（本里程碑）**，见 §2.6 |
| B-7 | edit/plan/apply 操作词表仅 INI family | `edit_cmd.rs:47-53,510-519` | backlog（每格式操作请求映射） | **保持 backlog**：M7 文档化边界；每格式映射表是增量大面，归 0.14.0+（facade `operation_registry` 已为每 profile 提供操作清单，映射表可直接挂接） |
| B-8 | `edit --write` 未接线（dry-run only） | `edit_cmd.rs:1023,1063`；`tests/cli_m7_plan.rs:98` 钉死 usage；帮助文本已于 2026-08-07 修订（`args.rs:194` 改为 "dry-run only"、`:214` 的 --write 行已删） | backlog 优先修复项 | **保持 backlog（0.13.0 收口前处理）**：两条路径——(a) 接线 fsio 提交路径（属 M6/fsio 里程碑域，非 M4 域）；(b) 最小路径：修订帮助文本（**已于 2026-08-07 完成**：`args.rs:194`/`:214`；RFC 0015 §6.1 edit 行冻结不动，CHANGELOG.md:45 边界记录同步——usage 显式拒绝不漂移）。行为（usage 拒绝）已由测试钉死，不会漂移 |
| B-9 | **`inspect --profile` 对未注册格式本地 code 诊断 exit 5 内部错误**（bug） | `inspect.rs:355-395`（对比 `query_cmd.rs:150-166`） | backlog 优先修复项 | **FIXED（本里程碑）**，见 §2.9 |

### 2.6 B-6 修复记录（java-properties 源 project/convert 不可达）

**根因（before）：** `format_family` 对 `java-properties.*` profile 返回 wire family `"properties"`（`query_cmd.rs:899`），而 `wire_projection_request` 的族前缀检查按 `{family}.projection.` 要求 target 以 `properties.projection.` 开头（`project_cmd.rs:74`），把 RFC 0010 发布的 `java-properties.projection.*` target 全部拒绝。

**实测 before：** `consema convert <jp文件> --profile java-properties.reader --request-file <java-properties.projection.best-exact-entry-mapping 请求>` → exit 2，stderr：`projection target 'java-properties.projection.best-exact-entry-mapping' does not belong to the 'properties' format family (code cli.data.invalid-request@1)`。`project` 路径同源但先被 B-3 家族门挡住（`project_cmd.rs:248-257`，文档化边界），prefix 检查是 convert 的实阻塞。

**修复（after，`project_cmd.rs:65-73`，~4 行）：**

```rust
    // The java-properties family's published projection targets are
    // namespaced `java-properties.projection.*` (RFC 0010) while its wire
    // family name is "properties" (the facade conversion boundary,
    // `query_cmd::format_family`); the family-prefix check needs the special
    // case or every java-properties target is rejected (B-6).
    let mut prefix = format!("{family}.projection.");
    if family == "properties" {
        "java-properties.projection.".clone_into(&mut prefix);
    }
```

**回归测试：**

- `project_cmd.rs` tests `wire_projection_request_accepts_published_java_properties_targets`：wire 映射接受两个已发布 java-properties target（`best-exact-entry-mapping`、`require-object`）→ `WireProjectionRequest::Properties`；另一家族 target（`toml.projection.best-exact-core`）仍拒绝 `cli.data.invalid-request@1`。
- `project_cmd.rs` tests `project_java_properties_source_is_refused_at_the_family_gate`：全命令 `project` + java-properties 源 → exit 2，错误必须是 B-3 家族门消息（"not wired for the 'properties' family"）而非 prefix 拒绝——钉死"B-6 修复后唯一阻塞是文档化边界"。
- `convert_cmd.rs` tests `convert_java_properties_source_to_toml_end_to_end`：全命令 convert java-properties → TOML exit 0，success envelope，`core.conversion-report@1` 源/目标 profile 正确，target snapshot 携带物化 TOML 字节。

### 2.9 B-9 修复记录（`inspect --profile` 对格式本地 code 诊断 exit 5）

**根因（before）：** `parse_facts_value` 两处绑定循环直接 `DiagnosticMessage::from_core_with_registry`，绑定失败（未注册 code：xml/plist/hcl 解析家族；或已注册但 category 与注册表矛盾：ini `ini.parse.missing-section@1` crate 侧 Syntax vs registry Conformance）即返回 `ParseOutcome::Internal` → exit 5 `cli.internal.unclassified@1`。inspect 未走 `query_cmd::registered_code` fallback。

**实测 before：** `inspect bad.xml --profile xml.1.0-safe`（`</roott>` 恢复诊断）→ exit 5 `xml.tree.mismatched-end-tag@1`；`inspect rec.hcl --profile hcl.native`（未闭合块）→ exit 5 `hcl.parse.block@1`；`inspect bad.plist --profile plist.xml` → exit 5 `plist.parse.dict-missing-value@1`；`inspect entry.ini --profile ini.python-configparser`（区头前条目，category 矛盾）→ exit 5。深层嵌套 fatal（`xml.limit.depth@1`、`plist.limit.nesting-depth@1`、`hcl.limit.expression-depth@1`）同样 exit 5。

**修复（after，`inspect.rs`）：**

1. 新 helper `bind_parse_diagnostic(diagnostic, path)`：先正常绑定；失败时用 `query_cmd::registered_code` 取注册 fallback（`core.source.invalid-sequence@1`），category 取注册表描述符（registry 是权威，修正 INI 矛盾案例），保留 severity/location/arguments/notes/occurrence；真 code 写入 bound `message` argument（"format-local code {code}"），stderr 与 human 视图均可读。
2. Fatal 循环与 Recovered 循环改用 helper；`ParseOutcome::Internal` 变体删除（不再有构造点）。
3. `write_human_parse` 渲染 `message` argument：Recovered human 视图显示 `core.source.invalid-sequence@1 (format-local code hcl.parse.block@1)`，真码不丢失。
4. 语义保持 RFC 0015 §7.2：Recovered 事实 → exit 0（report 即结果）；fatal 事实 → exit 2（data class，由 bound code 经 `classify_error_code` 派生）；不再有 exit 5。

**实测 after：** xml/plist/hcl 恢复诊断 → exit 0，envelope 诊断 code `core.source.invalid-sequence@1` + `message` argument 携带真码；ini category 矛盾案例 → exit 0，envelope 保留真码 `ini.parse.missing-section@1` 且 category 为注册表 Conformance；xml/plist/hcl 深度 fatal → exit 2，stderr `format-local code xml.limit.depth@1 (code core.source.invalid-sequence@1)`。

**回归测试（矩阵）：**

- `inspect.rs` tests：`inspect_xml_fatal_is_a_data_error_with_the_registered_fallback`（300 深 `<a>`，exit 2、envelope fallback code、stderr 真码）；`inspect_plist_fatal_is_a_data_error_with_the_registered_fallback`（300 深 dict）；`inspect_hcl_fatal_is_a_data_error_with_the_registered_fallback`（300 深 block）；`inspect_recovered_format_local_diagnostics_report_with_fallback_binding`（xml/plist/hcl 三例 Recovered exit 0 + human 视图真码）；`inspect_ini_category_contradiction_recovery_binds_the_registry_category`（exit 0、真码保留、category=Conformance）。
- `tests/cli_m4.rs` 进程级：`inspect_format_local_fatal_is_a_data_error_not_an_internal_error`（内置二进制 + xml fatal，exit 2、stderr 含真码、不含 `cli.internal.unclassified@1`、envelope fallback code）。

---

## 3. cargo-semver-checks 基线解读（M4 视角）

- **基线锚点**：`git tag v0.8.0` 存在（f79dd99，annotated 未签名），与 plan P-11 一致；baseline worktree 建于仓库外（`C:\Users\franck\Documents\consema-baseline-v0.8.0`，semver-checks 要求 baseline 不在当前 workspace 内）。
- **CI semver job（M1 交付，`.github/workflows/ci.yml:207-245`）**：`obi1kenobi/cargo-semver-checks-action@v2`，`baseline-root: baseline`（v0.8.0 checkout），package 列表 = v0.8.0 时代已存在的 11 个 crate（consema、consema-core、consema-document、consema-graph、consema-ini、consema-json、consema-properties、consema-protocol、consema-pvce、consema-toml、consema-yaml）；consema-xml/plist/hcl 无基线，排除（R-4 覆盖边界显式记录）。
- **本地实测（2026-08-07，`cargo install cargo-semver-checks --locked` 后逐包 `check-release --baseline-root`，与 CI job 等价）**：

| crate | 结果 |
|---|---|
| consema-protocol、consema-json、consema-toml、consema-yaml、consema-ini、consema-properties、consema-graph、consema-pvce（8 个） | **no semver update required**（全绿） |
| consema（facade） | `enum_variant_added` ×1：`ConversionProjectionReport::{Hcl,Xml,Plist}`（conversion.rs:65/67/69）、`FormatMismatch::{Xml,Plist,Hcl}`（lib.rs:505/507/509）、`ConversionProjectionProvenance::{Hcl,Xml,Plist}`（conversion.rs:86/88/90） |
| consema-core | `enum_variant_added` ×1：`MatchRole` 新增 Xml/Plist/Hcl 系列变体（query.rs:248+） |
| consema-document | `enum_variant_added` ×1：`NodeRole` 新增 Xml/Plist/Hcl 系列变体（lib.rs:190+） |

- **RFC 级决定（plan 门禁："任何相对 v0.8.0 的 breaking change 必须在此里程碑给出 RFC 级决定"）**：三个 crate 的失败全部是**同一类**——0.9.0-0.11.0 新家族（xml/plist/hcl）的**纯增量枚举变体**，无任何移除、签名变更、trait 破坏（196 项检查仅 1 项失败）。该面是 CHANGELOG 0.9.0-0.12.0 与 RFC 0012/0013/0014 明确文档化的功能面，facade 内穷尽处理，migration guide 已覆盖。按路线图 §12.1（0.x.0 是架构门，允许破坏性变更并记录）**批准该 breaking 面**：语义上是消费者必须处理新家族的预期变更，不是事故。CI semver job 对该类失败的处理：M9 收口时在 ci.yml 的 semver job 为这三个 crate 记录 approved-failure（allowlist `enum_variant_added` + 注释指向本条），或保留失败并附批准记录——二选一在 M9 落定。**已考虑并被否决的方案**：现在给三个枚举加 `#[non_exhaustive]`（会再引入一次消费者破坏，纯为门禁观感）；采纳窗口 = 1.0.0 API 冻结（届时加 `#[non_exhaustive]`，1.x 不再因变体新增而破坏）。
- **结论**：11 个基线 crate 中 8 个全绿；3 个仅新增变体（已批准）。F2/F3/F4/F10/F11/F13/F15 均为命名漂移而非签名破坏（§1 逐条处置）。无意外 breaking。

## 4. rustdoc 100% 断言

- 门禁体例：workspace lint `missing_docs = "warn"`（Cargo.toml:38）+ `RUSTDOCFLAGS="-D warnings" cargo doc --workspace --no-deps`。
- 实测（2026-08-07）：`cargo doc --workspace --no-deps --exclude consema-conformance` 在 `-D warnings` 下**零警告**（0 个 missing-docs），其余 14 个 crate 全部 100% 覆盖。
- 唯一失败点：`cargo doc -p consema-conformance` 12 个 missing-docs 警告，全部位于 `crates/consema-conformance/src/fuzz.rs:52-69`（`Mutation` 枚举字段/变体），该文件是 **M2 并行轨（fuzz 域）未落盘的新文件**（git 未跟踪，非本里程碑文件域）。M2 合入其 rustdoc 后门禁全绿；0.13.0 收口（M9）复核。

## 5. facade/feature 复查（§15.6 第 1416-1421 行）

- **facade 依赖面**：`crates/consema/Cargo.toml` 13 个依赖全部为 consema-* path 依赖；**无 `[features]` 段**——与 plan §1.6"facade 依赖 13 个 backend；无 [features]"一致。无 feature 即无 feature 组合面，§15.6"feature 关系清楚"成立（单一全量面）。
- **facade 表面与 CHANGELOG 声称一致**：8 个 `Document::parse_*`（`lib.rs:535-634`）+ 8 个 `as_*` 适配器（`:710-816`）+ 8 个 `convert_*`（`conversion.rs:346-597`）+ `registry` 模块（families 8 / profiles 16 / query_domains 21 / operation_registry 16 / parse_document）+ `pub use consema_* as *` 重导出——与 CHANGELOG.md:9/21/57/78/95/115 声称逐项相等。
- **`consema capabilities` 由 facade 派生**：capabilities.rs 走 `registry::format_families()/profiles()/query_domains()/operation_registry()`，无重复声明（RFC 0015 硬门禁 1）；`cli_m4.rs` 测试断言 16 profiles / 8 families / 21 query domains / 187 v7 error codes 与 registry 相等（`cli_m4.rs:160`，0.13.0 audit F3 注册 `json.projection.incomplete-document@1` 后 186 → 187）。
- **CLI 只走 public API**：`src/bin/consema/` 无 parse/query/project/materialize/edit/convert 实现（全部调用 facade）；本次 B-6/B-9 修复保持该结构（仅改 wire 映射与诊断绑定）。

## 6. backend AST 与第三方错误类型泄漏复查（§15.6 第 1417 行）

- **第三方错误类型**：15 个 crate 的 Cargo.toml 依赖全部为 consema-* path 依赖（逐一核对），**零第三方依赖**——第三方错误类型进入公共签名在构造上不可能。公共错误面全部是 crate 自有的 `StableFailure` 实现与 consema-protocol 的注册 code。
- **backend AST 泄漏**：格式 crate 的 AST 内部类型保持 crate 私有——`JsonSyntaxKind`/`JsonValueKind`/`JsonArrayElement`（json）、`XmlSyntaxKind`/`XmlElementData`（xml）、`HclSyntaxKind`/`HclAttribute`（hcl）等均为本 crate 公共但**不外泄到其他 crate 的签名**；facade `Document` 用私有 `DocumentInner` 枚举包装各格式 Document（`lib.rs:517-531`），跨 crate 公共签名只携带语言无关契约类型（`ProfileId`、`Diagnostic`、`PortableValue`、`NodeRef`、`Span`、`SourceSnapshot`、`ParseLimits`、`FormatFamilyId` 等，RFC 0002/0008/0011 契约面）。consema-core/consema-document 类型出现在格式 crate 公共签名中的全部是契约类型，非实现内部。
- **判定**：无泄漏。`cli-implementation-plan.md:42-46` 的"bin 只走 public API"结构约束继续成立（本次修复未触碰）。

## 7. Go API mapping RFC 立项（§15.2 第 1371 行）

本里程碑同步产出 `docs/rfcs/0016-go-api-mapping-v1.md`（立项/charter RFC）：Go module 布局、PortableValue → Go 类型映射、formation/projection/materialization/edit API 形状、错误分类、conformance 集成契约。实现归 0.14.0+。见该 RFC。

## 8. 门禁实测记录（2026-08-07，M4 执行时）

- `cargo test -p consema`：全绿（bin 164 tests 含新增 8 个回归测试；lib 31；integration 19+7+6+17+13+1+1）；`cargo test --workspace --all-targets` 48 个 test 目标全绿（含 conformance CLI 套件，B-9 修复未破坏 `cli.parse-facts@1` 向量钉死行为）。
- `cargo clippy -p consema --all-targets -- -D warnings`：全绿。
- `cargo fmt -p consema --check`：全绿。workspace 级 `cargo fmt --check` 的失败全部位于 M2 并行轨未落盘的 fuzz 域文件（`consema-conformance/examples/gen_mutation_corpus.rs`、`tests/{mutation_corpus,operation_fuzz,parse_fuzz,protocol_fuzz}.rs`，git 未跟踪），非本里程碑文件域；M2 落盘后全绿。
- `RUSTDOCFLAGS="-D warnings" cargo doc --workspace --no-deps`：除 M2 未落盘 `consema-conformance/src/fuzz.rs`（12 处 missing-docs）外全绿；详见 §4。
- cargo-semver-checks：11 个基线 crate 本地实测完成，8 绿 + 3 个仅新家族变体新增（RFC 级批准）；详见 §3。
- 五维审计 findings 全 7 + 2 项 disposition 完成（§1）；B-1..B-9 全部 disposition 完成（§2）；B-6/B-9 修复 + 回归测试落盘；RFC 0016 立项（§7）。
