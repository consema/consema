# Changelog

Consema 遵循 Semantic Versioning。尚未完成的路线项目不记为已发布能力。

## 0.8.0 — 2026-08-05

### Added

- 实现 RFC 0009，发布 `ini.portable@1`、`ini.windows@1` 与 `ini.python-configparser@1` 三个显式 Profile；覆盖 raw source/encoding、physical/logical line、section/entry identity、native/syntax query、EntryMapping 优先投影、三种 canonical materialization 与 8 个版本化编辑操作；
- 实现 RFC 0010，发布 `java-properties.reader@1` 与 `java-properties.latin1@1`；覆盖 natural/logical line、separator/continuation/escape、重复 property identity、精确 Java UTF-16 code unit、query、projection、canonical materialization 与 5 个版本化编辑操作；
- 实现 RFC 0011，发布 `core.semantic-model@6`：38 条 contract registry 记录与 166 个稳定 error code；新增 source encoding/snapshot/patch v2、materialization request/result v2、Java UTF-16 string 与外部定位的 INI/Properties query result，并精确冻结 v1-v5；
- 新增 `consema-ini`、`consema-properties` 公共 crate 与 facade 导出；新增 77 个语言无关案例，使 14 套 suite 达到 332/332；
- 固定 OpenJDK、CPython、.NET、Windows wide profile API 与 Qt 五套 runtime oracle 共 36 个差分案例，并加入真实 INI/Properties 工程夹具、adversarial corpus、可复现性能基线及最终 `.crate` 解包验证门禁。

### Correctness

- INI Profile 必须由调用方在 formation 前选择；不按扩展名或“哪个 parser 成功”猜方言，也不隐式执行 interpolation、provider precedence、environment/default lookup、registry redirect 或 typed getter；
- section、entry 与 duplicate occurrence 保持 source order 和独立身份；case、delimiter、comment、quote、continuation、empty/missing 与 collision policy 由所选 Profile 决定，不能用一个宽松 `ini@1` 抹平；
- Properties Document 不以 JDK `Hashtable` 为真相，不覆盖重复 key，也不执行 defaults chain；Reader encoding 由调用方显式给定，Latin-1 将 marker-shaped BOM bytes 视为内容，`\uXXXX` 产生的未配对 surrogate 以 exact `JavaString` 保留；
- Windows code page 使用冻结的数字 registry 和 strict decoding；BOM 的 `DetectUnicode | TreatAsContent` policy、raw/decoded boundary 与 digest 均进入 snapshot/patch 前置条件，transcoding 不伪装为 in-place patch；
- INI/Properties projection、materialization 与 edit 对 recovered/ambiguous/unrepresentable/resource-limit 输入原子失败；成功 materialization 重 parse 目标 bytes，成功 edit 产生一致 dry-run/commit plan、完整 untouched-byte proof 与可重放 SourcePatch。

### Verified

- Rust 1.97 与声明的 MSRV Rust 1.85 均通过 workspace `--all-targets --all-features` 的 452 项 tests 与 strict Clippy；当前工具链另通过 rustfmt、doctest 与 rustdoc `-D warnings`；
- 14 套语言无关 suite 共 332/332 cases 通过，其中 semantic-model v6 为 25/25、INI family 为 20/20、Java Properties 为 22/22；
- 五套固定 runtime oracle 共 36/36：OpenJDK 25.0.4 为 11/11、CPython 3.14.6 为 9/9、.NET 10.0.10 为 7/7、Windows wide API 为 5/5、Qt 6.10.2 为 4/4；
- `toml-test v2.2.0` 的 205/205 valid 与 474/474 invalid、YAML test-suite 的 307/307 valid、94/94 invalid 与 1/1 Profile exclusion，以及 JSON5 v2.2.3 的 83/83 外部门禁保持通过；
- RustSec 使用本地 1,189 条 advisory 数据扫描 Cargo.lock 的 38 个 crate dependencies，无已知漏洞；cargo-deny advisories、bans、licenses、sources 四类门禁通过；
- 11 个可发布 `.crate` 完成路径安全、内部 checksum/归档 SHA-256 一致性检查，并在 Rust 1.97 与 1.85 下从解包内容通过全 target/全 feature 编译；repository-only 的 `consema-conformance` 明确设为不可发布；
- 固定 INI 与 Properties 工程夹具上发布 parse、native query、exact projection、canonical materialization 与 semantic edit 的 3-sample/20,000-iteration release baseline；辅助 llvm-cov 报告为 region 84.65%、function 82.73%、line 86.59%。

