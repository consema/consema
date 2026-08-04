# Changelog

Consema 遵循 Semantic Versioning。尚未完成的路线项目不记为已发布能力。

## 0.5.0 — 2026-08-04

### Added

- 实现 RFC 0004，新增公共 `MaterializationRequest/Result`、fidelity、report、provenance 与 input/output/depth/report/provenance resource limits；
- 新增 `json.canonical-compact@1`、`json.canonical-pretty@1` 与 `toml.canonical-document@1`，完整区分 exact、显式 transformed 和 unrepresentable failure；
- 新增由 Projection 与 Materialization 组合的 JSON↔TOML conversion，保留中间 PortableValue、两阶段 provenance/report 和 overall fidelity；
- 新增 JSON/TOML format operation registry，各发布 7 个版本化 scalar/structural operation；
- 新增 JSON member/array element 与 TOML entry/array element 的 insert/remove/rename 原子事务；
- 新增 deterministic dry-run `EditPlan`、`UntouchedByteProof` 以及从成功 commit 派生的可重放 `SourcePatch`；
- 新增 `core.semantic-model@3`：25 条 contract registry 记录、90 个公共 error code，以及 conversion report、edit plan、operation registry 和 4 个 materialization payload；
- 新增 `consema.operations.conformance@1` 的 35 个语言无关案例。

### Correctness

- Materialization 的 style、newline、encoding、mapping 与 representability policy 全部显式；任何失败不携带 Document 或 partial output；
- TOML 全部 scalar/temporal/container 类别可 canonical round-trip；EntryMapping 只有在 unique String key 且调用方授权时才转换为 Object，并报告 `Transformed`；
- JSON duplicate member identity、JSONC comment/trailing-comma ownership、TOML table/inline-table ownership和 direct-key duplicate constraint 在结构编辑中保留；
- wrong snapshot/role、duplicate target/key、overlap、ancestor-descendant、removed anchor、unrepresentable value、resource limit 与 reparse failure 均在发布新文档前原子失败；
- dry-run 与 commit 的 replacement set/target digest 相同；SourcePatch 重放精确复现 commit bytes；UntouchedByteProof 对 replacement 外全部字节提供可篡改检测的完整覆盖；
- v1 的 16/55 与 v2 的 18/62 contract/error 集合保持冻结；v3 payload 必须通过完整 typed validation，不能凭 schema discriminator 绕过交叉约束；
- 移除 Rust 1.88 let-chain 依赖，恢复清单声明的 Rust 1.85 最低工具链兼容性。

### Verified

- Rust 1.97 下 workspace `--all-targets --all-features` 共 189 个 tests 通过，rustfmt、strict Clippy、doctest 与 rustdoc `-D warnings` 通过；
- Rust 1.85 下同一组 189 个 tests 与 strict Clippy 通过；
- 7 套语言无关 suite 共 163/163 cases 通过，其中 operations v1 为 35/35；
- 10 个 adversarial/property tests 覆盖 materialization、结构事务、proof/patch、v3 mutation/truncation、source/encoding、JSON/TOML/PVCE 与 cancellation；
- `toml-test v2.2.0` 的 205/205 valid 与 474/474 invalid TOML 1.0 decoder cases 通过；
- RustSec 扫描 24 个依赖无已知漏洞；cargo-deny advisories、bans、licenses、sources 四类门禁通过。

### Boundaries

- Materialization 创建新文档，不是既有文档 formatter；conversion 是可审计的两阶段组合，不是 parser-to-writer 捷径；
- EditPlan 与 SourcePatch 都不授权文件系统写入；本版本不提供 discovery、locking、fsync、atomic rename 或 recovery manifest；
- 本版本不提供 JSON5、YAML、INI、Properties、XML、plist、HCL、schema、semantic diff/merge、通用 reorder/table move、PortableGraph、稳定插件进程协议或 Go 实现。

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
