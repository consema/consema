# Consema

本文档描述 Rust 参考实现的 0.8.0-1.0.0-rc.1 特性面（workspace 版本推进 0.8.0→1.0.0-rc.1 已完成，2209582 提交；真实发布执行仍属发布检查单，fc-manifest 开放项 C-3）。

它将无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑分离；默认拒绝未经授权的转换、截断或信息损失。

## 当前实现

- JSON family：`json.strict@1`、`jsonc.bounded@1`、`json5.standard@1`；
- TOML：`toml.1.0@1`；
- YAML family：`yaml.1.2-core@1`、`yaml.1.1-compat@1`，支持 UTF-8/UTF-16、空流与多文档 stream；
- INI family：`ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1`，不做扩展名猜测或方言自动选择；
- Java Properties：`java-properties.reader@1`、`java-properties.latin1@1`，精确保留 Java UTF-16 code unit 与重复属性身份；
- XML：`xml.1.0-safe@1`，namespace-aware 无损 Document（UTF-8/UTF-16 显式 source contract、bounded safe DOCTYPE、六维实体膨胀限制）、恢复与诊断、native/syntax query、三种 projection、canonical materialization 与 8 个版本化编辑操作；
- Property List：`plist.xml@1`、`plist.binary@1`，共享原生值模型与不相交语法系统、双表示 round-trip 转换（representation change 报告）、native/syntax/binary query、projection、canonical materialization 与 6 个版本化编辑操作；
- HCL family：`hcl.native@1`、`hcl.tfvars@1`，body/expression/template 原生模型（AST 与精确 span 双保留）、native/syntax 双查询域、`hcl.body@1` 投影与 `hcl.expression@1` ExtendedValue、canonical materialization 与 6 个（tfvars 4 个）版本化编辑操作；
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
- JSON 8 个、TOML 7 个、YAML 8 个、INI 8 个、Properties 5 个、XML 8 个、plist 6 个及 HCL 6 个（tfvars 4 个）版本化编辑操作；格式间相同抽象操作不共享 trivia、delimiter、duplicate 或 encoding 规则；
- snapshot-bound 原子事务、dry-run `EditPlan`、`UntouchedByteProof` 与可重放 `SourcePatch`；
- semantic-model v6 发布 38 条 contract registry 记录与 166 个公共 error code，同时精确冻结 v1/v2/v3/v4/v5；
- semantic-model v7 在 v6 之上追加 `core.cli-output@1`、`core.batch-plan@1`、`core.batch-result@1` 三个 CLI 稳定 payload 与 20 个 `cli.*` error code，0.13.0 另注册 `json.projection.incomplete-document@1`（41 条 contract / 187 个 code），v1-v6 精确冻结；
- 18 套语言无关 conformance suite 共 508/508 cases，其中 semantic-model v6 为 25/25、INI family 为 20/20、Java Properties 为 22/22、XML 为 34/34、plist 为 45/45、HCL 为 57/57、CLI 为 40/40；
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
- XML 1.0 safe Profile：[RFC 0012](docs/rfcs/0012-xml-1.0-safe-profile-v1.md)
- plist family Profiles：[RFC 0013](docs/rfcs/0013-plist-family-profiles-v1.md)
- HCL family Profiles：[RFC 0014](docs/rfcs/0014-hcl-family-profiles-v1.md)
- CLI machine protocol 与 batch apply：[RFC 0015](docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md)
- CLI 任务配方（每命令真实输出与请求文件）：[Cookbook](docs/cookbook.md)
- 0.8.0 时代 API → 0.12.0 facade + CLI：[迁移指南](docs/migration-guide.md)
- JSON family 0.6.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.6.0.md)
- YAML 0.7.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.7.0.md)
- INI/Properties 0.8.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.8.0.md)
- XML 0.9.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.9.0.md)
- plist 0.10.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.10.0.md)
- HCL 0.11.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.11.0.md)
- consema CLI 0.12.0 性能基线：[Benchmark baseline](docs/BENCHMARKS-0.12.0.md)
- 0.8.0 迁移、安全、制品边界与发布记录：[Release record](docs/RELEASE-0.8.0.md)
- 0.7.0 迁移、安全与发布记录：[Release record](docs/RELEASE-0.7.0.md)
- JSON5 v2.2.3 上游参考门禁：[Reference corpus provenance](docs/UPSTREAM-JSON5-REFERENCE.md)
- 上游 TOML 门禁：[Official TOML 1.0 compatibility gate](docs/UPSTREAM-TOML-TEST.md)
- 上游 YAML 门禁：[Official YAML test-suite acceptance gate](docs/UPSTREAM-YAML-TEST-SUITE.md)
- 版本变更记录：[CHANGELOG](CHANGELOG.md)

