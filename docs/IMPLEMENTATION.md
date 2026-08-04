# Rust `0.2.0` 实现契约

本文记录 Consema 0.2.0 的 crate 边界、版本化 registry、可验证入口和明确非目标。语义权威顺序为：

1. 根目录《配置内容统一处理标准与 Rust 参考实现》中的永久不变量；
2. 已接受 RFC；
3. 语言无关 conformance vectors；
4. 本实现文档和 Rust API；
5. 第三方 parser 行为仅是实现细节，不构成公共契约。

## 1. 数据流与 crate 边界

```text
UTF-8 source bytes
  -> format profile parse
  -> immutable JSON or TOML Document snapshot
       |- exact render + exhaustive structural coverage
       |- format-native values/items and association identities
       |- validated ExecutableQuery -> ordered native matches
       |- explicit ProjectionRequest -> complete value/report/provenance OR failure
       `- EditTransaction -> new Document + complete ChangeSet OR atomic failure

PortableValue <-> PVCE/1
```

依赖只能向下：

```text
consema-core
  ↑
consema-document       consema-pvce
  ↑
consema-json           consema-toml
  ↑                         ↑
consema-conformance / consema facade
```

格式 crate 之间不互相依赖。`consema-core` 不依赖格式；`consema-document` 不理解 JSON/TOML 语义；跨格式操作必须通过公共 projection/materialization contract 组合。

## 2. 公共 document 事实

每次成功 parse 或 edit commit 都产生新的 `SnapshotIdentity`。`NodeRef` 和 `Span` 只能由所属 `DocumentAuthority` 验证；相同 source 的两次 parse 也不是同一 snapshot。

`LosslessStructuralIndex` 要求 source 从 byte 0 到末尾被有序的 Token/Trivia/ErrorRegion 无空洞、无重叠覆盖。默认 `Document::render()` 返回当前 snapshot 的精确 source bytes。

0.2.0 的 source 仍只接受 UTF-8。raw bytes、多编码和 encoding provenance 属于 0.4.0，不在本版本伪装实现。

## 3. JSON profiles

- `json.strict@1`：strict JSON 与明确 duplicate/BOM diagnostics；
- `jsonc.bounded@1`：在 strict 基础上允许 bounded comments、trailing comma 和受控 BOM。

JSON native model 保留 object member 和 array element 的 association identity，object 重复 member 不会在 parse 阶段折叠。Recovered document 使用显式 recovery structure；局部 native semantics 可以 unavailable。

## 4. TOML profile 与原生模型

`toml.1.0@1` 只形成完整合法 TOML 1.0 文档。语法错误是 `FatalFormationFailure`；0.2.0 不声明 TOML recovery capability。

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

## 7. 原子 scalar edit

事务绑定一个 base snapshot；全部 target、candidate representation、resource limits 和 overlap 必须先验证，再一次性替换并重 parse。

TOML exact literal 必须恰好是一个 scalar span：前后 trivia、comment、container 或额外 assignment 均拒绝。semantic edit 只接受 TOML 可无损表示的 core scalar，并显式选择：

- `ExactLiteral`；
- `PreserveCompatible`；
- `CanonicalForProfile`；
- `PreserveElseCanonical`。

任意精度 Integer 超出 i64、携带 payload 的非 canonical NaN、亚纳秒 Time、非整分钟 OffsetDateTime 等均明确失败。成功 commit 产生新 Document 和包含 source edits、node mappings、diagnostics 的 ChangeSet；旧 snapshot 永不改变。

0.2.0 不支持 key rename、insert/delete、table move、container replacement 或结构编辑。

## 8. Resource 与安全语义

- `ParseLimits`：source bytes、nesting、token/piece、node、diagnostic；
- `DecodeLimits`：PVCE bytes、depth、nodes、container、integer、blob；
- `QueryLimits`：steps、results；
- `ProjectionLimits`：value nodes、report、provenance、depth。

超限返回 fatal/failed 状态，不能把截断包装成成功。所有 workspace crates `unsafe_code = forbid`。

## 9. Conformance 证据

| Gate | 结果 |
|---|---|
| `consema.conformance@1` | 20/20 |
| `consema.toml.conformance@1` | 18/18 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 valid | 205/205 |
| `toml-lang/toml-test v2.2.0`, TOML 1.0 invalid | 474/474 |

TOML corpus 包含全类型、复杂 string/trivia、真实 service config、本仓库实际 Cargo manifest、PEP 621 pyproject 和非法重复 key。官方 adapter 只使用 Consema 公共 TOML API 输出 tagged JSON。

## 10. PVCE/1 固定项

- magic：ASCII `PVCE`；
- version：minimal unsigned LEB128 `1`；
- sign octet：`0 = zero`、`1 = positive`、`2 = negative`；
- tag、长度和计数：minimal unsigned LEB128；
- fixed float bits：network byte order。

任何不兼容编码修改必须使用新的 encoding version。

## 11. 0.2.0 明确边界

本版本没有 YAML、INI、Properties、XML、plist、HCL、raw multi-encoding source、Syntax Query、Schema、Diff/Patch、Formatter、Live Query、增量解析、Materialization、PortableGraph、全量结构编辑、稳定进程插件协议或 Go 实现。

这些不是“隐藏支持”或文档遗漏；它们是路线图后续版本的显式工作。0.2.0 只声明已由代码、语言无关向量和上游 suite 共同证明的 capability。

