# Consema

Consema 是《配置内容统一处理标准与 Rust 参考实现》的 Rust `0.8.0` 落地。

它将无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑分离；默认拒绝未经授权的转换、截断或信息损失。

## 当前实现

- JSON family：`json.strict@1`、`jsonc.bounded@1`、`json5.standard@1`；
- TOML：`toml.1.0@1`；
- YAML family：`yaml.1.2-core@1`、`yaml.1.1-compat@1`，支持 UTF-8/UTF-16、空流与多文档 stream；
- INI family：`ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1`，不做扩展名猜测或方言自动选择；
- Java Properties：`java-properties.reader@1`、`java-properties.latin1@1`，精确保留 Java UTF-16 code unit 与重复属性身份；
- PortableValue 全部 15 类核心值与 strict equality/hash；
- PVCE/1 canonical encode 与 strict bounded decode；
- PortableGraph@1：保留 tag、任意/重复 mapping key、共享、cycle 与多 root，提供 strict graph equality/hash、PGCE/1 和确定性 graph query；
- raw-byte `SourceSnapshot`、SHA-256 content identity、UTF-8/UTF-16LE/UTF-16BE/Latin-1/Binary/版本化 Windows code-page facts、显式 BOM policy 与精确 decoded locations；
- JSON v1/v2、TOML、YAML、INI 与 Properties format-specific native/lossless Syntax Query，以及显式 Completed/Cancelled/Failed cursor terminal；
- 可验证、原子、基于原始字节前置条件的 `SourcePatch`；
- `core.protocol-message@1` 公共 envelope、semantic-model v1/v2/v3/v4/v5/v6 注册表与 canonical JSON/PVCE 双传输；
- Profile、Capability、Diagnostic、Query、Projection、Provenance、ChangeSet、Execution、Completion 与 registry 的固定 wire schema；
- snapshot-bound `NodeRef`/`Span`、exhaustive lossless source coverage；
- versioned typed query、完整 projection/report/provenance；
- JSON/JSONC/JSON5 compact/pretty、TOML canonical、YAML block/flow、INI 三种 Profile canonical 与 Properties Reader/Latin-1 canonical materialization，显式 style/newline/encoding/mapping/representability policy；
- JSON、TOML、YAML、INI 与 Properties 的 audited conversion 均由 Projection 与 Materialization 组合，保留两阶段 fidelity、report 与 provenance；
- JSON 8 个、TOML 7 个、YAML 8 个、INI 8 个及 Properties 5 个版本化编辑操作；格式间相同抽象操作不共享 trivia、delimiter、duplicate 或 encoding 规则；
- snapshot-bound 原子事务、dry-run `EditPlan`、`UntouchedByteProof` 与可重放 `SourcePatch`；
- semantic-model v6 发布 38 条 contract registry 记录与 166 个公共 error code，同时精确冻结 v1/v2/v3/v4/v5；
- 14 套语言无关 conformance suite 共 332/332 cases，其中 semantic-model v6 为 25/25、INI family 为 20/20、Java Properties 为 22/22；
- 官方 JSON5 v2.2.3 参考语料 43 valid + 39 invalid 与完整 `package.json5` 夹具共 83/83；
- 官方 `toml-test v2.2.0` TOML 1.0 decoder gate：205 valid + 474 invalid 全部通过；
- 官方 `yaml/yaml-test-suite data-2022-01-17` 完整 402-case gate：307 valid byte-exact、94 invalid atomic rejection、1 个明确 Profile exclusion；
- 固定 OpenJDK、CPython、.NET、Windows profile API 与 Qt 的 5 套 INI/Properties runtime oracle，共 36/36 个差分案例。

TOML table、inline table、array-of-tables、dotted key 和 array 拥有各自原生身份，不复用 JSON object/member 类型。`.env` 不属于当前格式 Profile；它在产品路线中是 source adapter。

## Roadmap

