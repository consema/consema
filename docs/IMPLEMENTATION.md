# Rust `0.5.0` 实现契约

本文记录 Consema 0.5.0 的 crate 边界、版本化 registry、可验证入口和明确非目标。语义权威顺序为：

1. 根目录《配置内容统一处理标准与 Rust 参考实现》中的永久不变量；
2. 已接受 RFC；
3. 语言无关 conformance vectors；
4. 本实现文档和 Rust API；
5. 第三方 parser 行为仅是实现细节，不构成公共契约。

## 1. 数据流与 crate 边界

```text
raw source bytes
  -> explicit encoding resolution -> immutable SourceSnapshot
       |- SHA-256 content digest over exact raw bytes
       |- optional decoded text + exact raw/UTF-8/scalar/UTF-16 boundaries
       `- verifiable atomic SourcePatch
  -> format profile parse
  -> immutable JSON or TOML Document snapshot
       |- exact render + exhaustive structural coverage
       |- format-native values/items and association identities
       |- validated ExecutableQuery -> ordered native or lossless syntax matches
       |- explicit ProjectionRequest -> complete value/report/provenance OR failure
       |- MaterializationRequest + PortableValue -> new Document/report/provenance OR failure
       `- EditTransaction -> EditPlan -> new Document/ChangeSet/proof/SourcePatch OR atomic failure

source Document -> Projection -> PortableValue -> Materialization
  -> target Document + two-stage ConversionReport

PortableValue <-> PVCE/1

typed protocol object
  -> fixed-field PortableValue payload
      |- canonical core.portable-value-json@1
      `- canonical PVCE/1
