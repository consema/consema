# Consema

Consema 是《配置内容统一处理标准与 Rust 参考实现》的 Rust `0.5.0` 落地。

它将无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑分离；默认拒绝未经授权的转换、截断或信息损失。

## 当前实现

- JSON：`json.strict@1`、`jsonc.bounded@1`；
- TOML：`toml.1.0@1`；
- PortableValue 全部 15 类核心值与 strict equality/hash；
- PVCE/1 canonical encode 与 strict bounded decode；
- raw-byte `SourceSnapshot`、SHA-256 content identity、UTF-8/UTF-16LE/UTF-16BE/Latin-1/Binary encoding facts 与精确 decoded locations；
- JSON/TOML format-specific lossless Syntax Query 与显式 Completed/Cancelled/Failed cursor terminal；
- 可验证、原子、基于原始字节前置条件的 `SourcePatch`；
- `core.protocol-message@1` 公共 envelope、semantic-model v1/v2/v3 注册表与 canonical JSON/PVCE 双传输；
- Profile、Capability、Diagnostic、Query、Projection、Provenance、ChangeSet、Execution、Completion 与 registry 的固定 wire schema；
- snapshot-bound `NodeRef`/`Span`、exhaustive lossless source coverage；
- versioned typed query、完整 projection/report/provenance；
- JSON/JSONC compact/pretty 与 TOML canonical materialization，显式 style/newline/encoding/mapping/representability policy；
- JSON↔TOML 由 Projection 与 Materialization 组合的可审计转换，保留两阶段 fidelity、report 与 provenance；
- JSON/TOML 各 7 个版本化编辑操作，支持标量替换、成员/entry/array element 插入删除和 key rename；
- snapshot-bound 原子事务、dry-run `EditPlan`、`UntouchedByteProof` 与可重放 `SourcePatch`；
- 25 条 semantic-model v3 contract registry 记录与 90 个公共 error code，同时精确冻结 v1/v2；
- 20 个 core/JSON、18 个 TOML、32 个 protocol v1、28 个 source、19 个 syntax-query、11 个 protocol v2 与 35 个 operations v1 语言无关 conformance cases，共 163 个；
- 官方 `toml-test v2.2.0` TOML 1.0 decoder gate：205 valid + 474 invalid 全部通过。

TOML table、inline table、array-of-tables、dotted key 和 array 拥有各自原生身份，不复用 JSON object/member 类型。`.env` 不属于当前格式 Profile；它在产品路线中是 source adapter。

## Roadmap

- 现有语义基线：[配置内容统一处理标准与 Rust 参考实现.md](配置内容统一处理标准与%20Rust%20参考实现.md)
- 完整生产级 `1.0.0` 路线：[Consema 1.0.0 产品路线图与双语言落地设计.md](Consema%201.0.0%20产品路线图与双语言落地设计.md)
- TOML 0.2 契约：[RFC 0001](docs/rfcs/0001-toml-1.0-profile.md)
- 跨格式协议 v1：[RFC 0002](docs/rfcs/0002-cross-format-protocol-v1.md)
- raw source、Syntax Query 与 SourcePatch v1：[RFC 0003](docs/rfcs/0003-source-syntax-query-and-patch-v1.md)
- Materialization、conversion 与结构编辑 v1：[RFC 0004](docs/rfcs/0004-materialization-conversion-and-structural-edit-v1.md)
- 上游 TOML 门禁：[Official TOML 1.0 compatibility gate](docs/UPSTREAM-TOML-TEST.md)
- 版本变更记录：[CHANGELOG](CHANGELOG.md)

`1.0.0` 的目标不是最小闭环，而是覆盖 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个格式家族，并由 Rust、Go 两个独立实现共同证明。Go 只在 Rust Feature-Complete Gate 全部通过后开始。

## Workspace

- `consema-core`：PortableValue、诊断、Capability 和类型化查询协议；
- `consema-pvce`：PVCE/1 规范编码与严格解码；
- `consema-document`：不可变 source snapshot、Span、NodeRef、materialization、edit plan、proof 与 ChangeSet 公共事实；
- `consema-json`：JSON/JSONC 无损文档、原生语义、查询、投影、materialization 与结构编辑；
- `consema-toml`：TOML 1.0 无损文档、原生 item、查询、投影、materialization 与结构编辑；
- `consema-protocol`：语言无关固定 schema、公共注册表、canonical JSON/PVCE transport 与严格 payload validation；
- `consema-conformance`：语言无关向量 runner、硬化语料和官方 TOML adapter；
- `consema`：公共 facade，导出 `core/document/json/toml/protocol/pvce`。

