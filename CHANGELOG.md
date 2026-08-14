# Changelog

Consema 遵循 Semantic Versioning。尚未完成的路线项目不记为已发布能力。

## 1.0.0-rc.1 — 2026-08-10

1.0.0 的第一个 release candidate（路线图 §13：0.19.0 → 1.0.0-rc.n → 1.0.0）。workspace 版本推进 0.13.0→1.0.0-rc.1（15 crate `version.workspace = true`，Go CLI `product_version` 同步，Go module 版本随 release train 走 git tag，RFC 0016 §9）；release candidate 只收 blockers/security/docs errors（§12.1）。

### Added

- **RFC 0020（R-20）**：1.0 compatibility/support policy（`docs/rfcs/0020-compatibility-and-support-policy-v1.md`，Status: Accepted）——1.0 兼容承诺（patch/minor/major 语义边界、output order/default loss policy/acceptance-recovery 边界为兼容性、contract @N 永不重释）、支持周期（Rust MSRV、Go 版本窗口、三平台、安全 SLA、EOL/弃用流程）、契约版本治理；与 `docs/support-policy.md`/SECURITY.md/RFC 0015/0016 逐项一致（support-policy §2 的 Go 冻结措辞演进已在 RFC §9.2 调和）；
- **§28 五要素终审记录**（`docs/five-element-review-1.0.0.md`）：哲学统一/语义一致/逻辑自洽/真实有效 **PASS**，完整可靠 **PARTIAL**（C-1 已闭环 2026-08-11、C-2 fuzz 推进中、C-3 开放）；历史 findings 全部关账或标豁免；实测核验 14 项（Go 508/0/0、Rust 1,629 passed、差分 108×2、交换 83/83、parity 68/68、capability parity）；
- **RFC 0015 §3.3 契约修订**：product_version 校验从严格 MAJOR.MINOR.PATCH 扩展为完整 SemVer 2.0 核心语法（接受 `-rc.1`/`-beta.2` prerelease；无 git hash、无 build metadata；cli-v1 向量保持有效）——Rust/Go 两语言校验器同语义扩展 + 双向接受/拒绝测试；
- **聚合 digest 规范态重算**：conformance 向量聚合 sha256 以规范 LF 字节重算（`git show` 规范 blob），新值 `35bebc8d…` 取代 CRLF 工作树记录的 `e3d6578858…`（fc-manifest/go-implementation-plan/conformance_test/脚本全部更新；`git archive` 干净 checkout 全绿复现，含 race）。
- **P2-B 向量补强（2026-08-12，rc 前审计驱动）**：plist-v1.json +4 binary limit 失败 case（`plist.limit.container-depth/object-count/string-code-units/data-bytes@1`，转录 parser_binary.rs limit 矩阵，修复 README「覆盖 limits」声称与零 limit case 的缺口）；yaml-v1.json +4（undefined-anchor block 上下文、version-directive 拒绝 `yaml.profile.version-directive@1`、`max_nesting_depth` → `core.parse.resource-limit@1`、alias 预算零值门 → `yaml.projection.resource-limit@1`）；java-properties-v1.json +3（key 位 malformed unicode escape 家族码、invalid sequence → `core.source.invalid-sequence@1`、BOM conflict → `core.source.encoding-conflict@1`）。18 套 suite 508 → **519 cases**，聚合 digest → `cfd6e296…`；五语言 runner（rs/go/ts/py/kt）全量执行新增 case 零失败（Rust cargo test 全绿、Go/TS/Python/Kotlin runner 519/519），digest/计数硬钉五仓同步。

### Verified（2026-08-10 实测）

- Go：22 包全绿（20 含测试，quickstart/sdk_chain 两示例包无测试；LF 规范态含 race）；runner 508 passed / 0 skipped / 0 failed；capability parity PASS；16 fuzz targets 30s clean-run；差分 108/108 双向；协议交换 83/83；字节 parity 68/68；CLI（`go build ./cmd/consema`）11 命令 + plan→apply 全流程 exit 0-5 矩阵；Go pilot 14 测试（Rust/Go mismatch 0）；升级/回滚演练（D-1/D-2 记录）。
- Rust：`cargo test --workspace --locked` 1,629 passed / 0 failed；consema-protocol 100/100（含新 prerelease 测试）；fmt 干净。
- 发布流程复核：rc-1.0.0-candidate.md 的 §22 逐行核对表（22.2/22.3/22.5/22.7 达成）。

### Boundaries

- **C-1（CI GitHub 真跑）**：**已闭环**——2026-08-11 GitHub Actions run #5（head 437fd35）132/132 steps 全绿，10+1 job 定义（增补前；go-differential 2026-08-12 增补后 ci.yml 为 10+2 job / 12 定义）/ 三 OS 矩阵 17 次执行在 windows/ubuntu/macos 全矩阵通过，2026-08-12 经 GitHub Actions API 在线核实，结果已回填 fc-manifest（C-1 → closed）；五语言 CI 全绿（2026-08-12，ci.yml run#12 + ci-typescript/ci-python/ci-kotlin 各 run#5，head db746ba）将 C-1 证据由双语言扩展到 TS/Python/Kotlin；
- **C-2（72 CPU-hours fuzz）**：账本 122,477 数据行 / 780.529 CPU-hours（2026-08-13 复算，runs.csv 权威；122,478 文件行含表头）；properties 145.4h（201.9%）、yaml 128.8h（178.9%）、ini 124.8h（173.3%）、hcl 95.5h（132.7%）、json 95.3h（132.3%）五单位已过 72h 门槛；其余 toml 57.7h / protocol-decode 50.7h / plist 47.4h / xml 35.0h 继续累计；零新 crash（非零退出 = 40 行：10 行 session-9 外部终止 + 16 行 session-448-wave-3 超时 + 14 行 session-454 拆分停机，均非 fuzz finding；快照口径——追加式账本以 runs.csv 为准），完成路径不变（clang 主机 cargo-fuzz 17 target 为主）；
- **C-3（真实发布密钥与发布执行）**：真实密钥 + 签名 tag/artifact + SBOM/checksum 落盘 + 恢复演练复跑未执行（D-1：checksum manifest 须从干净发布 commit 重新生成；D-2：演练密钥无持久公钥）；
- **RC soak**：§22 中部分权限/磁盘失败演练列为 RC soak 必做（rc-1.0.0-candidate.md §2）；
- 依赖序（终审记录）：F-A → F-B → C-1 → C-2 → C-3 → RC soak → P2-7 → **1.0.0**。