```

直接本地依赖保持单向：

| crate | 直接本地依赖 |
|---|---|
| `consema-core` | 无 |
| `consema-document` | core |
| `consema-pvce` | core |
| `consema-json` | core、document |
| `consema-toml` | core、document |
| `consema-protocol` | core、document、json、pvce |
| `consema-conformance` | facade、core、document、json、pvce、protocol、toml |
| `consema` | core、document、json、pvce、protocol、toml |

格式 crate 之间不互相依赖。`consema-core` 不依赖格式；`consema-document` 不理解 JSON/TOML 语义；跨格式操作必须通过公共 projection/materialization contract 组合。

## 2. 公共 document 事实

每次成功 parse 或 edit commit 都产生新的 `SnapshotIdentity`。`NodeRef` 和 `Span` 只能由所属 `DocumentAuthority` 验证；相同 source 的两次 parse 也不是同一 snapshot。

`LosslessStructuralIndex` 要求 source 从 byte 0 到末尾被有序的 Token/Trivia/ErrorRegion 无空洞、无重叠覆盖。默认 `Document::render()` 返回当前 snapshot 的精确 source bytes。

公共 `SourceSnapshot` 保留完整原始字节，以原始字节的 SHA-256 作为跨进程 content identity，并独立于每次文档形成产生的 process-local `SnapshotIdentity`。encoding 闭集为 Binary、UTF-8、UTF-16LE、UTF-16BE 与 ISO-8859-1；BOM、声明、caller override 和 profile default 的解析事实完整保留，冲突不猜测。

所有 `Span` 继续表示原始字节半开区间。text source 只允许在 Unicode scalar boundary 上进行 raw/decoded UTF-8/scalar/UTF-16 坐标互换，不取整；Binary 没有 decoded coordinate。现有 JSON/TOML Profile parser 入口仍接受 UTF-8，公共多编码 source 能力不自动扩大任何格式 Profile 的准入范围。

## 3. JSON profiles

- `json.strict@1`：strict JSON 与明确 duplicate/BOM diagnostics；
- `jsonc.bounded@1`：在 strict 基础上允许 bounded comments、trailing comma 和受控 BOM。

JSON native model 保留 object member 和 array element 的 association identity，object 重复 member 不会在 parse 阶段折叠。Recovered document 使用显式 recovery structure；局部 native semantics 可以 unavailable。

## 4. TOML profile 与原生模型

`toml.1.0@1` 只形成完整合法 TOML 1.0 文档。语法错误是 `FatalFormationFailure`；0.5.0 不声明 TOML recovery capability。

TOML 公共实体角色：

| 角色 | 事实 |
|---|---|
| `TomlItem` | scalar、array、inline table、table 或 array-of-tables |
| `TomlEntry` | table/inline-table 中有序的直接 key-to-item association |
| `TomlKey` | 已解码直接 key segment 及其 source span |
| `TomlArrayElement` | array/AOT 中有序的元素 association |

原生 item 闭集包含 String、Integer、Float、Boolean、四类 temporal、Array、InlineTable、RootTable、StandardTable、ImplicitTable、DottedTable 和 ArrayOfTables。

`a.b.c = 1` 在逻辑树中形成逐层 entry，同时每个 key segment 保留独立 span。TOML table 不等于 JSON object；二者只在显式投影到 PortableValue Object 时相遇。

Rust parser backend 精确固定为 `toml_edit 0.22.27`。不可变 raw document 和 backend spans 用于建模，但公开 API、diagnostic code、query operator 和 projection 结果均不暴露 backend 类型。

## 5. Query registries

所有 operator version 均为 1。domain、参数集合、参数类型和角色组合在产生首个 match 前完成验证。

### `core.portable-value-query@1`

支持 Object、EntryMapping、Sequence 导航，`where/require type`，以及通用 `core.take`、`core.distinct-by-identity`。

### `json.native-semantic-query@1`

| Operator | 输入 | 输出 |
|---|---|---|
| `json.try-object-members` | JsonValue | JsonObjectMember |
| `json.member-name-equals` | JsonObjectMember | JsonObjectMember |
| `json.member-value` | JsonObjectMember | JsonValue |
| `json.try-array-elements` | JsonValue | JsonArrayElement |
| `json.array-element-value` | JsonArrayElement | JsonValue |

### `toml.native-semantic-query@1`

| Operator | 输入 | 输出 |
|---|---|---|
| `toml.try-table-entries` | TomlItem | TomlEntry |
| `toml.entry-name-equals` | TomlEntry | TomlEntry |
| `toml.entry-item` | TomlEntry | TomlItem |
| `toml.try-array-elements` | TomlItem | TomlArrayElement |
| `toml.array-element-item` | TomlArrayElement | TomlItem |

三个 domain 都使用相同的 selection、Concat、StructureOrderMerge、limit、cancellation 和 ordered cursor 语义。

### Lossless Syntax Query v1

- `json.lossless-syntax-query@1`：`json.syntax-kind-is@1`、`json.syntax-text-equals@1`，返回 `JsonSyntaxPiece`；
- `toml.lossless-syntax-query@1`：`toml.syntax-kind-is@1`、`toml.syntax-text-equals@1`，返回 `TomlSyntaxPiece`。

两个 domain 都以完整 lossless structural pieces 作为 source-order 输入。kind 在产生第一个 match 前验证；kind enum 与 match 类型保持格式专属。ordered cursor 的最终状态只有 Completed、Cancelled、Failed，并且只在全部已发现项被消费或取消/失败被观察后可见。

`core.query-definition@1` 通过固定字段 PortableValue schema 编码，再通过 PVCE/1 传输。未知、缺失或重排字段均拒绝。

## 6. Projection

Projection 是显式 operation，不是 parse 的隐式副作用。成功结果必须同时包含完整 PortableValue、fidelity、report 和 provenance；失败结果不得包含 partial value。

TOML `toml.best-exact-core@1` 映射：

| TOML | PortableValue |
|---|---|
| Boolean | Boolean |
| Integer | Integer |
| Float | BinaryFloat64 |
| String | String |
| LocalDate | Date |
| LocalTime | Time |
| LocalDateTime | LocalDateTime |
| OffsetDateTime | OffsetDateTime |
| Array | Sequence |
| 所有 table 类别 | Object |
| ArrayOfTables | Sequence<Object> |

合法 TOML 逻辑 table 不允许重复 key，因此可精确进入 unique-key Object。每个 projected value、ObjectEntry 和 ObjectKey association 都映射到 snapshot-bound source origin。超出 PortableValue v1 的时间字段会整体失败，不截断为成功。

JSON projection 继续通过显式 target 和 duplicate policy 在 Object/EntryMapping 之间选择，并报告任何 authorized loss。

## 7. Materialization 与 audited conversion

Materialization 从完整 `PortableValue` 和显式 `MaterializationRequest` 创建一个新文档；它不是既有文档的 formatter。请求冻结 target Profile、style、encoding、newline、EntryMapping policy、ExactOnly representability 以及 input/output/depth/report/provenance 上限。

- JSON/JSONC：`json.canonical-compact@1`、`json.canonical-pretty@1`，接受 JSON 可表示的 core kind；String-key `EntryMapping` 可保序保重复，非 String key 与 BinaryFloat/temporal/bytes 明确失败；
- TOML：`toml.canonical-document@1`，完整支持 TOML scalar、四类 temporal、array 与 nested object；根必须是 Object，或由调用方显式授权 unique String-key EntryMapping 转换为 Object；
- 完成结果包含新 Document、fidelity、完整 report 与 input-value/association 到 target node/span 的 provenance；失败只包含 failure/report/analyzed paths，不包含文档或 partial bytes。

facade 的 `convert_json`/`convert_toml` 只组合已发布的 Projection 与 Materialization。中间 `PortableValue`、两阶段 provenance、两阶段 fidelity/report 和 source/target Profile 都保留；overall fidelity 是两阶段最差值。未经 policy 授权的 projection loss、重复 key 转换、不可表示 target value 或 materialization failure 都不会产生 target Document。

## 8. 原子 scalar 与 structural edit

事务绑定一个 base snapshot；全部 target、candidate representation、resource limits 和 overlap 必须先验证，再一次性替换并重 parse。

TOML exact literal 必须恰好是一个 scalar span：前后 trivia、comment、container 或额外 assignment 均拒绝。semantic edit 只接受 TOML 可无损表示的 core scalar，并显式选择：

- `ExactLiteral`；
- `PreserveCompatible`；
- `CanonicalForProfile`；
- `PreserveElseCanonical`。

任意精度 Integer 超出 i64、携带 payload 的非 canonical NaN、亚纳秒 Time、非整分钟 OffsetDateTime 等均明确失败。成功 commit 产生新 Document 和包含 source edits、node mappings、diagnostics 的 ChangeSet；旧 snapshot 永不改变。

0.5.0 的 format operation registry 对 JSON 与 TOML 各发布 7 个版本化操作：semantic/literal scalar replacement，以及格式专属的 association insert/remove/rename 与 array element insert/remove。相同操作名不表示两个格式共享 trivia、comma、table ownership 或 duplicate 语义。

结构 target 和 placement anchor 都使用 snapshot-bound `NodeRef`。JSON member 的重复身份不会按 key 合并；JSONC 只修改 operation 所拥有的 delimiter/association 区域。TOML entry 保留 root/standard/inline table ownership，rename 不能制造重复 direct key；0.5.0 不移动 table、不合成 dotted-key ownership，也不做通用 reorder。

多操作冲突在发布新文档前统一判定，包括 wrong snapshot/role、missing or duplicate target、overlapping ownership、ancestor-descendant conflict、removed placement anchor、duplicate key、unrepresentable value、resource limit 与 reparse failure。成功同时产生新 Document、ChangeSet、UntouchedByteProof 和 SourcePatch；失败不产生其中任何一项。

`dry_run` 执行与 commit 相同的确定性验证和字节规划，输出 source ID、base digest、Profile、无内容操作摘要、精确 replacements、target digest 与 report。plan 不是文件写入授权；敏感 replacement 可在 review/debug 表示中 redacted，实际应用仍要求完整原始字节前置条件。

`SourcePatch` 是与格式无关的 raw-byte transition fact：它绑定 base/target digest、encoding facts、有序不重叠区间、原始字节前置条件和确定性 metadata。应用前完整验证 stale base、original bytes、encoding 与 target digest；任何失败都不返回新 snapshot。它不是 ChangeSet、语义 diff、merge、fuzzy patch 或文件系统写入授权。

## 9. Resource 与安全语义

- `ParseLimits`：source bytes、nesting、token/piece、node、diagnostic；
- `DecodeLimits`：PVCE bytes、depth、nodes、container、integer、blob；
- `ProtocolLimits`：canonical JSON/PVCE transport bytes、depth、nodes、container、integer、blob；
- `QueryLimits`：steps、results；
- `ProjectionLimits`：value nodes、report、provenance、depth。
- `SourceLimits`：raw bytes、decoded UTF-8 bytes、decoded scalar/boundary count；
- `SourcePatchLimits`：resulting source limits、replacement count 与 patch bytes。
- `MaterializationLimits`：input nodes/depth、output bytes、report 与 provenance；

超限返回 fatal/failed 状态，不能把截断包装成成功。所有 workspace crates `unsafe_code = forbid`。

## 10. Conformance 证据

| Gate | 结果 |
|---|---|
| `consema.conformance@1` | 20/20 |
| `consema.toml.conformance@1` | 18/18 |
| `consema.protocol.conformance@1` | 32/32 |
| `consema.source.conformance@1` | 28/28 |
| `consema.syntax-query.conformance@1` | 19/19 |
| `consema.protocol.conformance@2` | 11/11 |
| `consema.operations.conformance@1` | 35/35 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 valid | 205/205 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 invalid | 474/474 |

语言无关向量共 163 个。operations v1 覆盖 JSON/TOML materialization、两向 conversion、14 条 operation registry 记录、结构事务冲突矩阵、dry-run/patch/proof、semantic-model v3 双传输与资源失败。TOML corpus 包含全类型、复杂 string/trivia、真实 service config、本仓库实际 Cargo manifest、PEP 621 pyproject 和非法重复 key。官方 adapter 只使用 Consema 公共 TOML API 输出 tagged JSON。

## 11. PVCE/1 固定项

- magic：ASCII `PVCE`；
- version：minimal unsigned LEB128 `1`；
- sign octet：`0 = zero`、`1 = positive`、`2 = negative`；
- tag、长度和计数：minimal unsigned LEB128；
- fixed float bits：network byte order。

任何不兼容编码修改必须使用新的 encoding version。

## 12. Cross-format Protocol 与 semantic-model registries

RFC 0002 冻结 `core.semantic-model@1` 兼容性身份、`core.protocol-message@1` transport envelope、15 个稳定 payload 契约和 55 个公共 error code。每个 envelope payload 必须同时通过 contract registry、首字段 schema 和对应 typed decoder 的完整校验；只伪造正确 schema 不能形成消息。

协议对象只以固定字段 `PortableValue` 表达，同一 payload 通过 canonical tagged JSON 或 PVCE/1 传输。32 个语言无关 case 证明所有 15 个稳定 payload 都在两种 transport 上严格相等，并覆盖未知 contract/field、非规范表示、注册表矛盾、资源越界与 process-local identity 拒绝。

`NodeRef`、snapshot identity、cursor 与 `CancellationToken` 仍是 process-local。跨进程 Diagnostic、native Query match、Provenance、ChangeSet、MaterializationResult 与 EditPlan 必须由调用方提供稳定 `source_id`/`node_locator`；适配器缺少绑定时返回 `core.protocol.process-local-handle@1`，不静默删除身份事实。

ProjectionResult 的 present value 使用 `{ portable_value }` wrapper，因此成功的 PortableValue `Null` 与失败/缺席值不混淆。Completion failure、Diagnostic 和 ProjectionReport event code 都由同一个 ErrorCodeRegistry 校验；Diagnostic category 必须与注册表一致。

### Semantic model v2

RFC 0003 保持 `ContractRegistry::v1()` 的 16 条记录（15 stable + transport）和 `ErrorCodeRegistry::v1()` 的 55 个 code 精确不变。`core.semantic-model@2` 使用 18 条 contract record（增加 `core.source-snapshot@1`、`core.source-patch@1`）与 62 个 error code。`RegistryManifest::v1()`/`v2()` 显式构造冻结集合；旧 conformance 永远显式绑定其原 registry。

两个新 payload 的 decoder 都重新验证内容事实：SourceSnapshot 重算 digest、encoding resolution、decode status；SourcePatch 重新验证 schema、digest 表示、encoding facts、replacement order 与 limits。通过 wire 不会降低后续 patch application 的 stale/original/target 检查。

### Semantic model v3

RFC 0004 的 `ContractRegistry::v3()` 含 25 条记录，`ErrorCodeRegistry::v3()` 含 90 个 code，`RegistryManifest::current()` 在 0.5.0 指向 v3。v3 在 v2 基础上增加 7 个 stable payload：

- `core.conversion-report@1`；
- `core.edit-plan@1`；
- `core.format-operation-registry@1`；
- `core.materialization-provenance-map@1`；
- `core.materialization-report@1`；
- `core.materialization-request@1`；
- `core.materialization-result@1`。

每个 payload 在 canonical JSON 与 PVCE/1 两条 transport 上使用同一固定字段 `PortableValue` schema 并重新验证交叉约束。`MaterializationResult` 显式区分 Complete/Failed；Complete 携带 verified target SourceSnapshot、Profile、report/provenance，Failed 不携带 target source 或 bytes。v1/v2 的 contract、error code、manifest 与 frozen constructor 不因 v3 改写。

## 13. 0.5.0 明确边界

本版本没有 JSON5、YAML、INI、Properties、XML、plist、HCL、Schema、semantic diff/merge、Formatter、Live Query、增量解析、PortableGraph、通用 reorder/table move、文件系统原子替换、稳定进程插件协议或 Go 实现。`SourcePatch` 仍只声明精确 raw-byte transition；`EditPlan` 仍只声明已验证计划，二者都不授予文件系统写入权限。

这些不是“隐藏支持”或文档遗漏；它们是路线图后续版本的显式工作。0.5.0 只声明已由代码、语言无关向量、adversarial tests 和上游 suite 共同证明的 capability。