## TOML 示例

```rust
use consema::document::ParseLimits;
use consema::toml::{
    ProjectionRequest, ProjectionResult, ProjectionTarget, TomlProfile, parse,
};

let source = br#"
service.name = "catalog"
service.ports = [8080, 8081]
"#;

let document = parse(source.as_slice(), TomlProfile::Toml10V1, ParseLimits::default())
    .expect("valid TOML");
assert_eq!(document.render(), source);

let service = document.root().table_entries().unwrap()[0].item();
assert_eq!(service.table_entries().unwrap().len(), 2);

let projected = document.project(ProjectionRequest::new(
    ProjectionTarget::BestExactCoreV1,
));
let ProjectionResult::Complete(projected) = projected else {
    panic!("projection must be complete");
};
assert!(projected.value.as_object().is_some());
```

## 协议示例

```rust
use consema::protocol::{
    Completion, CompletionStatus, ContractId, ContractRegistry,
    ProtocolLimits, ProtocolMessage,
};

let completion = Completion::new(CompletionStatus::Success, 1, 1, None, None)
    .expect("valid completion");
let message = ProtocolMessage::new(
    ContractId::new("core.completion", 1).unwrap(),
    completion.to_value(),
    ContractRegistry::v1(),
)
.expect("fully validated payload");

let limits = ProtocolLimits::default();
let json = message.to_json(limits).expect("canonical JSON");
let decoded = ProtocolMessage::from_json(&json, limits, ContractRegistry::v1())
    .expect("strict transport and typed payload validation");
assert_eq!(decoded, message);
```

## Materialization 示例

```rust
use consema::core::{ObjectBuilder, PortableValue};
use consema::document::{
    MaterializationRequest, MaterializationResult, MaterializationStyleId,
    NewlinePolicy, ProfileId,
};

let mut value = ObjectBuilder::new();
value.insert("service", PortableValue::string("catalog")).unwrap();
value.insert("port", PortableValue::integer(8080_i64.into())).unwrap();

let request = MaterializationRequest::new(
    ProfileId::new("json.strict", 1),
    MaterializationStyleId::new("json.canonical-pretty", 1),
)
.with_newline(NewlinePolicy::Lf);

let MaterializationResult::Complete(result) =
    consema::json::materialize(&value.build(), &request)
else {
    panic!("value must be representable");
};
assert_eq!(result.fidelity, consema::document::MaterializationFidelity::Exact);
assert!(result.provenance.entries().len() >= 3);
```

## 原子结构编辑示例

```rust
use consema::core::PortableValue;
use consema::document::{AssociationPlacement, ParseLimits};
use consema::json::{EditTransactionBuilder, JsonProfile, parse};

let document = parse(
    br#"{"service":"catalog"}"#.as_slice(),
    JsonProfile::StrictV1,
    ParseLimits::default(),
).unwrap();
let mut transaction = EditTransactionBuilder::new(&document);
transaction.insert_member(
    document.root().node_ref(),
    "enabled",
    PortableValue::boolean(true),
    AssociationPlacement::End,
);

let commit = document.commit(&transaction.build()).unwrap();
assert_eq!(commit.document.render(), br#"{"service":"catalog","enabled":true}"#);
let replay = commit.source_patch.apply(document.source(), Default::default()).unwrap();
assert_eq!(replay.bytes(), commit.document.render());
commit.untouched_proof.verify(
    document.source(),
    commit.document.source(),
    commit.source_patch.replacements(),
).unwrap();
```

## 验证

```text
cargo fmt --all -- --check
cargo test --locked --workspace --all-targets
cargo clippy --locked --workspace --all-targets -- -D warnings
RUSTDOCFLAGS="-D warnings" cargo doc --locked --workspace --no-deps
cargo audit
cargo deny check
```

官方 TOML 1.0 gate：

```powershell
./scripts/run-toml-test.ps1
```

当前未实现 JSON5、YAML、INI、XML、Properties、plist、HCL、semantic diff/merge、formatter、通用 reorder/table move、文件系统写入事务和 Go。公共 source 层已支持多编码，但现有 JSON/TOML Profile 仍按各自已发布入口接受 UTF-8；格式级编码声明与准入将在对应格式里程碑单独冻结。这些能力按路线图逐阶段落地，不以 README 声明代替完成证据。