### 落地记录（2026-08-11/2026-08-12 补录：C-1 闭环与五语言时间线）

- **2026-08-12 · a0c318b**：Python 实现 L0-L4 入库（core/graph/protocol/document + 8 格式家族 + root facade + conformance runner）；a0c318b 同时补充 .gitignore 排除 node_modules；
- **2026-08-12 · 5cf680b + cd26af3 勘误**：TS/Python/Kotlin 三语言 L0-L4 实现实际由 5cf680b 携带（commit message 仅标注 fuzz 账本）；每语言 conformance 508/508（18 套 / digest 35bebc8d 共钉）+ capability parity；cd26af3 为勘误归因记录（5cf680b 树计数 533/475/18,467 含构建产物，5a040be purge 后真实 tracked 数 255/243/229，历史事实不变）；
- **2026-08-12 · 2f981df**：L5 差分 harness（TS/Python/Kotlin 跨语言 byte-parity/normalized/protocol-exchange）+ 五语言 CI workflow（ci-typescript/ci-python/ci-kotlin 各 3 job）；差分发现的 wire-codec 缺陷随本 commit 修复（ValuePath schema-less wire 与 AssociationLocation 位置面、materialization-request version:0 拒绝语义、yaml tag/provenance 面）；
- **2026-08-12 · dbba9a4**：五语言 CI 首跑缺陷修复（python 测试夹具路径仓库相对化、kotlin jar 供给 + TestShim.kt 入库）；四 workflow 全绿（ci.yml run#9 + 三语言各 run#2）；
- **2026-08-11 · c6c89bb**：C-1 闭环（GitHub Actions run #5，head 437fd35，132/132 steps 全绿，10+1 job 定义（增补前）/三 OS 矩阵 17 次执行；结果回填 fc-manifest，C-1 → closed）；
- **2026-08-12 · 8d00c4f**：五要素终审 findings 处置（run #5 steps 132/132 在线核实修正、L5 差分 closure 记录、L0-L5 closure 表、Kotlin ChangeSet 注记、快照截止注记）。

## 0.13.0 — 2026-08-07

0.13.0 是 Rust 生产加固与 Feature-Complete Gate 版本（路线图 §14.12/§15，执行计划 `docs/0.13.0-gate-plan.md`）：不新增格式，把 §15 门禁逐条落成可复现证据。全部条目状态与证据见 Feature-Complete Manifest（`docs/fc-manifest-0.13.0.json`）。本版本随 2026-08-07 落地：workspace 版本推进 0.8.0→0.13.0（发布检查单第 1 项）；五维交叉审计（哲学统一/语义一致/逻辑自洽/真实有效/完整可靠）findings 全部处置；Go SDK 0.14.0 G0.1-G0.3 按决策记录 D-1 入库（见本条目「落地记录」与 Boundaries）。门禁开放项 C-1/C-2/C-3 **尚未全部关闭**，Boundaries 如实列出完成路径。

### Added