- 现有语义基线：[配置内容统一处理标准与 Rust 参考实现.md](配置内容统一处理标准与%20Rust%20参考实现.md)
- 完整生产级 `1.0.0` 路线：[Consema 1.0.0 产品路线图与双语言落地设计.md](Consema%201.0.0%20产品路线图与双语言落地设计.md)
- TOML 0.2 契约：[RFC 0001](docs/rfcs/0001-toml-1.0-profile.md)
- 跨格式协议 v1：[RFC 0002](docs/rfcs/0002-cross-format-protocol-v1.md)
- raw source、Syntax Query 与 SourcePatch v1：[RFC 0003](docs/rfcs/0003-source-syntax-query-and-patch-v1.md)
- Materialization、conversion 与结构编辑 v1：[RFC 0004](docs/rfcs/0004-materialization-conversion-and-structural-edit-v1.md)
- JSON family 生产 Profile 与 JSON5 v1：[RFC 0005](docs/rfcs/0005-json-family-production-v1.md)
- PortableGraph 与 PGCE/1：[RFC 0006](docs/rfcs/0006-portable-graph-and-pgce-v1.md)
- YAML family Profiles 与安全边界：[RFC 0007](docs/rfcs/0007-yaml-family-profiles-and-safety-v1.md)
- semantic-model v5 graph/YAML 协议：[RFC 0008](docs/rfcs/0008-semantic-model-v5.md)
- INI family 三 Profile：[RFC 0009](docs/rfcs/0009-ini-family-profiles-v1.md)
- Java Properties Reader/Latin-1：[RFC 0010](docs/rfcs/0010-java-properties-profiles-v1.md)
- semantic-model v6 line-format 协议：[RFC 0011](docs/rfcs/0011-semantic-model-v6.md)
- JSON family 0.6.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.6.0.md)
- YAML 0.7.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.7.0.md)
- INI/Properties 0.8.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.8.0.md)
- 0.7.0 迁移、安全与发布记录：[Release record](docs/RELEASE-0.7.0.md)
- JSON5 v2.2.3 上游参考门禁：[Reference corpus provenance](docs/UPSTREAM-JSON5-REFERENCE.md)
- 上游 TOML 门禁：[Official TOML 1.0 compatibility gate](docs/UPSTREAM-TOML-TEST.md)
- 上游 YAML 门禁：[Official YAML test-suite acceptance gate](docs/UPSTREAM-YAML-TEST-SUITE.md)
- 版本变更记录：[CHANGELOG](CHANGELOG.md)

`1.0.0` 的目标不是最小闭环，而是覆盖 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个格式家族，并由 Rust、Go 两个独立实现共同证明。Go 只在 Rust Feature-Complete Gate 全部通过后开始。

## Workspace

- `consema-core`：PortableValue、诊断、Capability 和类型化查询协议；
- `consema-pvce`：PVCE/1 规范编码与严格解码；
- `consema-graph`：PortableGraph、PGCE/1 与 graph query；
- `consema-document`：不可变 source snapshot、Span、NodeRef、materialization、edit plan、proof 与 ChangeSet 公共事实；
- `consema-json`：JSON/JSONC/JSON5 无损文档、精确原生语义、查询、投影、materialization 与结构编辑；
- `consema-toml`：TOML 1.0 无损文档、原生 item、查询、投影、materialization 与结构编辑；
- `consema-yaml`：YAML 1.2 Core/1.1 compat 无损 stream、原生图语义、查询、投影、materialization 与原子编辑；
- `consema-ini`：Portable/Windows/Python ConfigParser 无损文档、Profile 原生语义、查询、投影、materialization 与原子编辑；
- `consema-properties`：Reader/Latin-1 无损文档、Java UTF-16 原生语义、查询、投影、materialization 与原子编辑；
- `consema-protocol`：语言无关固定 schema、公共注册表、canonical JSON/PVCE transport 与严格 payload validation；
- `consema-conformance`：语言无关向量 runner、上游语料、固定 runtime oracle、真实配置夹具、硬化与基准工具；
- `consema`：公共 facade，导出 `core/document/graph/ini/json/properties/toml/yaml/protocol/pvce`。

## JSON5 到 strict JSON 示例

```rust
use consema::{ConversionResult, convert_json};
use consema::document::{
    MaterializationRequest, MaterializationStyleId, NewlinePolicy, ParseLimits, ProfileId,
};
use consema::json::{
    JsonProfile, ProjectionRequestBuilder, ProjectionTarget, parse,
};

let source = br"{service:'catalog',limit:0x100,retry:.25,enabled:true,}";
let document = parse(
    source.as_slice(),
    JsonProfile::Json5StandardV1,
    ParseLimits::default(),
).expect("valid JSON5");
assert_eq!(document.render(), source);

let projection = ProjectionRequestBuilder::new(
    ProjectionTarget::Json5BestExactCoreV1,
).build().unwrap();
let target = MaterializationRequest::new(
    ProfileId::new("json.strict", 1),
    MaterializationStyleId::new("json.canonical-compact", 1),
).with_newline(NewlinePolicy::None);

let ConversionResult::Complete(converted) = convert_json(&document, &projection, &target)
else { panic!("finite JSON5 is exactly representable as strict JSON") };
assert_eq!(
    converted.document.render(),
    br#"{"service":"catalog","limit":256,"retry":25e-2,"enabled":true}"#,
);
```

