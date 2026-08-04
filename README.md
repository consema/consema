# Consema

Consema 是《配置内容统一处理标准与 Rust 参考实现》的 Rust `0.1.0` 落地。

它将无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑分离，默认拒绝未经授权的转换或信息损失。

## Roadmap

- `0.1.0` 语义和实现基线：《配置内容统一处理标准与 Rust 参考实现.md》
- 完整生产级 `1.0.0` 路线：《Consema 1.0.0 产品路线图与双语言落地设计.md》

`1.0.0` 的目标是完成 JSON、YAML、TOML、INI、XML、Properties、Property List 与 HCL 八个格式家族，以及 Rust、Go 两个独立实现；Go 只在 Rust Feature-Complete Gate 全部通过后开始。

## Workspace

- `consema-core`：PortableValue、诊断、Capability 和类型化查询协议。
- `consema-pvce`：完整 PVCE/1 规范编码与严格解码。
- `consema-document`：不可变源快照、Span、NodeRef 与文档公共事实。
- `consema-json`：`json.strict@1` / `jsonc.bounded@1` 的无损文档、原生语义、查询、投影与标量编辑。
- `consema-conformance`：语言无关 JSON 测试向量运行器与向量。
- `consema`：公共 facade。

实现范围和语义权威以仓库根目录的《配置内容统一处理标准与 Rust 参考实现.md》为准；规范未冻结的具体 wire 常量和 operator registry 在各 crate 的版本化模块文档中固定。

## 验证

```text
cargo fmt --all --check
cargo test --workspace --all-targets
cargo clippy --workspace --all-targets -- -D warnings
```