- 三平台 CI（`.github/workflows/ci.yml`，10 job）：lint/test 各 3 OS × stable、coverage（硬下限 + `-Trend` 趋势门禁）、msrv（1.85.0 全门禁）、conformance（18 套 suite / 508 cases 计数断言）、deny 四段、audit（RustSec）、semver（vs v0.8.0 基线 11 crate）、oracles（文档化 skip=成功）、package（含 MSRV 腿的归档重建门禁）；
- 打包验证脚本加固（`scripts/verify-package-archives.ps1`）：`-AllowDirty` 开关 + 脏树前置条件逐文件报错、`-SkipMsrv` + 默认开启的 MSRV 构建腿（rust-version 读自 cargo metadata）；干净 HEAD 工作树全流程实测 exit 0（14 个 `.crate` + 1.85.0 全 target 构建）；
- coverage 工具链常设化（`scripts/coverage.ps1` + `docs/COVERAGE-0.13.0.md`）：可复现测量（commit 9c1ede2，region 86.51% / function 82.82% / line 87.91%），硬下限（regions≥70/functions≥70/lines≥80）与 `-Trend` 趋势门禁；取代 0.8.0 的单次不可复现 84.65% 记录；
- fuzz/property/mutation 语料（门禁 §15.3）：确定性 in-process 变异引擎（consema-rs 的 `consema-conformance/src/fuzz.rs`，拆分前 `crates/consema-conformance/src/fuzz.rs`）驱动的 17 个长期 target（每格式 parse/operations + protocol decode；consema-rs 的 `consema-*/fuzz/` 下与 cargo-fuzz wrapper 双接线，拆分前 `crates/*/fuzz/`，corpus 种子 47 个文件进 git）；protocol/varint/offset/graph/alias property tests 3 组（property_graph/property_protocol/property_plist）；mutation corpus 46 fixtures × 174,921 cases（`conformance/corpora/mutation-v1.json`，种子提交）与全量 replay 测试；
- 两个 fuzz 发现修复：M2-F1（json Recovered 文档被 project/edit 接受，P1）与 M2-F2（yaml 引号 `"~"` 标量被解码为空，P0 静默损失）——均修复并带严格断言/回归（见 Correctness）；
- API/semver 审查（`docs/API-REVIEW-0.13.0.md`）：五维审计 findings（F2/F3/F4/F10/F11/F13/F15 + 2 philosophy）全部转写并给出 disposition；M10 移交的 CLI backlog B-1..B-9 全部处置；cargo-semver-checks vs v0.8.0 实测（8 全绿 + 3 仅新家族枚举变体新增，RFC 级批准）；rustdoc 100% 断言；backend AST/第三方错误类型泄漏复查零泄漏；Go API mapping RFC 0016 立项；
- 性能与内存预算冻结（`docs/BENCHMARKS-0.13.0.md`）：每格式 SDK/CLI p50/p95/峰值内存预算行（§4/§5/§6）、§20.3 回退批准记录政策（§8/§9）、大文档/深嵌套/大量重复/大量小节点四场景独立行（§7）；三个超线性路径修复：xml `raw_offset` 恒等快捷（consema-rs 的 `consema-xml/src/parser.rs:2027-2052`，拆分前 `crates/consema-xml/…`）、`SourceSnapshot` 保留已校验 UTF-8 文本（consema-rs 的 `consema-document/src/source.rs:466-509`）、yaml `RawByteResolver` 单遍偏移解析（consema-rs 的 `consema-yaml/src/offsets.rs:1-80`），各带回归测试；修复后实测 xml 20k 节点 96.6 s→0.105 s（~920×）、yaml 335 KB 转换 69.4 s→1.01 s（~69×）、properties 10k 重复键 5.09 s→127.5 ms（~40×），§15.5 线性度门禁据此复验通过；
- 发布供应链（`docs/release-process-0.13.0.md` + `scripts/release-sign.ps1`/`release-sbom.ps1`）：checksum 清单（`docs/release/SHA256SUMS-0.8.0.txt(.asc/.sig)`）、GPG 签名 tag/artifact 流程（演练全流程实测，tag 重签拒绝）、SPDX-2.3 SBOM（`docs/release/sbom-0.8.0.json`，42 packages / 123 relationships；披露注记：该产物为 0.13.0 门禁期生成、按当时 workspace 版本 0.8.0 命名，含 0.9.0-0.11.0 新增 crate，非 0.8.0 发布树——1.0.0-rc.1 发布时按 §7 从干净发布 commit 重新生成）、干净环境重建步骤 + CI package 常设载体、三场恢复演练真实记录（checksum 篡改/归档损坏/丢 tag）；SECURITY.md 新增安全披露与支持周期章节（协调披露渠道 + 分级 SLA + 支持窗口）；
- support policy（`docs/support-policy.md`，§21.4 七个必公开项 + 工具链冻结时机）与真实项目 pilot（`docs/pilot-0.13.0.md`，路线图 §23.2 必做工作流 W1-W8 + §23.3 核心指标 12 项）；
- 72 CPU-hours RC fuzz 证据账本（`docs/fuzz-evidence-0.13.0.md` + `docs/fuzz-evidence-0.13.0-logs/`）：追加式 runs.csv 账本（2026-08-07 会话结束快照：26.309 真实 CPU-hours、4,063 次进程运行、10.994 亿次变异、零新发现；快照口径——追加式账本以 runs.csv 为准），确定性口径与完成路径文档化。

### Correctness

- M2-F1 修复：consema-json 在 `Document::project` 与 edit `commit` 入口拒绝 Recovered 文档（`ProjectionFailure::RecoveredDocument`/`EditFailure::RecoveredDocument`，consema-rs 的 `consema-json/src/projection.rs:330,363`、`edit.rs:262,305`，拆分前 `crates/consema-json/…`），驱动计数豁免移除、严格断言生效（`operation_fuzz.rs:123`）；
- M2-F2 修复：yaml 空标量重写仅限 plain 样式（`exact_empty_scalar`，consema-rs 的 `consema-yaml/src/native.rs:497`，拆分前 `crates/consema-yaml/…`），引号 `"~"` 按 YAML 1.2 语义解码为字符串；trip-wire 回归（`property_graph.rs:20-34`）计数即失败；
- 三处超线性形成路径修复（见 Added 性能条目），每个带边界宽松的线性回归网（`parser.rs:2842-2878` 10k 元素 <20s、`source.rs:1538-1589` 262,144 次坐标转换 <5s、`offsets.rs:90-156` 与 `raw_byte_at` 逐点相等）；修复只改善性能，BENCHMARKS 冻结预算仍为有效上界，无批准记录需求；
- B-6 修复：java-properties 源 convert/project 的族前缀特例（`project_cmd.rs:65-73`），发布的两个 `java-properties.projection.*` target 可达，回归测试 3 个（含"唯一阻塞是文档化边界"钉死测试）；
- B-9 修复：`inspect --profile` 对未注册格式本地 code 诊断复用 `registered_code` 注册 fallback（`inspect.rs` 的 `bind_parse_diagnostic` helper），Recovered→exit 0、fatal→exit 2，不再有 exit 5 内部错误；stderr 与 human 视图保留真码；回归测试矩阵（xml/plist/hcl 三例 Recovered + 三例深度 fatal + ini category 矛盾 + 进程级）；
- 信封语义不漂移：B-9 修复后 inspect 与 query 行为一致化（同一 fallback `core.source.invalid-sequence@1`，RFC 0015 §4.3 冻结），B-4 处置保持冻结；
- audit F3 修复（latent CLI panic）：`json.projection.incomplete-document@1`（0.13.0 的 json Recovered-document 门禁，consema-rs 的 `consema-json/src/projection.rs:756`，拆分前 `crates/consema-json/…`）注册进 v7 error registry（consema-rs 的 `consema-protocol/src/error_registry.rs`，拆分前 `crates/consema-protocol/…`，Projection/0.13.0，v7 计数 186 → 187），registry 测试钉死注册与 `Completion::new_with_registry` 接受该 code；project 失败记录改用 `failed_query_result` 同款 minimal_record 回退（`project_cmd.rs`），任何未注册 code 不再可能 panic CLI（exit 101）。