`Infinity`、`NaN` 只映射到四种冻结的 BinaryFloat64 位模式；转换到 strict JSON 时显式失败，不会改写为字符串或 `null`。

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

## YAML 图语义示例

```rust
use consema::document::ParseLimits;
use consema::graph::{decode_pgce, encode_pgce, PgceLimits};
use consema::yaml::{ValueProjectionRequest, ValueProjectionResult, YamlProfile, parse};

let source = b"&root [one, *root]\n";
let document = parse(
    source.as_slice(),
    YamlProfile::Yaml12CoreV1,
    ParseLimits::default(),
).expect("valid cyclic YAML graph");
assert_eq!(document.render(), source);

let graph = document.project_graph().expect("exact graph projection");
assert_eq!(graph.node_count(), 2);
let pgce = encode_pgce(&graph).expect("canonical PGCE/1");
assert_eq!(decode_pgce(&pgce, PgceLimits::default()).unwrap(), graph);

assert!(matches!(
    document.project_value(ValueProjectionRequest::best_exact_v1()),
    ValueProjectionResult::Failed(_),
));
```

YAML alias/cycle 默认保留在 PortableGraph，不会被塞入 PortableValue 或隐式展开。调用方只有在图无环且明确选择 `SharingPolicy::DuplicateAcyclic` 时，才能授权共享节点复制为树。

## INI 显式 Profile 示例

```rust
use consema::ini::{
    IniEncodingSelection, IniParseLimits, IniProfile, ProjectionRequest,
    ProjectionResult, parse,
};

let source = b"[server]\nport=8080\nenabled=true\n";
let document = parse(
    source.as_slice(),
    IniProfile::PortableV1,
    IniEncodingSelection::ProfileDefault,
    IniParseLimits::default(),
).expect("valid portable INI");
assert_eq!(document.render(), source);
assert_eq!(document.entries().len(), 2);

let ProjectionResult::Complete(projected) =
    document.project(ProjectionRequest::best_exact_entry_mapping())
else { panic!("unique portable INI must project exactly") };
assert_eq!(projected.value.as_entry_mapping().unwrap().len(), 1);
```

同一输入若要按 Windows 或 Python ConfigParser 规则解释，调用方必须改选对应 Profile 和 encoding contract；库不会尝试多方言解析后挑一个“成功结果”。

## Java Properties 示例

```rust
use consema::document::SourceEncoding;
use consema::properties::{
    PropertiesParseLimits, ProjectionRequest, ProjectionResult, parse_reader,
};

let source = "greeting=你好\npath=C\\:\\\\work\n".as_bytes();
let document = parse_reader(
    source,
    SourceEncoding::Utf8,
    PropertiesParseLimits::default(),
).expect("valid Reader Properties");
assert_eq!(document.render(), source);
assert_eq!(document.properties()[0].value().to_unicode().unwrap(), "你好");

let ProjectionResult::Complete(projected) =
    document.project(ProjectionRequest::best_exact_entry_mapping())
else { panic!("well-formed Java strings must project exactly") };
assert_eq!(projected.value.as_entry_mapping().unwrap().len(), 2);
```

`reader@1` 的字符编码由调用方显式选择；`latin1@1` 对应 `Properties.load(InputStream)` 的单字节语义。`\uXXXX` 可形成未配对 surrogate，此时 native `JavaString` 仍完整，但普通 PortableValue String 投影会原子失败。

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
cargo test --locked --workspace --all-targets --all-features
cargo clippy --locked --workspace --all-targets --all-features -- -D warnings
RUSTDOCFLAGS="-D warnings" cargo doc --locked --workspace --all-features --no-deps
cargo audit
cargo deny check
cargo run --locked --offline --release -p consema-conformance --example json_family_baseline -- 20000
cargo run --locked --offline --release -p consema-conformance --example yaml_baseline -- 20000
cargo run --locked --offline --release -p consema-conformance --example line_formats_baseline -- 20000
```

固定上游格式 gate：

```powershell
./scripts/run-toml-test.ps1
./scripts/run-yaml-test-suite.ps1
./scripts/run-properties-jdk-oracle.ps1
./scripts/run-python-configparser-oracle.ps1
./scripts/run-dotnet-ini-oracle.ps1
./scripts/run-windows-ini-oracle.ps1
./scripts/run-qt-ini-oracle.ps1
```

当前未实现 XML、plist、HCL、semantic diff/merge、formatter、跨对象 member move/通用 table move、文件系统写入事务和 Go。JSON family/TOML Profile 仍按各自入口接受 UTF-8；YAML、INI 与 Properties 各自使用已冻结的显式 source/encoding contract。后续能力按路线图逐阶段落地，不以 README 声明代替完成证据。
