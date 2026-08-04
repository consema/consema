# Consema

Consema 是《配置内容统一处理标准与 Rust 参考实现》的 Rust `0.2.0` 落地。

它将无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑分离；默认拒绝未经授权的转换、截断或信息损失。

## 当前实现

- JSON：`json.strict@1`、`jsonc.bounded@1`；
- TOML：`toml.1.0@1`；
- PortableValue 全部 15 类核心值与 strict equality/hash；
- PVCE/1 canonical encode 与 strict bounded decode；
- snapshot-bound `NodeRef`/`Span`、exhaustive lossless source coverage；
- versioned typed query、完整 projection/report/provenance、原子 scalar edit/ChangeSet；
- 20 个 core/JSON 与 18 个 TOML 语言无关 conformance cases；
- 官方 `toml-test v2.2.0` TOML 1.0 decoder gate：205 valid + 474 invalid 全部通过。

TOML table、inline table、array-of-tables、dotted key 和 array 拥有各自原生身份，不复用 JSON object/member 类型。`.env` 不属于当前格式 Profile；它在产品路线中是 source adapter。

## Roadmap

- 现有语义基线：[配置内容统一处理标准与 Rust 参考实现.md](配置内容统一处理标准与%20Rust%20参考实现.md)
- 完整生产级 `1.0.0` 路线：[Consema 1.0.0 产品路线图与双语言落地设计.md](Consema%201.0.0%20产品路线图与双语言落地设计.md)
- TOML 0.2 契约：[RFC 0001](docs/rfcs/0001-toml-1.0-profile.md)
- 上游 TOML 门禁：[Official TOML 1.0 compatibility gate](docs/UPSTREAM-TOML-TEST.md)
- 版本变更记录：[CHANGELOG](CHANGELOG.md)

`1.0.0` 的目标不是最小闭环，而是覆盖 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个格式家族，并由 Rust、Go 两个独立实现共同证明。Go 只在 Rust Feature-Complete Gate 全部通过后开始。

## Workspace

- `consema-core`：PortableValue、诊断、Capability 和类型化查询协议；
- `consema-pvce`：PVCE/1 规范编码与严格解码；
- `consema-document`：不可变 source snapshot、Span、NodeRef 和 ChangeSet 公共事实；
- `consema-json`：JSON/JSONC 无损文档、原生语义、查询、投影与标量编辑；
- `consema-toml`：TOML 1.0 无损文档、原生 item、查询、投影与标量编辑；
- `consema-conformance`：语言无关向量 runner、硬化语料和官方 TOML adapter；
- `consema`：公共 facade，导出 `core/document/json/toml/pvce`。

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

当前未实现 YAML、INI、XML、Properties、plist、HCL、结构编辑、materialization 和 Go；这些能力按路线图逐阶段落地，不以 README 声明代替完成证据。