### Verified

- workspace `cargo test --workspace --locked`：1,617 passed / 0 failed（2026-08-07 实测）；18 套语言无关 suite 508/508（含 fuzz/property/mutation 新增的 conformance 域测试）；
- mutation corpus 全量 replay：174,921 case 通过（`cargo test -p consema-conformance --test mutation_corpus --locked -- --ignored`，2026-08-07 15:49；原始输出未保留在仓内、时长不可复算——见 fuzz-evidence-0.13.0.md §8 证据链说明）；
- cargo deny 四段与 cargo audit（本地 1,189 advisories / 76 deps / 0 漏洞；Cargo.lock 实测 76 个 `[[package]]`，cargo audit 口径随版本变化，以当前扫描结果为准）保持全绿；CI 10 job（lint/test/coverage/msrv/conformance/deny/audit/semver/oracles/package）均已落盘（第一次 GitHub 真跑是收口项，见 Boundaries）；
- coverage 可复现基线入库（86.51/82.82/87.91，脚本产出）；BENCHMARKS-0.13.0.md 预算表 + 后修复复测（S3 127.5 ms、S4 0.105 s）记录在档；
- 发布供应链演练真实执行：签名全流程、SBOM 生成、三场恢复演练、14 归档校验，记录于 `docs/release-process-0.13.0.md`。

### Boundaries

- **72 CPU-hours RC fuzz 未完成（质量门禁 Q-7，partial）**：2026-08-07 会话结束快照累计 26.309 CPU-hours、4,063 次进程运行（`runs.csv`；快照口径——追加式账本以 runs.csv 为准），每格式家族最接近的 properties 仅 6.9%（4.964/72）；零未解释发现，但"每格式 ≥72 CPU-hours"门槛未达。完成路径（`docs/fuzz-evidence-0.13.0.md` §7）：clang 主机对 17 个 cargo-fuzz target 跑 `cargo +nightly fuzz run`（corpus 进化），本机确定性协议续跑为备选；时长按追加式账本入 `runs.csv`，新 crash 清零该 target 计时；
- **CI 10 job 已落盘、未在 GitHub 真跑（A-4/A-9/SEC-9，partial）**：推入后在干净 checkout 全矩阵全绿是收口项；semver job 对三个 crate 的 `enum_variant_added` 保持失败 + RFC 级批准记录（`docs/API-REVIEW-0.13.0.md` §3），allowlist 修改属 `.github` 域由 gatekeeper 推入时落定；
- **真实发布密钥未生成（C-3，partial）**：演练密钥（82301612…）与 scratch 仓库不进入发布记录；0.13.0 发布前按 `docs/release-process-0.13.0.md` §4.1 在默认 keyring 生成真实密钥 + 私钥备份 + 吊销证书，并执行 §7 发布检查单（含版本推进 0.8.0→0.13.0）；
- 门禁 open backlog 保持：facade node-locator API（B-1/B-2，1.0.0 窗口）、每格式报告外部化（B-3）、失败 convert 形态（B-5，冻结语义）、每格式 edit 词表（B-7，0.14.0+）、`edit --write` 接线（B-8，usage 显式拒绝不漂移）；全部记录于 Feature-Complete Manifest 的 known_accepted_limitations；
- M2 修复、fuzz/property/mutation 语料与三处性能修复已随 0.13.0 落地 commit 094f5d1（Harden and gate the Rust implementation）与 7e9de38（Record the 0.13.0 gate evidence）入库，不再处于工作树状态；manifest 证据行号按 7e9de38 提交树核验。

### 落地记录（2026-08-07）

