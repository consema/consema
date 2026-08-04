# Rust `0.7.0` 实现契约

本文记录 Consema 0.7.0 的 crate 边界、版本化 registry、可验证入口和明确非目标。语义权威顺序为：

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
  -> immutable JSON, TOML or YAML Document snapshot
       |- exact render + exhaustive structural coverage
       |- format-native values/items and association identities
       |- validated ExecutableQuery -> ordered native or lossless syntax matches
       |- explicit ProjectionRequest -> complete value/report/provenance OR failure
       |- MaterializationRequest + PortableValue -> new Document/report/provenance OR failure
       `- EditTransaction -> EditPlan -> new Document/ChangeSet/proof/SourcePatch OR atomic failure

source Document -> explicit Projection -> PortableValue or PortableGraph
  -> explicit Materialization -> target Document

source Document -> PortableValue Projection -> target Materialization
  -> target Document + two-stage ConversionReport

PortableValue <-> PVCE/1
PortableGraph <-> PGCE/1

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
| `consema-graph` | core |
| `consema-json` | core、document |
| `consema-toml` | core、document |
| `consema-yaml` | core、document、graph |
| `consema-protocol` | core、document、graph、json、pvce |
| `consema-conformance` | facade、core、document、graph、json、pvce、protocol、toml、yaml |
| `consema` | core、document、graph、json、pvce、protocol、toml、yaml |

格式 crate 之间不互相依赖。`consema-core` 不依赖格式；`consema-document` 不理解 JSON/TOML/YAML 语义；跨格式操作必须通过公共 projection/materialization contract 组合。`consema-graph` 是格式无关图模型，不依赖 YAML；YAML 只是首个验证它的格式。

## 2. 公共 document 事实

每次成功 parse 或 edit commit 都产生新的 `SnapshotIdentity`。`NodeRef` 和 `Span` 只能由所属 `DocumentAuthority` 验证；相同 source 的两次 parse 也不是同一 snapshot。

`LosslessStructuralIndex` 要求 source 从 byte 0 到末尾被有序的 Token/Trivia/ErrorRegion 无空洞、无重叠覆盖。默认 `Document::render()` 返回当前 snapshot 的精确 source bytes。

公共 `SourceSnapshot` 保留完整原始字节，以原始字节的 SHA-256 作为跨进程 content identity，并独立于每次文档形成产生的 process-local `SnapshotIdentity`。encoding 闭集为 Binary、UTF-8、UTF-16LE、UTF-16BE 与 ISO-8859-1；BOM、声明、caller override 和 profile default 的解析事实完整保留，冲突不猜测。

所有 `Span` 继续表示原始字节半开区间。text source 只允许在 Unicode scalar boundary 上进行 raw/decoded UTF-8/scalar/UTF-16 坐标互换，不取整；Binary 没有 decoded coordinate。JSON/TOML Profile parser 入口仍接受 UTF-8；YAML 两个 Profile 显式接受 BOM 检测的 UTF-8、UTF-16LE 与 UTF-16BE。

## 3. JSON profiles

- `json.strict@1`：strict JSON 与明确 duplicate/BOM diagnostics；
- `jsonc.bounded@1`：在 strict 基础上允许 bounded comments、trailing comma 和受控 BOM；
- `json5.standard@1`：Standard JSON5 1.0.0，包括 IdentifierName key、两种引号、扩展 escape/whitespace/comment、十六进制与扩展十进制、trailing comma、Infinity/NaN。

JSON native model 保留 object member 和 array element 的 association identity，object 重复 member 不会在 parse 阶段折叠。JSON5 的有限整数/十进制仍是任意精度 `BigInteger`/`Decimal`；只有 `±Infinity` 与 `±NaN` 形成四种冻结位模式的 `BinaryFloat64`。Recovered document 使用显式 recovery structure；局部 native semantics 可以 unavailable。JSON5 Unicode IdentifierStart/Continue 使用精确锁定的 `unicode-id-start 1.4.0` 表，不依赖宿主 Unicode 版本漂移。

## 4. TOML profile 与原生模型

`toml.1.0@1` 只形成完整合法 TOML 1.0 文档。语法错误是 `FatalFormationFailure`；0.7.0 继续不声明 TOML recovery capability。

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

## 4.1 PortableGraph@1 与 PGCE/1

PortableGraph 是与 PortableValue 平行的 immutable portable representation，不是给 PortableValue 增加引用类型。它保留有序 roots、graph-local node identity、Scalar/Sequence/Mapping、tag、任意与重复 mapping key、sharing 和 cycle。strict equality/hash 比较可达拓扑与顺序，不比较 builder 分配编号；不可达节点、未定义节点和跨图引用在 build 完成前失败。

PGCE/1 使用 `PGCE` magic、version 1、minimal unsigned LEB128 与 canonical node numbering。严格 decoder 拒绝非最小 varint、trailing bytes、无效引用、非 canonical numbering、未知版本与全部资源越界；失败不返回 partial graph。`core.portable-graph-query@1` 对 root、reachable node、sequence element 与 mapping entry 提供确定性遍历，sharing 只访问一次，cycle 不展开。

## 4.2 YAML family 与原生图语义

- `yaml.1.2-core@1`：YAML 1.2.2 presentation grammar 与 Core scalar schema；
- `yaml.1.1-compat@1`：保持相同安全 presentation 边界，并冻结 YAML 1.1 boolean/octal/sexagesimal/timestamp resolution；
- Profile 只接受自身版本 directive；未来版本、重复 directive 与跨 Profile directive 显式失败；
- stream、document、node、mapping entry、sequence element、anchor definition 与 alias occurrence 都有 YAML 专属 snapshot-bound 身份；
- mapping 保留任意 key、重复 key 与顺序；tag、anchor、alias、sharing 和 cycle 不被压平；
- lossless syntax 保留 directive、document marker、block/flow indicator、五种 scalar style、block content、comment、whitespace 与原始 newline；
- custom tag 是数据，不执行 constructor、import、网络或文件访问；alias 默认不展开，anchor 作用域严格限制在单个 document。

Rust backend 固定为 `saphyr-parser 0.0.11`，只负责 bounded event parsing。Profile resolution、source identity、lossless scanner、native composition、diagnostic code、query、projection、materialization 与 edit 均由 Consema 层拥有，任何 backend 类型都不进入公共 API。

## 5. Query registries

所有 operator version 均为 1。domain、参数集合、参数类型和角色组合在产生首个 match 前完成验证。

### `core.portable-value-query@1`

支持 Object、EntryMapping、Sequence 导航，`where/require type`，以及通用 `core.take`、`core.distinct-by-identity`。

### `json.native-semantic-query@1/@2`

| Operator | 输入 | 输出 |
|---|---|---|
| `json.try-object-members` | JsonValue | JsonObjectMember |
| `json.member-name-equals` | JsonObjectMember | JsonObjectMember |
| `json.member-value` | JsonObjectMember | JsonValue |
| `json.try-array-elements` | JsonValue | JsonArrayElement |
| `json.array-element-value` | JsonArrayElement | JsonValue |

v1 对 strict JSON/JSONC 保持冻结。JSON5 必须使用 v2；v2 在既有角色和 operator 语义上增加 `BinaryFloat64` native kind，不修改 v1 输出集合。

### `toml.native-semantic-query@1`

| Operator | 输入 | 输出 |
|---|---|---|
| `toml.try-table-entries` | TomlItem | TomlEntry |
| `toml.entry-name-equals` | TomlEntry | TomlEntry |
| `toml.entry-item` | TomlEntry | TomlItem |
| `toml.try-array-elements` | TomlItem | TomlArrayElement |
| `toml.array-element-item` | TomlArrayElement | TomlItem |

### `core.portable-graph-query@1`

支持 roots、reachable nodes、sequence elements、mapping entries、entry key/value、node kind/tag filter，以及通用 `core.take` 与 `core.distinct-by-identity`。遍历按 canonical root/association 顺序，sharing 只访问一次且 cycle 不递归展开。

### `yaml.native-semantic-query@1`

支持 stream documents、document root、mapping entries、entry key/value、sequence elements、anchor definitions、alias occurrences、alias target 与 node kind/tag filter；所有结果保留 YAML 专属 role 和 source order。

所有 domain 都使用相同的 selection、Concat、StructureOrderMerge、limit、cancellation 和 ordered cursor 语义。

### Lossless Syntax Query v1/v2

- `json.lossless-syntax-query@1`：`json.syntax-kind-is@1`、`json.syntax-text-equals@1`，返回 `JsonSyntaxPiece`；
- `json.lossless-syntax-query@2`：为 JSON5 增加 `Identifier` syntax kind；JSON5 文档拒绝 v1 domain；
- `toml.lossless-syntax-query@1`：`toml.syntax-kind-is@1`、`toml.syntax-text-equals@1`，返回 `TomlSyntaxPiece`；
- `yaml.lossless-syntax-query@1`：`yaml.syntax-kind-is@1`、`yaml.syntax-text-equals@1`，返回 `YamlSyntaxPiece`。

三个 lossless domain 都以完整 structural pieces 作为 source-order 输入。kind 在产生第一个 match 前验证；kind enum 与 match 类型保持格式专属。ordered cursor 的最终状态只有 Completed、Cancelled、Failed，并且只在全部已发现项被消费或取消/失败被观察后可见。

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

JSON projection 继续通过显式 target 和 duplicate policy 在 Object/EntryMapping 之间选择，并报告任何 authorized loss。`json5.projection.best-exact-core@1` 只适用于 JSON5，并保留四种非有限 BinaryFloat64 位模式；旧 `json.projection.best-exact-core@1` 与新 target 跨 Profile 使用都会以 target-not-applicable 失败。

YAML 默认 target 是 `yaml.projection.best-exact-graph@1`：每个 document 形成一个 root，node/association 与 alias reference 都有精确 provenance。`yaml.projection.best-exact-value@1` 是显式 tree projection：cycle 永远失败；sharing 默认失败，只能对无环图由 `DuplicateAcyclic` 授权复制；custom tag 默认失败，只能由 `StripToNodeKind` 授权丢失；mapping 可显式选择 exact-first、RequireObject 或 RequireEntryMapping。全部 graph/value/provenance/report/depth/amplification 上限先于完整结果发布。

## 7. Materialization 与 audited conversion

Materialization 从完整 `PortableValue` 或 `PortableGraph` 和显式 `MaterializationRequest` 创建一个新文档；它不是既有文档的 formatter。请求冻结 target Profile、style、encoding、newline、EntryMapping policy、ExactOnly representability 以及 input/output/depth/report/provenance 上限。

- JSON/JSONC：`json.canonical-compact@1`、`json.canonical-pretty@1`，接受 JSON 可表示的 core kind；String-key `EntryMapping` 可保序保重复，非 String key 与 BinaryFloat/temporal/bytes 明确失败；
- JSON5：`json5.canonical-compact@1`、`json5.canonical-pretty@1`；普通值生成 strict JSON 子集，四种非有限位模式生成 `Infinity/-Infinity/NaN/-NaN`，有限 binary64 与其他 NaN payload 明确失败；
- TOML：`toml.canonical-document@1`，完整支持 TOML scalar、四类 temporal、array 与 nested object；根必须是 Object，或由调用方显式授权 unique String-key EntryMapping 转换为 Object；
- YAML：`yaml.canonical-block@1`、`yaml.canonical-flow@1`；PortableGraph 的 tag、任意 mapping key、sharing、cycle 与多 root 精确重建，PortableValue 通过 frozen best-exact projection 反验；跨 document sharing 与无已发布 constructor 的 custom tag 原子失败；
- 完成结果包含新 Document、fidelity、完整 report 与 input-value/association 到 target node/span 的 provenance；失败只包含 failure/report/analyzed paths，不包含文档或 partial bytes。

facade 的 `convert_json`/`convert_toml`/`convert_yaml` 只组合已发布的 PortableValue Projection 与 Materialization。中间值、两阶段 provenance、两阶段 fidelity/report 和 source/target Profile 都保留；overall fidelity 是两阶段最差值。未经 policy 授权的 projection loss、重复 key、YAML sharing/tag、不可表示 target value 或 materialization failure 都不会产生 target Document。PortableGraph 的图闭环使用独立的 graph projection/materialization，不伪装成 tree conversion。

## 8. 原子 scalar 与 structural edit

事务绑定一个 base snapshot；全部 target、candidate representation、resource limits 和 overlap 必须先验证，再一次性替换并重 parse。

TOML exact literal 必须恰好是一个 scalar span：前后 trivia、comment、container 或额外 assignment 均拒绝。semantic edit 只接受 TOML 可无损表示的 core scalar，并显式选择：

- `ExactLiteral`；
- `PreserveCompatible`；
- `CanonicalForProfile`；
- `PreserveElseCanonical`。

任意精度 Integer 超出 i64、携带 payload 的非 canonical NaN、亚纳秒 Time、非整分钟 OffsetDateTime 等均明确失败。成功 commit 产生新 Document 和包含 source edits、node mappings、diagnostics 的 ChangeSet；旧 snapshot 永不改变。

0.7.0 的 format operation registry 对全部 JSON family Profile 发布 8 个版本化操作，对 TOML 发布 7 个，对两个 YAML Profile 发布 8 个。三者共同包含 semantic/literal scalar replacement 和格式专属 collection edit；JSON 额外发布同对象 member move；YAML 额外发布 anchor rename 与 alias insertion，并对 live alias dependency、最新可见 anchor、block/flow placement、tag/anchor property boundary 和同容器冲突进行原子验证。相同操作名不表示格式间共享 trivia、delimiter、table、anchor 或 duplicate 语义。

结构 target 和 placement anchor 都使用 snapshot-bound `NodeRef`。JSON member 的重复身份不会按 key 合并；JSONC/JSON5 只修改 operation 所拥有的 delimiter/association 区域。member move 只允许同一 Object，保留原地 comment/trivia 所有权，并在 dry-run/commit 中产生相同 patch；跨对象/self anchor/并发修改显式失败。TOML entry 保留 root/standard/inline table ownership，rename 不能制造重复 direct key；0.7.0 不移动 table、不合成 dotted-key ownership，也不提供跨对象 move。YAML mapping/sequence edit 保留 association order、style 和 trivia；删除仍被 alias 引用的 anchor 或插入指向不可见定义的 alias 必须失败。

多操作冲突在发布新文档前统一判定，包括 wrong snapshot/role、missing or duplicate target、overlapping ownership、ancestor-descendant conflict、removed placement anchor、duplicate key、unrepresentable value、resource limit 与 reparse failure。成功同时产生新 Document、ChangeSet、UntouchedByteProof 和 SourcePatch；失败不产生其中任何一项。

`dry_run` 执行与 commit 相同的确定性验证和字节规划，输出 source ID、base digest、Profile、无内容操作摘要、精确 replacements、target digest 与 report。plan 不是文件写入授权；敏感 replacement 可在 review/debug 表示中 redacted，实际应用仍要求完整原始字节前置条件。

`SourcePatch` 是与格式无关的 raw-byte transition fact：它绑定 base/target digest、encoding facts、有序不重叠区间、原始字节前置条件和确定性 metadata。应用前完整验证 stale base、original bytes、encoding 与 target digest；任何失败都不返回新 snapshot。它不是 ChangeSet、语义 diff、merge、fuzzy patch 或文件系统写入授权。

## 9. Resource 与安全语义

- `ParseLimits`：source bytes、nesting、token/piece、node、diagnostic；
- `DecodeLimits`：PVCE bytes、depth、nodes、container、integer、blob；
- `ProtocolLimits`：canonical JSON/PVCE transport bytes、depth、nodes、container、integer、blob；
- `QueryLimits`：steps、results；
- `ProjectionLimits`：value nodes、report、provenance、depth。
- `GraphLimits`/`PgceLimits`：nodes、roots、edges、tag/content/stream bytes 与 depth；
- `ValueProjectionLimits`：YAML value visits、depth、report、provenance 与 amplification ratio；
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
| `consema.json-family.conformance@2` | 33/33 |
| `consema.portable-graph.conformance@1` | 10/10 |
| `consema.semantic-model-v5.conformance@1` | 22/22 |
| `consema.yaml.conformance@1` | 27/27 |
| JSON5 v2.2.3 reference valid/invalid | 43/43 + 39/39 |
| JSON5 v2.2.3 complete `package.json5` fixture | 1/1 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 valid | 205/205 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 invalid | 474/474 |
| `yaml/yaml-test-suite data-2022-01-17`, valid byte-exact | 307/307 |
| `yaml/yaml-test-suite data-2022-01-17`, invalid atomic rejection | 94/94 |
| YAML profile-contract exclusions | 1/1（`%YAML 1.3`） |

11 套语言无关向量共 255 个。新增 10 个 PortableGraph、22 个 semantic-model v5 和 27 个 YAML case，覆盖图同构/拓扑/PGCE/query、v1-v4 registry 冻结、graph/YAML wire payload，以及 YAML Profile、encoding、stream、syntax、native graph、projection、materialization、edit 和 limits。官方 YAML gate 完整枚举 402 个 upstream case，不使用 allowlist；唯一 exclusion 要求未来 `%YAML 1.3` directive 按当前 Profile 契约精确拒绝。Kubernetes、GitHub Actions、Compose 与 anchor-heavy 四类自有 MIT fixture 均完成 byte-exact parse/render、lossless coverage、graph/PGCE/materialization closure；tree-shaped fixture 另完成 PortableValue closure。YAML/PGCE hardening 覆盖逐字节 mutation、截断、Unicode、深度/node/token/source limit、alias bomb、cycle、custom tag 与 canonical decode。既有 JSON5/TOML 语料和门禁保持通过。

## 11. PVCE/1 固定项

- magic：ASCII `PVCE`；
- version：minimal unsigned LEB128 `1`；
- sign octet：`0 = zero`、`1 = positive`、`2 = negative`；
- tag、长度和计数：minimal unsigned LEB128；
- fixed float bits：network byte order。

任何不兼容编码修改必须使用新的 encoding version。

### PGCE/1 固定项

- magic：ASCII `PGCE`；
- version：minimal unsigned LEB128 `1`；
- roots 与 nodes 使用 canonical graph-local 编号；
- node kind、tag、scalar content、sequence edge 与 mapping association 全部有界编码；
- decode 后重新 canonical encode 必须产生相同字节，否则输入不是规范 PGCE/1。

## 12. Cross-format Protocol 与 semantic-model registries

RFC 0002 冻结 `core.semantic-model@1` 兼容性身份、`core.protocol-message@1` transport envelope、15 个稳定 payload 契约和 55 个公共 error code。每个 envelope payload 必须同时通过 contract registry、首字段 schema 和对应 typed decoder 的完整校验；只伪造正确 schema 不能形成消息。

协议对象只以固定字段 `PortableValue` 表达，同一 payload 通过 canonical tagged JSON 或 PVCE/1 传输。32 个语言无关 case 证明所有 15 个稳定 payload 都在两种 transport 上严格相等，并覆盖未知 contract/field、非规范表示、注册表矛盾、资源越界与 process-local identity 拒绝。

`NodeRef`、snapshot identity、cursor 与 `CancellationToken` 仍是 process-local。跨进程 Diagnostic、native Query match、Provenance、ChangeSet、MaterializationResult 与 EditPlan 必须由调用方提供稳定 `source_id`/`node_locator`；适配器缺少绑定时返回 `core.protocol.process-local-handle@1`，不静默删除身份事实。

ProjectionResult 的 present value 使用 `{ portable_value }` wrapper，因此成功的 PortableValue `Null` 与失败/缺席值不混淆。Completion failure、Diagnostic 和 ProjectionReport event code 都由同一个 ErrorCodeRegistry 校验；Diagnostic category 必须与注册表一致。

### Semantic model v2

RFC 0003 保持 `ContractRegistry::v1()` 的 16 条记录（15 stable + transport）和 `ErrorCodeRegistry::v1()` 的 55 个 code 精确不变。`core.semantic-model@2` 使用 18 条 contract record（增加 `core.source-snapshot@1`、`core.source-patch@1`）与 62 个 error code。`RegistryManifest::v1()`/`v2()` 显式构造冻结集合；旧 conformance 永远显式绑定其原 registry。

两个新 payload 的 decoder 都重新验证内容事实：SourceSnapshot 重算 digest、encoding resolution、decode status；SourcePatch 重新验证 schema、digest 表示、encoding facts、replacement order 与 limits。通过 wire 不会降低后续 patch application 的 stale/original/target 检查。

### Semantic model v3

RFC 0004 的 `ContractRegistry::v3()` 含 25 条记录，`ErrorCodeRegistry::v3()` 含 90 个 code。v3 在 v2 基础上增加 7 个 stable payload：

- `core.conversion-report@1`；
- `core.edit-plan@1`；
- `core.format-operation-registry@1`；
- `core.materialization-provenance-map@1`；
- `core.materialization-report@1`；
- `core.materialization-request@1`；
- `core.materialization-result@1`。

每个 payload 在 canonical JSON 与 PVCE/1 两条 transport 上使用同一固定字段 `PortableValue` schema 并重新验证交叉约束。`MaterializationResult` 显式区分 Complete/Failed；Complete 携带 verified target SourceSnapshot、Profile、report/provenance，Failed 不携带 target source 或 bytes。v1/v2 的 contract、error code、manifest 与 frozen constructor 不因 v3 改写。

### Semantic model v4

RFC 0005 的 `ContractRegistry::v4()` 保持 25 条 contract 记录；`ErrorCodeRegistry::v4()` 在冻结 v3 的 90 条基础上增加 `json5.string.unescaped-line-separator@1` 与 `json5.syntax.invalid-identifier@1`，合计 92 条。JSON5 专属 Diagnostic 只有在 v4 及以后 registry 下可外部化。

### Semantic model v5

RFC 0008 的 `ContractRegistry::v5()` 增至 30 条记录，新增 `core.portable-graph@1`、`core.graph-query-result@1`、`core.graph-provenance-map@1`、`core.graph-projection-result@1` 与 `core.yaml-query-result@1`。PortableGraph payload 同时携带 readable graph 与 canonical PGCE/1，decoder 要求两者严格一致；graph association、provenance location 和 YAML domain/role/order 都重新验证，raw process-local YAML handle 不能过 wire。

`ErrorCodeRegistry::v5()` 在 v4 的 92 条上增加 40 条 graph/PGCE/YAML formation/projection/materialization/edit code，共 132 条。`RegistryManifest::current()` 在 0.7.0 指向 v5；v1-v4 的 contract/error 集合、manifest 和 frozen constructors 精确不变。内部 graph/YAML failure 通过 exhaustive mapping 发布稳定 code，不依赖 Rust Debug/Display 文本。

## 13. 0.7.0 明确边界

本版本没有 INI、Properties、XML、plist、HCL、Schema、semantic diff/merge、Formatter、Live Query、增量解析、跨对象 member move/table move、文件系统原子替换、稳定进程插件协议或 Go 实现。JSON5 不执行 JavaScript 表达式、import、computed key、method、regex、template literal、`undefined` 或 bigint。YAML 不执行 custom constructor、merge、include/import、remote tag 或 alias expansion；不提供跨 document anchor、general formatter、graph diff/merge 或跨容器 node move。`SourcePatch` 仍只声明精确 raw-byte transition；`EditPlan` 仍只声明已验证计划，二者都不授予文件系统写入权限。

这些不是“隐藏支持”或文档遗漏；它们是路线图后续版本的显式工作。0.7.0 只声明已由代码、语言无关向量、adversarial tests、真实夹具、固定基准和上游 suite 共同证明的 capability。
