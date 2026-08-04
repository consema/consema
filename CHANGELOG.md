# Changelog

Consema 遵循 Semantic Versioning。尚未完成的路线项目不记为已发布能力。

## 0.4.0 — 2026-08-04

### Added

- 接受 RFC 0003，新增 exact raw-byte `SourceSnapshot`、SHA-256 content digest 与独立 process-local snapshot identity；
- 新增 Binary、UTF-8、UTF-16LE、UTF-16BE、ISO-8859-1 encoding resolution facts，以及不取整的 raw/UTF-8/scalar/UTF-16 decoded locations；
- 新增 BinaryStructuralIndex 与 format-owned binary regions 的无空洞、无重叠覆盖验证；
- 新增 `json.lossless-syntax-query@1` 与 `toml.lossless-syntax-query@1`，以及 Completed/Cancelled/Failed ordered cursor terminal；
- 新增可验证、原子应用的 raw-byte `SourcePatch` 与 redacted review presentation；
- 新增 `core.semantic-model@2`、`ContractRegistry::v2()`、`ErrorCodeRegistry::v2()`、`core.source-snapshot@1` 与 `core.source-patch@1`，同时保持 v1 精确冻结；
- 新增 28 个 source、19 个 shared syntax-query 与 11 个 protocol v2 语言无关 conformance cases。

### Correctness

- digest 对包含 BOM 在内的完整原始字节计算，不混入 encoding、Profile 或 metadata；
- encoding 冲突、非法 UTF 序列、unsupported UTF-32 BOM 与 decoded size/coordinate overflow 均显式失败；
- Syntax Query kind/text、source order、selection、limit 与 cancellation 在 JSON/TOML 间共享语义但不共享格式 kind 类型；
- SourcePatch 在分配前验证 count/bytes/output bounds，并在 stale digest、original mismatch、encoding drift、overlap 或 target mismatch 时不产生新 snapshot；
- lazy query cursor 对 branch clone、merge aggregation 与巨大容器 expansion 施加分配前/分配中上限。

### Verified

- workspace `--all-targets --all-features` 共 141 个 Rust tests 通过，fmt、strict Clippy、doctest 与 `-D warnings` rustdoc 通过；
- 20 个 core/JSON、18 个 TOML、32 个 protocol v1、28 个 source、19 个 syntax-query 与 11 个 protocol v2 cases 全部通过，共 128 个语言无关案例；
- SourceSnapshot/SourcePatch 均通过 semantic-model v2 canonical JSON/PVCE envelope 往返；
- adversarial source decoding、patch offset/count/allocation、协议变异与既有 JSON/TOML/PVCE hardening 语料通过；
- `toml-test v2.2.0`：205 valid、474 invalid TOML 1.0 decoder cases 保持通过；
- RustSec audit 与 cargo-deny advisories/bans/licenses/sources 门禁通过。

### Boundaries

- 公共 source 层支持五种 encoding，不自动扩大现有 JSON/TOML Profile parser 的 UTF-8 准入；
- SourcePatch 是精确 raw-byte transition，不是 ChangeSet、semantic diff、merge、fuzzy patch、结构编辑或文件系统写入；
- YAML、INI、XML、Properties、plist、HCL、Schema、materialization 与 Go 尚未作为已实现能力发布。

## 0.3.0 — 2026-08-04

### Added

- 冻结 RFC 0002 与 `core.semantic-model@1` 跨格式语义模型身份；
- 新增 `core.protocol-message@1` envelope、15 个稳定 payload contract 和 55 个公共 error code；
- 新增 Profile、Capability、Diagnostic、Query、Projection、Provenance、ChangeSet、Execution、Cancellation、Completion 与 registry 的固定字段协议；
- 新增覆盖 PortableValue 全部 15 类值的 canonical tagged JSON transport，并保持 PVCE/1 字节契约不变；
- 新增全量 typed payload validation，未知 contract/field、非规范 encoding、注册表矛盾和 process-local handle 均显式拒绝；
- 新增 32 个语言无关 protocol conformance cases，其中注册表精确覆盖全部 15 个稳定 payload 的 JSON/PVCE 双传输；
- 新增协议恶意输入、逐字节变异、截断、深度与 payload bypass 硬化语料；
- 新增 facade 的 `protocol` 导出与 Rust `0.3.0` 统一版本面。

### Correctness

- 使用 present-value wrapper 区分成功的 PortableValue `Null` 与 absent ProjectionResult value；
- Completion failure、Diagnostic 与 ProjectionReport event code 统一绑定 ErrorCodeRegistry，Diagnostic category 必须与注册表一致；
- `NodeRef`、snapshot handle、cursor 与 `CancellationToken` 明确定义为 process-local，wire adapter 缺少稳定 locator 时失败。

### Verified

- workspace 全 target 测试共 78 项通过；
- 20 个 core/JSON、18 个 TOML 与 32 个 protocol 语言无关 cases 全部通过；
- 15 个稳定 payload 均通过 canonical JSON/PVCE envelope 往返；
- `toml-test v2.2.0`：205 valid、474 invalid TOML 1.0 decoder cases 全部通过；
- fmt、strict Clippy、rustdoc warnings、RustSec audit 与 cargo-deny 门禁通过。

### Boundaries

- `core.semantic-model@1` 是 compatibility identity，不是可嵌套 payload；`core.protocol-message@1` 是 transport envelope，不允许作为自身 payload；
- 0.3.0 仍只接受 UTF-8 source，不提供 raw multi-encoding SourceSnapshot；
- YAML、INI、XML、Properties、plist、HCL、结构编辑、materialization 与 Go 尚未作为已实现能力发布。

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