`1.0.0` 的目标不是最小闭环，而是覆盖 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个格式家族，并由 Rust、Go、TypeScript、Python、Kotlin 五个独立实现共同证明（2026-08-11 用户决策：五语言同等地位，见 `docs/multi-language-implementation-plan.md` 与 `docs/five-language-ci-design.md`）。Go SDK（go/，0.14.0 里程碑 G0.1-G0.3：core/graph/protocol）按 2026-08-07 决策记录在 Rust Feature-Complete Gate 关闭前启动（偏差经记录，见 fc-manifest decision record）；其余 Go 里程碑（0.15.0-0.19.0）按 docs/go-implementation-plan.md 顺序推进。

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
- `consema-xml`：XML 1.0 safe 无损文档、namespace 原生语义、查询、投影、materialization 与原子编辑；
- `consema-plist`：XML/binary 双表示无损文档、共享原生值模型、查询、投影、materialization 与原子编辑；
- `consema-hcl`：native/tfvars 无损文档、body/expression 原生语义、查询、投影、materialization 与原子编辑；
- `consema-protocol`：语言无关固定 schema、公共注册表、canonical JSON/PVCE transport 与严格 payload validation；
- `consema-conformance`：仓库内、不可发布的语言无关向量 runner、上游语料、固定 runtime oracle、真实配置夹具、硬化与基准工具；
- `consema`：公共 facade，导出 `core/document/graph/hcl/ini/json/plist/properties/toml/xml/yaml/protocol/pvce`；0.12.0 起内嵌正式 `consema` CLI（11 个命令，只消费 facade public API，零新外部依赖）。

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

## XML 示例

```rust
use consema::document::{
    MaterializationRequest, MaterializationResult, MaterializationStyleId, ProfileId,
};
use consema::xml::{
    ContentPlacement, EditTransactionBuilder, NameFacts, ProjectionRequest, ProjectionResult,
    XmlEncodingSelection, XmlParseLimits, XmlProfile, materialize, parse,
};

let source = br#"<service xmlns:cfg="urn:cfg" cfg:port="8080"><name>catalog</name></service>"#;
let document = parse(
    source.as_slice(),
    XmlProfile::SafeV1,
    XmlEncodingSelection::ProfileDefault,
    XmlParseLimits::default(),
)
.expect("well-formed namespaced XML");
assert_eq!(document.render(), source);

let ProjectionResult::Complete(projected) = document.project(ProjectionRequest::element_tree())
else {
    panic!("exact projection");
};
let MaterializationResult::Complete(converted) = materialize(
    &projected.value,
    &MaterializationRequest::new(
        ProfileId::new("xml.1.0-safe", 1),
        MaterializationStyleId::new("xml.safe-canonical-document", 1),
    ),
) else {
    panic!("canonical materialization");
};
assert_eq!(
    converted.document.render(),
    br#"<service xmlns:cfg="urn:cfg" cfg:port="8080"><name>catalog</name></service>
"#
    .as_slice(),
);

let mut transaction = EditTransactionBuilder::new(&document);
transaction.insert_element(
    document.root().expect("root").node_ref(),
    NameFacts::new(None, "replica".to_owned(), None),
    Some("backup".to_owned()),
    ContentPlacement::End,
);
let commit = document.commit(&transaction.build()).expect("commit");
assert_eq!(
    commit.document.render(),
    br#"<service xmlns:cfg="urn:cfg" cfg:port="8080"><name>catalog</name><replica>backup</replica></service>"#
        .as_slice(),
);
```

XML Profile 必须在 formation 前由调用方选择；扩展名不授权 DTD 校验、schema 或 application mapping。canonical materialization 生成新文档（含尾换行），结构编辑只替换操作自有 span 内文本并保留未触及字节。

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

## CLI 工作流示例（0.12.0）

正式 `consema` CLI 内置于 facade crate（11 个命令：inspect/capabilities/query/project/materialize/convert/edit/plan/apply/conformance/explain）。跨格式转换是"投影 + 物化"两阶段的显式组合：先检查源文件事实，再按显式 Profile 与两阶段请求转换。