- **版本推进**：workspace 版本 0.8.0→0.13.0（15 个 crate 全部 `version.workspace = true`，CLI `PRODUCT_VERSION` 走 `CARGO_PKG_VERSION` 自动跟随）；发布检查单（`docs/release-process-0.13.0.md` §7）第 1 项完成，其余项（真实密钥生成、签名 tag/artifact、SBOM/checksum 落盘、恢复演练复跑）属 C-3 开放，完成路径不变；
- **五维交叉审计执行与修复**（哲学统一/语义一致/逻辑自洽/真实有效/完整可靠，六 agent 并行，对应路线图 §28 五要素终审）：共 5 P1 + 11 P2 + 4 P3，全部处置——README convert-request.json 损坏 JSON 修复（与 cookbook 一致）；Go core 值模型 8→15 kind 全契约（PVCE 七新标签字节对等，golden 向量经 scratch cargo 调 Rust 编码器生成验证，既有冻结字节零变动）；EncodeJSON 根节点重复计数边界修复；graph builder 非法 UTF-8 拦截；协议覆盖缺口测试（numberToken/unicodeEscape/不可达论证）；RFC 0016 §4.1 修订为 15-kind 映射（Status: Accepted）；CLI 帮助文本 `edit --write` 如实化（dry-run only）；cookbook Recovered 查询分层表述；conformance/README 18 套/508 cases 清单更新；路线图时间线与版本面同步；fuzz 账本统一回填（26.309 CPU-hours/4,063 次运行/10.994 亿变异，快照口径注明）；CI 10 job 计数与行号全库统一；聚合 sha256 算法文档化（值可精确复现）；waves.log 入库；0.1.0 日期修正；B-8 审计证据行同步；
- **Go SDK 0.14.0 G0.1-G0.3 按决策记录 D-1 入库**（`go/`：core 15-kind + PVCE、graph + PGCE、protocol v1-v7 41 条/187 码 + CLI 记录；238 个 Go 测试，`go build/vet/test/race/gofmt/tidy` 全绿，零第三方依赖）：按 2026-08-07 owner 决策记录（`docs/fc-manifest-0.13.0.json` decisions[0]）与路线图 §0 冲突解决层级（改路线图、不静默缩小承诺）落地；**这不是 0.14.0 发布声明**——0.14.0 发布仍受 C-1/C-2/C-3 门禁，Go 里程碑顺序与验收门禁（`docs/go-implementation-plan.md` §6）不变；
- **门禁复验实测（2026-08-07）**：Rust fmt/clippy `-D warnings`/workspace test/doc `-D warnings`（fresh target）/deny 四段/audit（1,189 advisories / 76 deps / 0 漏洞）全绿；Go 六项门禁全绿；mutation corpus 174,921 cases replay 通过；
- **开放项**（完成路径不变，见 fc-manifest）：C-1（CI 10 job GitHub 干净 checkout 真跑全矩阵全绿）、C-2（每格式 ≥72 CPU-hours release-candidate fuzz，当前最接近 properties 6.9%）、C-3（真实发布密钥 + 签名 + SBOM/checksum + tag + 恢复演练复跑）。

## Unreleased — 0.12.0

### Added

- 实现 RFC 0015，发布正式 `consema` CLI（11 个命令：inspect/capabilities/query/project/materialize/convert/edit/plan/apply/conformance/explain），作为 facade crate 的 `[[bin]]` 目标内置（`cargo install consema` 同时获得 SDK 与 CLI，可发布归档数不变）；CLI 是产品入口，不是第三个实现——bin 与 lib 同包，只能访问 facade public API，机器输出与 SDK 直接 encode 字节相等；
- 发布 semantic-model v7：v6 的 38 条 contract 记录冻结不变，追加 `core.cli-output@1`、`core.batch-plan@1`、`core.batch-result@1` 三个 CLI 稳定 payload（固定字段 PortableValue + canonical JSON/PVCE 双传输 + typed decoder 重验交叉约束）；v6 的 166 个 error code 冻结不变，追加 20 个 `cli.*` code（usage 7/data 2/detection 1/limit 3/write 5/interrupted 1/internal 1），共 41 条 contract 与 186 个 code（0.13.0 随 audit F3 修复在 v7 追加注册 `json.projection.incomplete-document@1`，v7 现为 187 个 code，见 0.13.0 条目）；`RegistryManifest::current()` 指向 v7；
- 机器协议：全部命令统一输出 `core.cli-output@1` 信封（command/exit_class/product_version/payload/diagnostics/redaction），stdout 只有一行规范 JSON（`--json`）或命令结果数据，诊断与进度全部走 stderr；exit code 0-5 稳定分类（success/usage/data/limit/precondition/internal），分类是纯函数，每个错误族都有穷尽映射测试；
- facts-only auto-detection：inspect 只报告字节大小/SHA-256/BOM/marker/候选 Profile（每个候选附理由）/歧义，永不输出"这是 X 格式"的单一结论；parse 类命令必须显式 `--profile`，歧义是可报告的一等结果而不是猜测；
- plan/apply 批量工作流：`plan` 逐文件 parse + edit dry-run，产出 `core.batch-plan@1` manifest（source_digest/operations/source_patch/target_digest），单文件失败作为 manifest 内容如实记录、不整批失败也不伪装成功；`apply` 逐文件重读重验 base digest 与 original-bytes 双前置条件，通过后同目录临时文件 + 原子替换 + 读回验证 target digest，产出 `core.batch-result@1`（completed/failed/pending/skipped-stale 状态机）；中断恢复：每文件写入前先落 pending 标记、完成后落 completed，重跑 completed 跳过、pending 重做（`CONSEMA_APPLY_INTERRUPT_AFTER`/`CONSEMA_APPLY_WRITE_FAILURE` 注入 seam）；
- secret redaction：保守键名模式集 + `--redact-keys <glob>` 追加，human 视图/plan 视图默认脱敏（`$REDACTED$` 占位 + stderr 提示 + 机器 `redaction` 事实），`--show-secrets` 是唯一展示取消通道；只影响展示，绝不触碰 SourcePatch 应用所需的字节前置条件；
- 零新外部依赖：参数解析、人类可读的规范 JSON 缩进渲染、原子写引擎、secret 检测全部自写（std-only；deny.toml 与 workspace 依赖政策不变）；
- 默认只读/dry-run：没有任何命令在无显式参数时写目标文件，写入必须显式 `--write`/`--apply`/`--output`；`apply` 只消费先前 `plan` 产生的 manifest，不接受裸操作；
- 新增 `consema.cli.conformance@1` 语言无关 suite（40 个 case，套件总数 17→18 达 508/508），覆盖 v7 信封双传输等价、exit-code 分类矩阵、batch-plan/batch-result 状态迁移（含非法迁移负例）、redaction 展示策略与检测事实矩阵；`consema conformance` 内嵌自检子集（信封 round-trip、exit 分类、redact 自检）随发布物执行，完整语言无关 suite 保持仓库级运行。

