# Rust `0.1.0` 实现契约

本文件记录《配置内容统一处理标准与 Rust 参考实现.md》落到代码后的 crate 边界、版本化 registry 和可验证入口。架构语义仍以根目录设计基线为权威。

## 数据流与 crate 边界

```text
SourceSnapshot
  -> consema-json::parse
  -> immutable consema-json::Document
       |- exact render / lossless structural index
       |- native JsonValue / member / element views
       |- ExecutableQuery -> ordered matches
       |- ProjectionRequest -> complete value + report + provenance
       `- EditTransaction -> new Document + ChangeSet

PortableValue
  <-> consema-pvce::PVCE/1
```

`consema-core` 不依赖格式 crate；`consema-document` 只提供快照事实；`consema-json` 持有格式语法和原生语义。公开类型不暴露 parser AST、arena 或第三方树类型。

## Mandatory Capability 对照

| Capability | 入口 | 验证 |
|---|---|---|
| `core.value.strict-equality@1` | `PortableValue: Eq + Hash` | core unit + conformance |
| `core.pvce.full@1` | `consema_pvce::{encode,decode}` | 全核心类型、固定向量、非规范拒绝 |
| `core.document.exact-roundtrip@1` | `Document::render` | strict/JSONC exact bytes |
| `json.document.lossless-syntax@1` | `Document::lossless_structural_index` | 逐字节无 gap/overlap |
| `json.native.duplicate-members@1` | `JsonValue::object_members` | 重复名称、顺序和身份 |
| `core.query.ordered-results@1` | `ExecutableQuery` + JSON executor | 角色验证、顺序、基数、cursor |
| `core.query.protocol@1` | `QueryDefinition::{to,from}_protocol_value` | round trip、未知字段拒绝 |
| `json.projection.best-exact-core@1` | `Document::project` | Object/EntryMapping 决策 |
| `json.projection.project-as-object@1` | duplicate policy rules | Reject/FirstWins/LastWins |
| `json.edit.scalar-replace@1` | `Document::commit` | minimal edit、trivia、wrong snapshot |
| `core.parse.resource-limits@1` | `ParseLimits` | fatal、无截断假成功 |

机器可读向量位于 `conformance/vectors/v1.json`；Rust runner 是 `consema_conformance::run_v1`。

## PVCE/1 wire 常量

设计基线冻结 tag 与规范性，但没有给出 magic、sign octet 和 unsigned varint 的比特布局。Rust `0.1.0` 将这些剩余项冻结为：

- magic：ASCII `PVCE`；
- version：minimal unsigned LEB128 `1`；
- sign octet：`0 = zero`、`1 = positive`、`2 = negative`；
- tag、长度和计数：minimal unsigned LEB128；
- fixed float bits：network byte order。

完整字段编码直接记录在 `consema-pvce` crate 根文档和冻结向量中。任何不兼容修改必须使用新的 encoding version。

## Query operator registry v1

所有 ID 均使用 version `1`。定义在产生首个 Match 前完成 domain、参数和角色验证。

### `core.portable-value-query@1`

| Operator ID | 输入角色 | 输出角色 | 参数 |
|---|---|---|---|
| `core.try-object-entries` | `Value` | `ObjectEntry` | — |
| `core.object-entry-name-equals` | `ObjectEntry` | `ObjectEntry` | `name: String` |
| `core.object-entry-value` | `ObjectEntry` | `Value` | — |
| `core.try-entry-mapping-entries` | `Value` | `EntryMappingEntry` | — |
| `core.entry-key` | `EntryMappingEntry` | `Value` | — |
| `core.entry-value` | `EntryMappingEntry` | `Value` | — |
| `core.try-sequence-elements` | `Value` | `Value` | — |
| `core.where-type` | `Value` | `Value` | `kind: String` |
| `core.require-type` | `Value` | `Value` | `kind: String` |

### `json.native-semantic-query@1`

| Operator ID | 输入角色 | 输出角色 | 参数 |
|---|---|---|---|
| `json.try-object-members` | `JsonValue` | `JsonObjectMember` | — |
| `json.member-name-equals` | `JsonObjectMember` | `JsonObjectMember` | `name: String` |
| `json.member-value` | `JsonObjectMember` | `JsonValue` | — |
| `json.try-array-elements` | `JsonValue` | `JsonArrayElement` | — |
| `json.array-element-value` | `JsonArrayElement` | `JsonValue` | — |

两个 domain 都支持 `core.take(count: Integer)` 和 `core.distinct-by-identity`。组合层支持 `Concat` 与 `StructureOrderMerge`；完成选择支持 `All`、`First`、`Last`、`ZeroOrOne`、`RequireOne`。

## Query protocol schema

`core.query-definition@1` 是固定顺序 Object：

```text
schema
domain_id
domain_version
selection
expression
```

表达式使用 `Input`、`Apply`、`Concat`、`StructureOrderMerge`；operator 固定字段为 `id`、`version`、`arguments`。所有未知、缺失、重排字段均拒绝。协议链是：

```text
QueryDefinition -> PortableValue -> PVCE/1
```

## 最小使用示例

```rust
use consema::core::{
    CapabilityId, CapabilitySet, OperatorCall, PortableValue, QueryDefinition,
    QueryDomain, QueryExpression, QueryLimits,
};
use consema::document::ParseLimits;
use consema::json::{
    execute_json_query, parse, DuplicateKeyPolicy, JsonProfile,
    ProjectionRequestBuilder, ProjectionTarget,
};

let document = parse(
    br#"{"a":1,"a":2}"#.as_slice(),
    JsonProfile::StrictV1,
    ParseLimits::default(),
)?;

let definition = QueryDefinition::new(QueryDomain::json_native_v1()).with_expression(
    QueryExpression::Input
        .then(OperatorCall::new("json.try-object-members", 1))
        .then(
            OperatorCall::new("json.member-name-equals", 1)
                .with_argument("name", PortableValue::string("a")),
        ),
);
let mut capabilities = CapabilitySet::new();
capabilities.insert(CapabilityId::new("core.query.ordered-results", 1));
let executable = definition.validate()?.bind(&capabilities)?;
let matches = execute_json_query(
    &executable,
    &document,
    QueryLimits::default(),
    &Default::default(),
)?;
assert_eq!(matches.matches().len(), 2);

let request = ProjectionRequestBuilder::new(ProjectionTarget::ProjectAsObjectV1)
    .global_duplicate_policy(DuplicateKeyPolicy::LastWins)
    .build()?;
let result = document.project(&request);
# Ok::<(), Box<dyn std::error::Error>>(())
```

## 明确边界

首版没有公开 Syntax Query domain，也没有 TOML、YAML、Schema、Diff/Patch、Formatter、Live Query、增量解析、表达式执行、引用解析、PortableGraph、全量结构编辑或稳定进程插件协议。JSON typed syntax 与内部 entity index 不提升为跨格式公共 CST。