### Boundaries

- INI Profile 只定义确定的文件内容语义，不模拟 Windows registry redirect/cache、.NET provider layering、Python interpolation/multi-file precedence 或 Qt fallback scope；
- Properties line profiles 不包含 XML Properties、ResourceBundle、classpath、defaults chain、`store()` timestamp/comment 行或宿主 Charset 猜测；
- 本版本不提供 XML、plist、HCL、Schema、semantic diff/merge、通用 formatter、增量解析、Live Query、文件系统事务、稳定插件进程协议或 Go 实现；`.env` 仍是后续 source adapter，而不是第九种配置格式 Profile。

## 0.7.0 — 2026-08-04

### Added

- 实现 RFC 0006，发布独立 PortableGraph@1、strict graph equality/hash、canonical PGCE/1 与 `core.portable-graph-query@1`；保留多 root、tag、任意/重复 mapping key、sharing 与 cycle；
- 实现 RFC 0007，发布 `yaml.1.2-core@1` 与 `yaml.1.1-compat@1`：UTF-8/UTF-16 stream、multi-document、完整 lossless/native view、tag/anchor/alias 图语义、native/syntax query、graph/value projection、block/flow materialization 与 8 个 YAML 编辑操作；
- JSON↔YAML audited conversion 通过显式 PortableValue projection/materialization 组合，YAML sharing、cycle、tag 与 mapping policy 保持可观察；
- 实现 RFC 0008，发布 `core.semantic-model@5`：30 条 contract、132 个稳定 error code，以及 PortableGraph、graph query/provenance/projection 和外部化 YAML query payload；v1-v4 精确冻结；
- 新增 10 个 PortableGraph、22 个 semantic-model v5 与 27 个 YAML language-neutral cases，使 11 套 suite 合计达到 255/255；
- 固定官方 `yaml/yaml-test-suite data-2022-01-17` 完整 402-case gate，新增 Kubernetes、GitHub Actions、Compose、anchor-heavy 四类工程夹具、YAML/PGCE adversarial corpus 与可复现性能基线。

### Correctness

- PortableValue 未因 YAML 增加引用或 graph 类型；YAML graph 默认进入 PortableGraph，tree projection 对 cycle 永远失败，对 sharing/custom tag 只有显式 policy 才允许转换；
- custom tag 不执行语言构造器、merge、include、import、网络或文件访问；alias 不隐式展开，放大、depth、node、edge、provenance、report 和 output 全部有界；
- YAML 1.1 与 1.2 boolean/octal/sexagesimal/timestamp 差异完全由 Profile 决定，未来/冲突 version directive 不猜测；
- graph equality、canonical numbering、query order、PGCE bytes 与 protocol dual transport 均确定；strict decoder 拒绝非规范编号、varint、trailing data 与 readable/PGCE 不一致；
- YAML graph/value materialization 都重 parse 并验证 promised input；edit 保留 style/trivia/encoding，anchor rename 更新依赖 alias，删除 live anchor 与不可见 alias insertion 原子失败；
- 官方 suite 与 anchor-heavy fixture 分别发现并锁定两项 lossless scanner 缺陷：多行 plain scalar 中的 `&`/`!` 不再伪造 node property，更深层 mapping 行也不再被上一 plain scalar 吞并。

### Verified

- Rust 1.97 与声明的 MSRV Rust 1.85 均通过 workspace `--all-targets --all-features` 的 312 项 tests 与 strict Clippy；当前工具链另通过 rustfmt、doctest 与 rustdoc `-D warnings`；
- 11 套语言无关 suite 共 255/255 cases 通过；PortableGraph 10/10、semantic-model v5 22/22、YAML family 27/27；
- YAML 官方 gate 完整核算 402 项：307/307 valid byte-exact、94/94 invalid atomic rejection、1/1 明确 Profile exclusion；四类 YAML 工程夹具均完成 source/graph/PGCE/materialization closure；
- `toml-test v2.2.0` 的 205/205 valid 与 474/474 invalid，以及 JSON5 v2.2.3 的 83/83 外部门禁保持通过；
- RustSec 使用本地 1,189 条 advisory 数据扫描 Cargo.lock 的 35 个 crate dependencies，无已知漏洞；cargo-deny advisories、bans、licenses、sources 四类门禁通过；
- 固定 anchor-heavy YAML 夹具上发布 parse、syntax query、graph/value projection、PGCE、graph materialization 与 anchor edit 的 3-sample/20,000-iteration release baseline，并记录环境、input digest 与完整样本离散度。