### Correctness

- CLI 全部格式知识来自 facade：`src/bin/consema/` 无任何 parse/query/project/materialize/edit/convert 实现代码，命令是"参数 → facade 调用 → 渲染"的薄驱动（编译期强制，硬门禁 1）；`capabilities` 清单由 facade 类型派生，不重复声明；
- 便利性不改变核心语义：duplicate/lossy/encoding/mapping 等 policy 全部由请求 payload 或显式参数给定，CLI 不发明默认策略（未授权 loss 即失败）；
- apply 的写入前重验（stale digest + original-bytes 双前置条件）与写入后 target digest 读回验证，与 plan 的 replacements/target digest 严格一致（dry-run/commit 等价契约的进程级落实）；CLI 层文件大小/批量文件数上限是 limit 类失败（exit 3），绝不截断伪装成功；
- redaction 是 presentation-only：脱敏值只出现在 human/机器展示层，SourcePatch 的 `original`/`replacement` 字节前置条件与 plan manifest 记录本身永不脱敏（硬门禁 3）；
- plan manifest 是产物不是授权：`plan` 永不写任何目标文件，manifest 记录（stdout 或 `--output`）与其在 `--json` 信封中的 payload 字节相同；
- 默认无文件写入与无副作用链：inspect/query/project/materialize/convert（默认）/plan/conformance/explain 全部只读；materialize/convert 的目标字节默认只到 stdout；进程中断的优雅路径先落 manifest 再退出。

### Verified

- Rust 1.97.1 下 workspace `--all-targets --all-features` 的 1,564 项 tests 与 strict Clippy、rustfmt 通过；doc-tests 与 rustdoc `-D warnings` 通过（发布门禁体例）；
- 18 套语言无关 suite 共 508/508 cases 通过（其中 semantic-model v6 25/25、INI 20/20、Java Properties 22/22、XML 34/34、plist 45/45、HCL 57/57、CLI 40/40；semantic-model v7 与 `consema.cli.conformance@1` 见上）；
- RustSec 使用本地 1,189 条 advisory 数据扫描 Cargo.lock 的 42 个 crate dependencies，无已知漏洞；cargo-deny advisories、bans、licenses、sources 四类门禁通过；
- 14 个可发布 `.crate`（consema 归档现含 CLI bin）完成路径安全、内部 checksum/归档 SHA-256 一致性检查，并在 Rust 1.97.1 与 MSRV 1.85.0 下从解包内容通过全 target/全 feature 编译；repository-only 的 `consema-conformance` 明确设为不可发布；
- CLI 进程级 e2e 与 hardening 覆盖：参数矩阵、stdout/stderr 分流、exit code 矩阵、机器输出与 SDK encode 字节相等、plan→apply 全流程、stale/篡改 original/只读/目录/symlink/权限/磁盘/中断注入（`tests/cli_*.rs`，env!(`CARGO_BIN_EXE_consema`) 启动二进制，零 dev-dependency）；
- 本机 CLI 性能基线（冷启动 inspect、parse-path query、批 100 文件 plan/apply、信封 round-trip）记录于 `docs/BENCHMARKS-0.12.0.md`，方法学与 BENCHMARKS-0.9.0/0.11.0 同纪律。

### Boundaries

- `consema query` 只接线 `core.portable-value-query@1`：native 查询域需要调用方外部化的 node locator，facade 尚未暴露该 API（xml/plist/hcl 源因此不可经便携域查询，显式拒绝而非不完整结果）——0.13.0 API 评审项；
- `consema project` 的报告/来源外部化仅 json/toml 两家族（TOML 非空报告同样拒绝）；其余家族显式拒绝，绝不输出不完整记录——0.13.0 API 评审项；
- materialize/convert 结果的 provenance map 为空（facade 无 locator API，无法真实外部化），envelope 携带空 map——0.13.0 API 评审项；
- edit/plan/apply 的操作词表仅接线 INI family（consema-ini operation registry），其余格式的版本化编辑操作尚未映射；`edit --write` 仍拒绝（dry-run only），单文件提交路径未接线——0.13.0 API 评审项；
- 信封只能携带注册 code：XML/plist/HCL 等格式本地诊断在信封中绑定注册 fallback（`core.source.invalid-sequence@1`），stderr 行保留真码，人可读信息不丢失（RFC 0015 §4.3 冻结语义）；
- 本版本不提供原生查询域的进程级 locator、跨格式 edit 词表、`edit --write` 单文件提交、shell 补全、watch/live 模式或 Go 实现。

## Unreleased — 0.11.0

### Added

