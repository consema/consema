# Changelog

Consema 遵循 Semantic Versioning。尚未完成的路线项目不记为已发布能力。

## 0.2.0 — 2026-08-04

### Added

- 冻结 `toml.1.0@1` 原生语义契约与 RFC 0001；
- 新增无损 TOML document、table/inline table/array-of-tables/dotted-key/array 身份；
- 新增 TOML 类型化查询、到 PortableValue 的精确投影和完整 provenance；
- 新增只修改目标标量 span 的原子 literal/semantic edit；
- 新增 18 个语言无关 TOML conformance cases、真实配置 fixtures 与硬化语料；
- 新增仅使用 Consema 公共 API 的官方 `toml-test` decoder adapter；
- 新增 facade 的 `toml` 导出与 Rust `0.2.0` 统一版本面；
- 新增 `deny.toml` 可执行依赖来源、许可证、重复版本和公告政策。

### Verified

- 仓库测试共 45 项通过；
- `toml-test v2.2.0`：205 valid、474 invalid TOML 1.0 decoder cases 全部通过；
- fmt、strict Clippy、rustdoc warnings、RustSec audit 与 cargo-deny 门禁通过。

### Boundaries

- 非法 TOML 不形成伪恢复文档；
- 当前编辑面仅覆盖 TOML 标量，不包含结构编辑或 materialization；
- YAML、INI、XML、Properties、plist、HCL 与 Go 尚未作为已实现能力发布。

## 0.1.0 — 2026-08-03

### Added

- 建立 PortableValue、PVCE/1、不可变文档事实、诊断、能力与类型化查询基础；
- 发布 `json.strict@1` 与 `jsonc.bounded@1` 的无损文档、查询、精确投影和标量编辑；
- 建立语言无关 conformance runner、硬化语料与 Rust workspace 发布门禁。