### Boundaries

- canonical YAML materialization 创建新文档，不是既有 YAML formatter；不提供 implicit merge、custom constructor、cross-document anchor、graph diff/merge 或 cross-container move；
- graph wire payload 只传输 PortableGraph 与已外部定位的结果；raw YAML `Document`、`NodeRef`、native handle、syntax piece 与 cursor 仍是 process-local；
- 本版本不提供 INI、Properties、XML、plist、HCL、Schema、semantic diff/merge、通用 formatter、增量解析、Live Query、文件系统事务、稳定插件进程协议或 Go 实现。

## 0.6.0 — 2026-08-04

### Added

- 实现 RFC 0005，发布完整 `json5.standard@1` Profile：Standard JSON5 形成、无损 Document、精确 native view、Unicode IdentifierName、扩展字符串/数字、comment 与 trailing comma；
- 新增 `json.native-semantic-query@2`、`json.lossless-syntax-query@2` 与 Profile-bound `json5.projection.best-exact-core@1`，保持 v1 domain 的严格 JSON/JSONC 语义不变；
- 新增 `json5.canonical-compact@1`、`json5.canonical-pretty@1` 与 JSON5↔strict JSON/JSONC audited conversion；
- JSON5 scalar/association/array edit 保持合法原表示；新增 `json.edit.move-member@1`，JSON family operation registry 增至 8 项，TOML 保持 7 项；
- 发布 `core.semantic-model@4`：25 条 contract registry 记录与 92 个公共 error code；v1/v2/v3 registry 精确冻结；
- 新增 `consema.json-family.conformance@2` 的 33 个语言无关案例、固定 JSON5 v2.2.3 上游 gate、4 份典型项目配置、12 项 hardening/property tests 与可重现性能基线。

### Correctness

- 所有有限 JSON5 数字映射为任意精度 Integer/Decimal；只有 `±Infinity` 与 `±NaN` 映射到四种冻结 BinaryFloat64 位模式，strict JSON 不可表示时原子失败；
- JSON5 IdentifierStart/Continue 固定到 `unicode-id-start 1.4.0`，不随宿主 Unicode 表漂移；parser 不求值 JavaScript，也不访问文件或网络；
- query domain、projection target 与 materialization style 均绑定 Profile；跨 Profile 误用显式失败，不静默收窄语义；
- JSON5 edit 保持 quote、escape、key、comment、comma 与 trivia 所有权；member move 仅允许同一 Object，并保持 dry-run/commit patch 一致；
- 上游无效语料发现的 escaped identifier continuation panic 已修复为正常拒绝，并加入专门回归；失败 parse/conversion/edit 均不产生 partial success。

### Verified

- Rust 1.97 与声明的 MSRV Rust 1.85 均通过 workspace `--all-targets --all-features` 的 208 项 tests 与 strict Clippy；当前工具链另通过 rustfmt、doctest 与 rustdoc `-D warnings`；
- 8 套语言无关 suite 共 196/196 cases 通过，其中 JSON family v2 为 33/33；
- JSON5 v2.2.3 外部门禁 43/43 valid、39/39 invalid 与 1/1 完整配置夹具通过，共 83/83；4 份典型 JSON/JSONC/JSON5 项目配置与 12 项 adversarial/property tests 通过；
- `toml-test v2.2.0` 的 205/205 valid 与 474/474 invalid cases 保持通过；
- RustSec 扫描 Cargo.lock 的 25 个 crate dependencies 无已知漏洞；cargo-deny advisories、bans、licenses、sources 四类门禁通过；
- 固定 JSON5 夹具上发布 parse、syntax query、projection、materialization 与 edit 的 3-sample/20,000-iteration release baseline，并完整记录环境、输入 digest 与样本离散度。

### Boundaries

- canonical JSON5 生成是新文档 materialization，不是现有源文件 formatter；JSON5 支持不包含 JavaScript evaluation、import、computed key、method、regex、template literal、`undefined` 或 bigint；
- member move 限于同一 JSON Object；本版本不提供跨对象 move、通用 reorder、TOML table move、文件系统写入或稳定进程插件协议；
- 本版本不提供 YAML、INI、Properties、XML、plist、HCL、Schema、semantic diff/merge、PortableGraph、增量解析、Live Query 或 Go 实现。

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