```text
$ consema inspect package.json
consema inspect package.json
  bytes: 424 bytes sha256:06d760863d6c0c66e119747d74a116c12a365315cb423ce3108f4f2b10089a13
  bom: none
  symlink: no
  markers: first non-whitespace '{'
  candidates: json.strict@1 (first non-whitespace byte is '{'); json5.standard@1 (first non-whitespace byte is '{'); jsonc.bounded@1 (first non-whitespace byte is '{')
  ambiguous: yes: first non-whitespace '{' is consistent with multiple profiles of the json family
```

```text
$ consema convert package.json --profile json.strict --request-file convert-request.json
"name" = "consema-fixture-app"
"version" = "1.0.0"
"private" = true
"type" = "module"
"scripts" = { "build" = "tsc -p tsconfig.json", "check" = "tsc --noEmit", "test" = "node --test" }
"engines" = { "node" = ">=20" }
"dependencies" = { "fastify" = "4.28.1" }
"devDependencies" = { "typescript" = "5.6.3" }
"tooling" = { "coverage" = true, "thresholds" = [90, 85, 80] }
```

`convert-request.json` 是 RFC 0015 §3.2 的严格 canonical tagged JSON
（`cli.convert-request@1`：`json.projection.best-exact-core@1` →
`toml.1.0`/`toml.canonical-document`，映射政策
`UniqueStringEntriesToObject`，ExactOnly）：

```json
{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.convert-request@1"}},{"key":"projection_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.projection-request@1"}},{"key":"target","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"json.projection.best-exact-core"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"default_policy","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"core.projection.exact-or-reject"}},{"key":"version","value":{"type":"Integer","value":"1"}},{"key":"arguments","value":{"type":"Object","entries":[]}}]}},{"key":"rules","value":{"type":"Sequence","items":[]}},{"key":"limits","value":{"type":"Object","entries":[]}}]}},{"key":"materialization_request","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.materialization-request@2"}},{"key":"target_profile","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.1.0"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"style","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"toml.canonical-document"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"encoding","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"core.source-encoding@1"}},{"key":"kind","value":{"type":"String","value":"Utf8"}},{"key":"windows_code_page","value":{"type":"Null"}}]}},{"key":"newline","value":{"type":"String","value":"Lf"}},{"key":"mapping_policy","value":{"type":"String","value":"UniqueStringEntriesToObject"}},{"key":"representability","value":{"type":"String","value":"ExactOnly"}},{"key":"limits","value":{"type":"Object","entries":[{"key":"max_input_nodes","value":{"type":"Integer","value":"1000000"}},{"key":"max_output_bytes","value":{"type":"Integer","value":"67108864"}},{"key":"max_depth","value":{"type":"Integer","value":"256"}},{"key":"max_report_entries","value":{"type":"Integer","value":"100000"}},{"key":"max_provenance_entries","value":{"type":"Integer","value":"2000000"}}]}}]}}]}}
```

请求文件不能带尾随换行（canonical 字节形式严格判定）。CLI 默认不写
文件：目标字节在 stdout，`--output <path>` 显式落盘；机器模式 `--json`
时 stdout 只有一行 `core.cli-output@1` 信封。批量修改（plan/apply）、
secret 脱敏、每格式能力矩阵与 loss policy 真实示例见
[docs/cookbook.md](docs/cookbook.md)。

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
cargo run --locked --offline --release -p consema-conformance --example xml_baseline -- 5000
cargo run --locked --offline --release -p consema-conformance --example plist_baseline -- 5000
cargo run --locked --offline --release -p consema-conformance --example hcl_baseline -- 5000
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

当前未实现 semantic diff/merge、formatter、跨对象 member move/通用 table move、文件系统写入事务。Go SDK 按 2026-08-07 决策记录在 go/ 启动（0.14.0 里程碑 G0.1-G0.3：core/graph/protocol）。TypeScript/Python/Kotlin 按 2026-08-11 用户决策加入（与 Rust/Go 同等地位），L0-L5 全闭环，各 conformance 508/508（18 套 / digest 35bebc8d 共钉）。JSON family/TOML Profile 仍按各自入口接受 UTF-8；YAML、INI、Properties 与 XML 各自使用已冻结的显式 source/encoding contract；HCL 恒为 UTF-8。后续能力按路线图逐阶段落地，不以 README 声明代替完成证据。