- 实现 RFC 0014，发布 `hcl.native@1` 与 `hcl.tfvars@1`：两 Profile 共享同一语法系统与原生模型（有序 body/attribute/block/label 与完整 expression AST + 精确 span 双保留），tfvars 只是顶层仅 attributes 的 profile 结构限制（顶层 block → Recovered + `hcl.tfvars.block-not-allowed@1`）；
- 自研 lexer + parser（无第三方 HCL 后端、无求值器）：UAX #31 标识符（unicode-ident 钉版）、引号模板/heredoc/插值/指令文法、30 种 lossless syntax kind 的穷尽 piece 覆盖；前导 BOM（Recovered，无 Bom kind）、lone CR、invalid UTF-8（fatal）、duplicate attribute 等恢复与诊断语义；
- `hcl.native-semantic-query@1` 与 `hcl.lossless-syntax-query@1` 两查询域（RFC 0014 §7.1 全操作符 + 30 种 kind/text 过滤）；`QueryDomain` 仅新增两个构造器，查询 wire 契约不进 consema-protocol 核心注册表；
- `hcl.projection.body@1` 精确投影：literal-complete 判定、类型化 members（string/integer/real/boolean/null/tuple/object）、attribute/block/label 序与重复 object key 全保留；derived 表达式默认原子失败，显式 `ProjectExpression` 策略下投影为 authorized ExtendedValue `hcl.expression@1`（type_id/version/版本化 payload codec/structural fingerprint，重解析比对指纹）；
- `hcl.canonical-document@1` materialization：UTF-8 无 BOM、两空格缩进、label 恒加引号、数字 canonical 拼写（`1.50`/`15e-1` → `1.5`），生成字节必先重解析并逐节点比较闭包语义（数字按 canonical-decimal 值相等、其余按结构相等）；
- 6 个版本化编辑操作：`set-attribute-value`、`insert-attribute`、`remove-attribute`、`rename-attribute`、`insert-block`、`remove-block`，值以类型化 literal-complete 提供；tfvars Profile 只发布前四个 attribute 操作；
- 新增 `consema-hcl` 公共 crate（可发布）与 facade 导出（`consema::hcl`、`Document::parse_hcl`/`as_hcl`、`convert_hcl` 跨格式转换目标）；从 HCL 转换遇 derived 表达式按默认精确目标原子失败；
- 新增 `consema.hcl.conformance@1` 语言无关 suite（57 个 case），使 17 套 suite 达到 468/468；覆盖 formation、全部表达式/模板/heredoc 文法、恢复、双查询域、projection、materialization、六类 edit 与 limits。

### Correctness

- HCL Profile 在 formation 前选择；`.tf`/`.tfvars` 扩展名不选择 Profile、representation 或 encoding，encoding 恒为 UTF-8，BOM 是 Recovered 而非 fatal；
- parse/query/project/edit 全程不求值：无 variable/function/template 求值与展开、无 Terraform/cty 语义、无 application schema（硬门禁 2）；`hcl.expression@1` 只承载语法事实，永不执行；
- duplicate attribute 在 formation 排除、永不进入 native 模型；重复 object key、重复 block occurrence 与 attribute/block 同名共享保留为有序 native facts（独立 span，永不折叠）；
- 恢复语义：expression 失败/未终止构造以错误区域收容（string/heredoc 到行尾或上限边界），Recovered 后 body 从下一行继续，绝不虚构 closing delimiter/equals/value；Recovered 文档可查询、不可 project/materialize/commit；
- canonical materialization 生成字节必先重解析并逐节点比较闭包语义，失败返回无目标 Document、无 partial bytes、无 partial provenance；
- 全部尺寸算术在分配前 checked（expression/template/heredoc depth、number digits、item/label/attribute counts、recovery regions、syntax pieces），limit 失败绝不伪装成空 body、截断表达式或缩短查询；
- 未修改 Document 字节精确往返；数字 canonical-decimal 归一为纯十进制字符串运算，零浮点计算。

## Unreleased — 0.10.0

### Added

- 实现 RFC 0013，发布 `plist.xml@1` 与 `plist.binary@1`：两个 Profile 共享一个原生值模型（有序 dict/array/string/integer/real/boolean/date/data/UID），但拥有不相交的语法系统；XML 表示是无损 tag 树（UTF-8/UTF-16 显式 source contract），binary 表示是 object table（offset-table 与 trailer 事实，不伪造文本 token/trivia）；
- XML/binary 双表示 round-trip 转换：序列化目标表示字节、重解析并验证原生模型相等（reparse closure），每次转换报告 representation change 与逐值映射事件；目标表示无法表达的原生事实（UID、Float32 width、未配对 surrogate、分数秒/越界日期等）原子失败并发布 `plist.conversion.inexpressible@1`，无部分目标文档；
- `plist.value-tree@1` 精确 projection、`plist.xml-canonical@1`/`plist.binary-canonical@1` materialization（生成字节重解析闭包验证）与 native/syntax/binary-structure query；
- 6 个版本化编辑操作：`set-value`、`insert-dict-entry`、`remove-dict-entry`、`rename-dict-key`、`insert-array-element`、`remove-array-element`；
- 新增 `consema-plist` 公共 crate（可发布）与 facade 导出（`consema::plist`、`Document::parse_plist`/`as_plist`、plist materialization 转换目标）；
- 新增 `consema.plist.conformance@1` 语言无关 suite（45 个 case），使 16 套 suite 达到 411/411；覆盖 formation、全部值类型、双表示转换、query、projection、materialization、六类 edit 与 limits。

### Correctness

- plist Profile 在 formation 前选择；`bplist00` magic number 与 `.plist` 扩展名都不选择 Profile、representation 或 encoding，encoding selection 与 Profile 不一致是 formation 时的 source-contract 冲突；
- XML 与 binary 共享值语义但不共享语法树；XML 文档永不暴露 binary object/offset/ref/trailer 事实，binary 文档永不暴露文本 token/trivia（硬门禁 1）；
- formation 无副作用：不 fetch Apple DTD 或任何 URI，不解析 UID archive key path，不求值表达式，不读环境/locale 状态，不写文件，不调用应用代码；
- date、data 与 integer 不通过字符串降维；binary object reference、offset 与 size 计算有溢出与资源限制保护；
- 恢复文档不进入 projection、materialization 或 edit；canonical materialization 生成字节必先重解析并逐节点比较闭包语义，失败返回无目标 Document、无部分字节；
- 未修改 Document 字节精确往返；XML 原始 code unit 与 binary 原始字节全部保留。

## Unreleased — 0.9.0

### Added

- 实现 RFC 0012，发布 `xml.1.0-safe@1`：namespace-aware 无损 Document（prolog/DOCTYPE/元素/attribute/namespace/text/CDATA/comment/PI/mixed content）、predefined/character/admitted internal entity 与六维文档级实体膨胀限制、外部 subset/entity 与参数实体 deny-by-default、UTF-8/UTF-16LE/BE 显式 source contract（UTF-16 必须带 BOM）、native/syntax query、element-tree/text-content/entry-mapping projection、`xml.safe-canonical-document@1` materialization（生成字节重解析闭包验证）与 8 个版本化结构编辑操作；
- 新增 `consema-xml` 公共 crate（可发布）与 facade 导出（`consema::xml`、`Document::parse_xml`/`as_xml`、XML materialization 转换目标）；
- 新增 34 个语言无关 XML 案例，使 15 套 suite 达到 366/366；
- XML 语法覆盖扩展为 37 种细粒度 syntax kind（declaration/doctype/tag/qname 部件/attribute 部件/reference/CDATA/comment/PI 全部独立成 piece）。

### Correctness

- XML Profile 在 formation 前选择；扩展名不授权 I/O、schema、DTD 校验或 application mapping；解析只消费单文档实体，不打开任何外部实体、文件、URI、网络连接或 catalog；
- DOCTYPE 仅允许 bounded internal subset；外部/参数实体、notation 与 validation 声明恢复并发布诊断；内部 subset 注释不会被误读为排除声明；
- entity 膨胀按整个文档记账（declarations/references/depth/bytes/scalars/amplification 六维），突破即恢复，绝不以截断文本或空树伪装成功；
- namespace 声明与 expanded name 分离；重复 expanded attribute、unbound prefix、保留前缀误用均恢复或拒绝编辑；编辑不猜测、不伪造 xmlns 声明；
- 恢复文档永不投影或编辑；materialization 生成字节必先重解析并逐节点比较闭包语义，失败返回无目标 Document；
- 未修改 Document 字节精确往返；UTF-16 原始 code unit 与 BOM 全部保留。

## 0.8.0 — 2026-08-05

### Added

- 实现 RFC 0009，发布 `ini.portable@1`、`ini.windows@1` 与 `ini.python-configparser@1` 三个显式 Profile；覆盖 raw source/encoding、physical/logical line、section/entry identity、native/syntax query、EntryMapping 优先投影、三种 canonical materialization 与 8 个版本化编辑操作；
- 实现 RFC 0010，发布 `java-properties.reader@1` 与 `java-properties.latin1@1`；覆盖 natural/logical line、separator/continuation/escape、重复 property identity、精确 Java UTF-16 code unit、query、projection、canonical materialization 与 5 个版本化编辑操作；
- 实现 RFC 0011，发布 `core.semantic-model@6`：38 条 contract registry 记录与 166 个稳定 error code；新增 source encoding/snapshot/patch v2、materialization request/result v2、Java UTF-16 string 与外部定位的 INI/Properties query result，并精确冻结 v1-v5；
- 新增 `consema-ini`、`consema-properties` 公共 crate 与 facade 导出；新增 67 个语言无关案例，使 14 套 suite 达到 332/332；
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
- 新增 10 个 PortableGraph、22 个 semantic-model v5 与 27 个 YAML language-neutral cases，使 11 套 suite 合计达到 265/265；
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
- 11 套语言无关 suite 共 265/265 cases 通过；PortableGraph 10/10、semantic-model v5 22/22、YAML family 27/27；
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
- 8 套语言无关 suite 共 206/206 cases 通过，其中 JSON family v2 为 33/33；
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
- 7 套语言无关 suite 共 173/173 cases 通过，其中 operations v1 为 35/35；
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
- 新增 28 个 source、19 个 shared syntax-query、11 个 protocol v2 与 10 个 core/JSON 编辑表示保持、查询 limit/终态、投影来源及 PVCE 边界语言无关 conformance cases。

### Correctness

- digest 对包含 BOM 在内的完整原始字节计算，不混入 encoding、Profile 或 metadata；
- encoding 冲突、非法 UTF 序列、unsupported UTF-32 BOM 与 decoded size/coordinate overflow 均显式失败；
- Syntax Query kind/text、source order、selection、limit 与 cancellation 在 JSON/TOML 间共享语义但不共享格式 kind 类型；
- SourcePatch 在分配前验证 count/bytes/output bounds，并在 stale digest、original mismatch、encoding drift、overlap 或 target mismatch 时不产生新 snapshot；
- lazy query cursor 对 branch clone、merge aggregation 与巨大容器 expansion 施加分配前/分配中上限。

### Verified

- workspace `--all-targets --all-features` 共 141 个 Rust tests 通过，fmt、strict Clippy、doctest 与 `-D warnings` rustdoc 通过；
- 30 个 core/JSON、18 个 TOML、32 个 protocol v1、28 个 source、19 个 syntax-query 与 11 个 protocol v2 cases 全部通过，共 138 个语言无关案例；
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

## 0.1.0 — 2026-08-04

### Added

- 建立 PortableValue、PVCE/1、不可变文档事实、诊断、能力与类型化查询基础；
- 发布 `json.strict@1` 与 `jsonc.bounded@1` 的无损文档、查询、精确投影和标量编辑；
- 建立语言无关 conformance runner、硬化语料与 Rust workspace 发布门禁。
