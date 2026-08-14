# 五要素终审（§28 收口记录，`1.0.0` 前哨）

- 对应门禁：路线图 §28《五要素终审》（74e336e 树 :2253-2329 / 现行 :2259-2337；行号可能漂移，以锚为准），对 §28.1-§28.5 的通过条件逐条核验
- 日期：2026-08-10（本地实测）
- 计数口径注记（2026-08-13 round-4 补充）：本文件多处「conformance 508/508」为
  2026-08-12 19:41（ad66702，P2-B 向量补强）之前撰写的记录，保留当时口径 508（自洽
  历史快照，不静默改写）；现行口径为 18 套 suite / 519 cases（digest cfd6e296…，
  fc-manifest-0.13.0.json digests.conformance_suite——以字段名为锚，行号可能漂移）。
- 范围：0.13.0-0.19.0 全周期已积累审计证据的**最终状态核验**（不重跑审计，只核验修复后状态）；
  只读核验 + 实际抽查；所有声称标注证据（file:line）或实测记录
- 核验口径：
  - **提交态** = 当前 HEAD（含 2209582 的 F-A/F-B 修复与 1.0.0-rc.1 版本推进）；本核验时点提交
    `74e336e`（历史提交：Deliver Go 0.19.0 G5.6-G5.7，go/ 0.14.0-0.19.0 证据链终点），
    抽查在临时 worktree（`git worktree add ... 74e336e`，干净 checkout）执行；
  - **工作树** = 主仓库当前状态。版本推进（consema-rs 15 个 `Cargo.toml` 的
    `0.13.0 → 1.0.0-rc.1` 与 `consema-go/go/cmd/consema/version.go` 的 `0.19.0 → 1.0.0-rc.1`）与 RFC 0020 已于 2209582 提交（docs/rfcs/0020-compatibility-and-support-policy-v1.md，
    Accepted，2026-08-10）。工作树与提交态的历史差异如实区分（见 §5）；
  - 无法在本机复核的声称（三平台矩阵的 Linux/macOS 腿、72 CPU-hours 账本时长等）标注来源与日期，不冒充实测。

---

## 1. 五要素逐条核验

### 1.1 §28.1 哲学统一（74e336e 树 :2255-2265 / 现行 :2261-2271；行号可能漂移，以锚为准）— **PASS**

| # | 通过条件（原文引用 §28.1） | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 八个格式都以不可变 Document 为真实状态 | Rust：各家族 RFC 0012-0014 与 README（无损 Document、immutable）；Go：consema-go/go/README.md 的「SDK usage essentials (roadmap §21.2 / RFC 0016 §6)」节政策 1（Completed objects 逻辑不可变、访问器返回拷贝、唯一变更路径是显式 builder；74e336e 树 :455 / 现行 :477；行号可能漂移，以锚为准）。CHANGELOG.md（0.11.0/0.10.0 行"未修改 Document 字节精确往返"） | 通过 |
| 2 | PortableValue 不吞并 graph、XML tree 或 HCL program | YAML graph 归属 PortableGraph（RFC 0006/0007，CHANGELOG.md"PortableValue 未因 YAML 增加引用或 graph 类型"）；XML element-tree、HCL body/expression 各自有 `xml.element-tree@1`/`hcl.projection.body@1`/`hcl.expression@1` 记录（CHANGELOG.md）；IMPLEMENTATION.md（"PortableGraph 是与 PortableValue 平行的 immutable portable representation"）；Go 侧同名记录（consema-go/go/README.md 各家族记录：xml 族 `xml.element-tree@1` 记录 74e336e 树 :298-301 / 现行 :318-321、hcl 族 `hcl.projection.body@1`/`hcl.expression@1` 记录 74e336e 树 :402-405 / 现行 :422-425；行号可能漂移，以锚为准） | 通过 |
| 3 | Projection、Materialization 和 Edit 都是显式操作 | RFC 0004（MaterializationRequest/Result、fidelity/report/provenance）；CLI 默认只读/dry-run、写操作显式参数（CHANGELOG.md"没有任何命令在无显式参数时写目标文件"）；失败形态原子（B-5，API-REVIEW-0.13.0.md"report:null,target:null 是诚实形态"）；Go 侧同样显式（pilot-go-0.19.0.md §2.7 六组原子拒绝） | 通过 |
| 4 | CLI 便利性不改变核心默认拒绝原则 | RFC 0015（default dry-run、`edit --write` usage 显式拒绝，consema-rs/consema/src/bin/consema/edit_cmd.rs 由测试钉死）；帮助文本已如实化（API-REVIEW-0.13.0.md：args.rs "dry-run only"） | 通过 |
| 5 | Rust 与 Go 共享行为，不强制共享实现结构 | 路线图 §11（双实现原则）；RFC 0016 §1.1 cgo 禁令（consema-go/go/README.md 的 cgo 禁令句，74e336e 树 :771 / 现行 :845；行号可能漂移，以锚为准）；Go stdlib-only 零第三方依赖（consema-go/go/go.mod 无 require；consema-go/go/README.md 的 stdlib-only 句 74e336e 树 :501、go.mod 零第三方依赖句 :554 / 现行 :532；行号可能漂移，以锚为准）；两语言独立 parser（consema-go/go/README.md 各家族"self-written"/"independent tokenizer"） | 通过 |
| 6 | 生产级范围没有把配置来源、evaluation 和治理平台塞入核心 | `.env` 明确为"后续 source adapter，而不是第九种配置格式 Profile"（CHANGELOG.md 的 `.env` 句，74e336e 树 :190 / 现行 :225；行号可能漂移，以锚为准）；HCL 不求值（SECURITY.md、CHANGELOG.md）；无 schema/registry/remote-KV 进核心（路线图 §24 非目标清单，CHANGELOG.md） | 通过 |

### 1.2 §28.2 语义一致（74e336e 树 :2266-2291 / 现行 :2272-2297；行号可能漂移，以锚为准）— **PASS**

- 通过条件为 18 个概念（SourceSnapshot → Conformance）的清单 + "每个概念只有一个核心职责，不随格式或语言改变含义"。
- 证据：semantic-model v7 registry（41 contract / 187 error code，fc-manifest-0.13.0.json digests.contract_registry——以字段名为锚，行号可能漂移）在 Rust 与 Go 两侧逐字节一致（consema-go/go/README.md 的注册表 v1-v7 计数概述行，74e336e 树 :30-32 / 现行 :47-50；capability parity 硬门禁，consema-go/go/README.md 的「Capability parity」节，74e336e 树 :797 / 现行 :878；行号可能漂移，以锚为准）；语言无关行为不依赖 Rust 类型名（§15.2，API-REVIEW-0.13.0.md）。
- 实测：跨语言 normalized-result 差分 108/108（双向）、protocol exchange 83/83（双向）、byte parity 68/68（2026-08-10 本机重跑，见 §4 实测表）——18 个概念在跨语言面上行为一致。
- 命名漂移 findings（F2 `core.edit.incomplete-target@1` 双语义、F4 projection 拼写、F11 duplicate-group 词、F15 PascalCase 拼写等）全部**冻结且被 RFC/vector 钉死**，disposition = exempt-with-reason（API-REVIEW-0.13.0.md §1），修复窗口为 semantic-model v8 / 1.0.0 API 冻结；语义含义不随格式/语言漂移，属命名层清理而非语义不一致 → 不违反本条通过条件。
- 结论：通过（v8/1.0.0 命名清理项不阻塞本要素）。

### 1.3 §28.3 逻辑自洽（74e336e 树 :2292-2303 / 现行 :2298-2309；行号可能漂移，以锚为准）— **PASS**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | read/query/project 链闭合 | W1-W7 全工作流经公共 API 端到端（pilot-go-0.19.0.md §2.1-§2.7）；query 定义错误不晚于首个 Match（rc-1.0.0-candidate.md）；Go 三查询域 21 个（consema-go/go/README.md 的 facade 快照段：registry.go 三查询域记录） | 通过 |
| 2 | materialize/convert 链闭合 | 两阶段 projection→PortableValue→materialization 组合（CHANGELOG.md）；canonical 生成字节必先重解析闭包验证（各家族 Correctness 段）；Go `Convert*` 8 入口（consema-go/README.md 的「API 摘要」节）；convert 组合 W6 全 Exact、W7 六组原子拒绝（pilot-go-0.19.0.md §2.6-2.7） | 通过 |
| 3 | edit/patch/apply 链闭合 | dry-run/commit 等价（EditPlan/SourcePatch/UntouchedByteProof，CHANGELOG.md）；plan/apply 双前置条件 + skipped-stale 状态机（pilot-go-0.19.0.md §2.8）；中断恢复 100%（53+47，pilot metric 11） | 通过 |
| 4 | Document 与 portable representation 之间没有隐藏同步 | 转换/物化全部显式两阶段 + 重解析闭包验证（CHANGELOG.md"失败不携带 Document/partial output"）；无共享缓存/隐式关联（架构层，IMPLEMENTATION.md 分层） | 通过 |
| 5 | format-specific edit 不伪装成 universal edit | 16 个 format-local operation registry（按 profile 计；各家族操作数 json 8/toml 7/yaml 8/ini 8/properties 5/xml 8/plist 6/hcl 6 合计 56，fc-manifest-0.13.0.json digests.operation_registry——以字段名为锚，行号可能漂移；Go 侧同集（consema-go/go/README.md 的 registry.go 概述行：8 families / 16 profiles / 21 query domains / 16 operation registries（RFC 0015 §6.2），74e336e 树 :430-433 / 现行 :450-452；行号可能漂移，以锚为准））；跨家族组合显式经 Document 投影/物化，不假借"通用编辑" | 通过 |
| 6 | YAML graph、XML tree 和 HCL expression 都有合法归属 | PortableGraph / `xml.element-tree@1` / `hcl.expression@1`（§1.1 第 2 行证据）；Go 侧同名记录实现（consema-go/go/README.md 各家族记录：yaml 族 MaterializeGraph/MaterializeValue 与 `&gN` anchors 74e336e 树 :183-189 / 现行 :203-208、xml 族 `xml.element-tree@1` 记录 74e336e 树 :298-301 / 现行 :318-321、hcl 族 `hcl.projection.body@1`/`hcl.expression@1` 记录 74e336e 树 :402-405 / 现行 :422-425；行号可能漂移，以锚为准） | 通过 |
| 7 | Rust 先行与 Go 反向审计没有权威循环 | PVCE/PGCE 字节权威 = Rust 编码器（consema-go/go/README.md 的 "Rust side is the authority for the bytes" 句，74e336e 树 :588 / 现行 :650；行号可能漂移，以锚为准）；golden 向量由 Rust 编码器生成、Go 逐字节转录，既有冻结字节零变动（CHANGELOG.md）；差分 harness 双向（Go 发射 → Rust consume）构成对 Rust 的独立反审计而非循环依赖；cgo 禁令排除 FFI 作弊（consema-go/go/README.md 的 cgo 禁令句，74e336e 树 :771 / 现行 :845；行号可能漂移，以锚为准） | 通过 |

**Kotlin ChangeSet 结构差异（终审记录 F-28.3-1，2026-08-12，LOW）**：Kotlin 在 7/8 family 无一等公民 ChangeSet
（consema-kt/kotlin/src/main/kotlin/consema/json/Edit.kt 标注 "ChangeSet is a post-1.0.0（冻结前评估项，见五要素终审 F-28.3-1 处置）milestone; this L1 commit carries the ordered edit diagnostics"——class EditCommit 在 :248；consema-kt 0d6dde9 已将 L4 标注 15 处改为 post-1.0.0）；
`core.change-set@1` 向量经 runner 本地 wire builder（镜像 Rust 构造器）通过，协议线格式面闭环；
功能闭合不受影响（conformance 508/508）。处置：不重构 Kotlin edit 管线（属 1.0.0 API 冻结决策，留待
冻结前评估）；建议在 1.0.0 API 冻结前对齐（见 §6.2 收口项）。

### 1.4 §28.4 真实有效（74e336e 树 :2304-2315 / 现行 :2310-2321；行号可能漂移，以锚为准）— **PASS**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 格式范围来自跨生态调查，而不是个人偏好 | 路线图 §4《1.0.0 格式范围》生态调查与范围论证（74e336e 树 :239-357 / 现行 :243-361；行号可能漂移，以锚为准）；RFC 0001-0014 逐个冻结 Profile 依据 | 通过 |
| 2 | `.env`、注册表和远程 KV 被正确归为来源 | CHANGELOG.md 的 `.env` 句（"`.env` 仍是后续 source adapter，而不是第九种配置格式 Profile"；74e336e 树 :190 / 现行 :225；行号可能漂移，以锚为准）；路线图 §24 非目标清单（注册表/远程 KV 不在 1.0.0 范围）——正确归类、未混入核心 | 通过 |
| 3 | 八个家族完成真实 corpus 和迁移工作流 | 钉版 corpus 12 文件（pilot-go-0.19.0.md §1，digest 登记）；三类真实批量迁移全部执行（版本/镜像更新、结构插入删除、跨格式转换，pilot-go-0.19.0.md §4.1-4.3）；fixtures 覆盖 9 目录（conformance/fixtures/，2026-08-10 实测） | 通过 |
| 4 | 每个格式不仅能 parse，还能保真、查询、投影、生成和编辑 | 路线图 §8《每个 GA 格式的 Mandatory Capability Matrix》（74e336e 树 :613-646 / 现行 :617-650；行号可能漂移，以锚为准）；18 套语言无关 suite 508/508（实测 508 passed / 0 skipped / 0 failed，见 §4）；Go 侧 capability parity 全等（实测 PASS）；pilot W1-W5 覆盖全部八家族编辑 | 通过 |
| 5 | 用户可以用 CLI 安全 plan/apply | Rust CLI 与 Go CLI（consema-go/go/cmd/consema；核验提交 74e336e 为拆分前母仓 commit，go 仓不可直接解析，见 §1 核验口径）plan/apply 六步写前重验 + 原子替换 + 读回验证；stale/篡改/只读/中断负例全绿（pilot-go-0.19.0.md §2.8；rc-1.0.0-candidate.md（stale/中断；演练 4 只读负例段——行号可能漂移，以小节为锚））；升级演练逐字节兼容（rc-1.0.0-candidate.md §3.2——行号可能漂移，以小节为锚） | 通过 |
| 6 | 性能、安全和供应链有可重放证据 | BENCHMARKS-0.13.0.md（冻结预算 + 复验机制 §12）；三处超线性修复复测（CHANGELOG.md）；security matrix（consema-go/go/README.md 的「Security matrix (0.19.0 G5.4)」节：XML/plist 32 行 + HCL 13 行 = 45 行边界 + threat corpora）；供应链流程落地（release-process-0.13.0.md）——**但 0.13.0 真实发布未执行（C-3）且演练发现 D-1/D-2（checksum 不可复现、密钥无备份），见 §2 与 §3** | 通过（发布执行属 §28.5 口径） |
| 7 | 静默信息损失为零 | pilot metric 3 = 0（pilot-go-0.19.0.md）；M2-F2（P0 静默损失）已修复并带 trip-wire（fuzz-evidence-0.13.0.md §5/§6 的 M2-F2 记录）；audited conversion 全部 fidelity=Exact 或原子失败（pilot metric 4/5） | 通过 |

### 1.5 §28.5 完整可靠（74e336e 树 :2316-2329 / 现行 :2322-2337；行号可能漂移，以锚为准）— **PARTIAL**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 标准、Rust、Go、CLI 和 suite 同时完成 | RFC 0001-0016 与 0020 冻结（0017-0019 编号保留未用）；Rust 0.13.0 Feature-Complete（fc-manifest 功能门禁全 complete）；Go 0.14.0-0.19.0 全部里程碑交付（74e336e）；Rust CLI 11 命令 + Go CLI beta（consema-go/go/cmd/consema，e2e 9 测试实测 PASS）；18 套 suite 508 cases 双 runner 全过（实测） | 通过 |
| 2 | 所有 mandatory capability 100% 通过 | 508/508（实测）；capability parity 8 families / 16 profiles / 21 query domains / 16 operation registries（按 profile 计）/ 56 operations / 187 codes（实测 PASS）；无 "Rust only" mandatory 行为（consema-go/go/capability_parity_test.go） | 通过 |
| 3 | P0/P1 为零 | 通过：F-A/F-B 已修复并验证（2209582，审计 PASS），"无未解决 P0/P1"恢复成立——rc-1.0.0-candidate.md 记录"当前 0"（本次核验当时发现的 F-B 提交态证据缺陷与 F-A 工作树回归已分别处置，见 §5.1/§5.2） | **通过** |
| 4 | 两语言 observable mismatch 为零 | normalized differential 108/108 ×2、byte parity 68/68、protocol exchange 83/83（2026-08-10 全部重跑通过，§4）；pilot metric 12 = 0（pilot-go-0.19.0.md）；Go fuzz 4 缺陷修复后双语言契约一致（consema-go/go/README.md 的「Full-family fuzz targets (0.19.0 G5.4)」节） | 通过 |
| 5 | 生产发布物可验证、可重建、可升级 | 发布流程与演练已落地（release-process-0.13.0.md、rc-1.0.0-candidate.md §3：升级/回滚逐字节兼容）；**但真实发布未执行（C-3 开放）**：无真实密钥、无发布 commit 上的 checksum/SBOM/签名；演练发现 D-1（0.8.0 checksum manifest 从 git 历史不可复现，脏树记录）与 D-2（演练密钥无持久公钥） | **部分（C-3 + D-1/D-2 阻塞）** |
| 6 | failure、recovery、cancellation、limits 和 conflict 都有正式语义 | RFC 0015 exit code 0-5 分类（穷尽映射测试）；limits 矩阵（Rust SECURITY.md + consema-go/go/conformance/limits_matrix_test.go 83 行 + consema-go/go/conformance/security_matrix_test.go 45 行——XML/plist 32 行 + HCL 13 行）；batch 状态机 completed/failed/pending/skipped-stale；中断注入 seam（CONSEMA_APPLY_INTERRUPT_AFTER）；RC soak 待补：**仅磁盘失败演练未记录**（rc-1.0.0-candidate.md，P2-6，RC soak 阶段 1 必做：部分权限演练已闭环——演练 4，2026-08-10；磁盘失败环境阻塞——演练 5：C-1 已闭环（2026-08-11）后 Linux runner 完成路径可用，演练本身仍待执行） | 通过（仅磁盘失败演练归 RC soak 收口） |
| 7 | 没有通过 experimental 标签隐藏未完成的 1.0 承诺 | F-8 门禁 complete：无 mandatory capability 标记 experimental/stub/partial（fc-manifest-0.13.0.json gates.capability 断言——以字段名为锚，行号可能漂移）；全部边界是显式拒绝而非 stub（CHANGELOG.md） | 通过 |

---

## 2. 已知开放项对五要素的影响

| 开放项 | 状态（fc-manifest open_items / rc-1.0.0-candidate） | 依赖它的 §28 条件 | 影响判定 |
|---|---|---|---|
| C-1：CI 10 job GitHub 干净 checkout 全矩阵全绿 | **已闭环（2026-08-11：GitHub Actions run #5，head 437fd35，132/132 steps 全绿，10+1 job（增补前，11 定义/17 次执行）windows/ubuntu/macos 全矩阵；go-differential 2026-08-12 增补后 ci.yml 为 10+2 job/12 定义；fc-manifest open_items C-1 → closed）** | §28.5 条件 1/3/4（三平台全矩阵、SEC-9 Linux/macOS 验证、A-4 msrv 真验证、A-9 package 真跑、semver approved-failure 落定） | **C-1 腿阻塞已解除**（run #5 真跑全绿：三平台全矩阵、SEC-9、A-4、A-9 随 manifest C-1.closes 满足）；§28.5 仍 **PARTIAL**——C-2/C-3 未关闭（partial）；**延伸（2026-08-12，head dbba9a4）**：五语言 CI 全绿（ci.yml run#9 Rust 10+1 + ci-typescript/ci-python/ci-kotlin 各 run#2 全绿；go-differential 上线：2026-08-12，run#12 全绿）——§28.5 条件 1（标准/Rust/Go/CLI/suite 同时完成）的证据由双语言扩展到五语言在 CI 中 live（five-language-ci-design.md §10） |
| C-2：每格式 ≥72 CPU-hours release-candidate fuzz | partial（runs.csv 13,005 行 / 79.427 CPU-hours，截取自 session 79 期间，2026-08-10；最接近格式 properties ≈20.6%（14.8/72）；零新 crash；Go 16 targets 30s clean-run 已有记录）；**2026-08-13 复算快照（runs.csv 权威）**：122,477 数据行（122,478 文件行含表头）/ 780.529 CPU-hours，零新 crash（非零退出 40 行均系已分类非 fuzz finding）；**properties 145.4h（201.9%）、yaml 128.8h（178.9%）、ini 124.8h（173.3%）、hcl 95.5h（132.7%）、json 95.3h（132.3%）五单位已过 72h 门槛**；toml 57.7h（80.2%）、protocol-decode 50.7h（70.4%）、plist 47.4h（65.8%）、xml 35.0h（48.6%）仍开放 | §28.5 条件 3（P0/P1=0 的 fuzz clean-run 证据完整性，路线图 §22.4） | **阻塞 §28.5 通过**（Q-7 未闭）；不依赖其他四要素 |
| C-3：真实发布密钥与 1.0.0-rc.1 发布执行 | partial（演练密钥仅流程验证；默认 keyring 无真实密钥；docs/release 仅 0.8.0 演练产物；D-1/D-2 处置随本项） | §28.5 条件 5（生产发布物可验证/可重建/可升级——发布物、SBOM、签名、checksum、build provenance 真跑）；§28.4 条件 6 的供应链侧 | **阻塞 §28.5 通过**；D-1 要求"manifest 必须从干净发布 commit 重新生成"（rc-1.0.0-candidate.md）与 F-B 同源纪律（干净 checkout 复现） |
| RC soak 阶段 1（磁盘失败、部分权限失败演练、differential 追加、Go RC fuzz 记录、corpus 巡检、性能复测） | 部分权限失败演练已闭环（rc-1.0.0-candidate.md §3.5 演练 4，2026-08-10）；磁盘失败演练环境阻塞（演练 5；C-1 已闭环 2026-08-11 后 Linux runner 完成路径可用，演练本身仍待执行）；differential 追加、Go RC fuzz 记录、corpus 巡检、性能复测状态按 rc-1.0.0-candidate.md §4.1 | §28.5 条件 6（failure/limits 演练完整性，§22.7"stale/部分权限/中断/磁盘四类演练"——仅磁盘失败未记录，部分权限已闭环） | 阻塞 §28.5 的 RC 收口（RC soak 本身是 §16.6 硬门禁的法定例外） |
| Go CLI 合入后的 cross-language exchange 复跑（P2-7） | 已闭环（2026-08-10，rc-1.0.0-candidate.md：G5.6 合入后四 harness 复跑 83/83 + 108/108 + 68/68） | §22.2（rc-1.0.0-candidate.md 边界）→ §28.5 条件 4 的 CLI 侧核对 | 不阻塞（SDK 面 83/83 已实测；CLI 侧已闭环） |
| 版本推进 `1.0.0-rc.1`（F-A） | 已随 2209582 提交（consema-rs/Cargo.toml 的 workspace version / consema-go/go/cmd/consema/version.go——行号可能漂移，以字段名为锚）并通过两语言门禁（审计实测） | §28.5 条件 5 的发布准备、C-3 阶段 0 执行 | 不阻塞（F-A 已修复，§5.1） |
| vector 聚合 digest 干净 checkout 不可复现（F-B，提交态） | 已修复（2209582）：干净 LF checkout 重算 35bebc8d… 并回填 fc-manifest digests.conformance_suite 与 conformance_test.go（行号可能漂移，以字段/符号名为锚），与 D-1 纪律合并记录（一切门禁证据以干净 checkout 为准） | §28.5 条件 5（可重建证据）、C-1（go-1-26 job）、fc-manifest"值可精确复现"声称 | 不阻塞（已修复；C-1 推入与 C-3 发布按原路径执行） |

其余开放项（B-1/B-2/B-3/B-5/B-7/B-8 backlog、P2-1..P2-6 发布判断清单、BENCH-NOHARNESS 等）均为文档化边界或带 judgment 的 P2，不依赖任何 §28 通过条件，随 1.0.0 窗口处置。

---

## 3. 历史 findings 关账清单

### 3.1 0.13.0 五维交叉审计（commit 8b5c738 "Land 0.13.0 with the five-dimension cross-audit closure" + 92a244a round-2）

| ID | 描述 | 分级 | 修复 commit | 关账状态 |
|---|---|---|---|---|
| P1-1 | README convert-request.json 示例损坏 JSON（与 cookbook 不一致） | P1 | 8b5c738（README.md 示例重写为与 cookbook 逐字节一致） | 关闭（本记录核验：README.md 示例现为合法 canonical JSON） |
| P1-2 | Go core 值模型 8→15 kind 契约缺口（PVCE 七新标签缺失） | P1 | 8b5c738（go/core 15-kind 全契约；golden 向量经 Rust 编码器验证、既有冻结字节零变动；RFC 0016 §4.1 修订） | 关闭（byte parity 68/68 重跑通过） |
| P1-3 | EncodeJSON 根节点重复计数边界错误 | P1 | 8b5c738 | 关闭 |
| P1-4 | graph builder 非法 UTF-8 未拦截 | P1 | 8b5c738（go/graph utf8 拦截 + 测试） | 关闭 |
| P1-5 | 协议覆盖缺口（canonical JSON 解析器 numberToken/unicodeEscape 路径无测试、不可达论证缺失） | P1 | 8b5c738（go/protocol/canonical.go 覆盖测试 + 不可达论证） | 关闭 |
| — | round-2 findings：human-mode 失败零 stdout 字节、apply env seam 文档化、`json.projection.incomplete-document@1` 注册进 v7（186→187）、typed `WriteError::ReadBackMismatch`、locale-stable 信封、RFC §4.4 示例字节修正、mutation-corpus regression 工作流修复、yaml compose eager-span 性能（~26-29×） | P1/P2 混合 | 92a244a | 全部关闭（v7 187 code 断言实测通过，cli_m4.rs） |
| M2-F1 | fuzz：Recovered JSON 文档被 project/edit 接受（错误完成状态） | P1 | 094f5d1（RecoveredDocument 门，projection.rs / edit.rs；严格断言 operation_fuzz.rs） | 关闭 |
| M2-F2 | fuzz：yaml 引号 `"~"` 标量解码为空（静默损失） | **P0** | 094f5d1（exact_empty_scalar 仅 plain 样式；trip-wire property_graph.rs） | 关闭（trip-wire 计数即失败） |
| F-2 | yaml 335 KB 转换超线性（69.4 s） | P1 | 094f5d1（RawByteResolver 单遍偏移，offsets.rs） | 关闭（复测 1.01 s，~69×；pilot-go §5 再次复核线性） |
| B-6 / B-9 | java-properties 源 convert/project 不可达（bug）；`inspect --profile` 格式本地 code 诊断 exit 5 内部错误（bug） | P1 | 92a244a/8b5c738（project_cmd.rs 族前缀特例；inspect.rs fallback 绑定） | 关闭（回归测试矩阵） |
| F2/F3/F4/F10/F11/F13/F15 + 2 philosophy | API 命名漂移（注册 code / 枚举名 / 拼写） | P2 | exempt-with-reason（全部被 RFC + vector 冻结；修复窗口 semantic-model v8 / 1.0.0 API 冻结） | 关闭（豁免类，已入 fc-manifest known_accepted_limitations） |

### 3.2 0.14.0-0.19.0 Go 里程碑审计发现

| ID | 描述 | 分级 | 修复 commit | 关账状态 |
|---|---|---|---|---|
| G0 审计 P1 | graph-domain distinct-by-identity 语义（(parent, ordinal)，consema-rs/consema-graph/src/query.rs）；portable-domain identity 经全路径 | P1 | 7f9c3c1（最小反例回归） | 关闭 |
| G1.1 finding | records_source.go 5 个未注册 wire code（core.source.patch-*）映射错误 | P1 | 372d182（remap 到注册 code，与 Rust 一致） | 关闭 |
| 差分 harness findings | 外族源 parse 失败不统一（invalid-sequence@1）；query 参数缺失/错误不统一（invalid-argument@1）；非法 UTF-8 escape 损失语义不标准；compareFacts 接受重复键；operations default 分支非显式失败；**registry-v3/protocol-v3-dual-transport 死 case label 误跳为 documented skip（协议 suite 覆盖缺口）** | P1 | 8d9c567（含 4 个新负向 case 钉死 U+FFFD 语义） | 关闭（"protocol 线格式/覆盖缺口"类 findings 的最完整仓库记录：另一处为 0.13.0 P1-5；两处均关闭） |
| yaml anchor-dependency | yaml 编辑 anchor 依赖验证过度拒绝（无关删除被拒） | P1 | e420ad7（只收集删除子树，照 Rust edit.rs；3 个回归测试） | 关闭 |
| 结构性债务 | 7 项 drift 统一到 Rust 参考（含 toml/ini/yaml 潜在 UntouchedByteProof 算法分歧）；protocol operator 表 147 行 diff 缺 `ini.duplicate-group` | P1 | e420ad7（108/108 + 68/68 证明零可观察变化） | 关闭 |
| G3.3 finding | plist materialization 失败路径 debug println 残留（污染 stderr） | P2 | 24d6ca2 | 关闭 |
| G4.2 finding | consema-go/go/plist materialization provenance 面缺失（direct/generated 关系） | P1 | 79df437（照 Rust build_provenance） | 关闭 |
| G5.3 exchange findings | core.query-result@1 Native match wire 字段等 6 项（unknown-field、Bytes replacement wrong-type、batch-plan profile_default:null、stale doc comments） | P1 | ada5020（83/83 双向通过；2 个遗留 documented skip 翻转为执行，508 全执行） | 关闭 |
| Go fuzz 4 缺陷（G5.4） | ① plist.binary trailer limit 越界报 false Complete（无 native model、无诊断）② json strict trailing-comma 诊断 category panic ③ yaml plain-block 无限循环（`e0: e0\n s:[a,t`）④ plist.xml 恢复循环 OOB panic + tokenizer 卡死循环 | ①P0（伪成功）②③④P1 | 937b330（回归种子：③ 钉入 yaml/testdata/fuzz/FuzzParse、④ 钉入 plist/testdata/fuzz/FuzzParseXML；① 与 ② 为 fuzz target 内 f.Add 种子——「每个失败输入钉入 testdata/fuzz/」对 4 缺陷中 2 个不成立；①保留 Foundation 冻结事实） | 关闭（30s×16 target clean-run 实测 2026-08-10） |
| G5.5 F1 | §21.2 最低版本 CI 腿未落（go-1-26 job） | P2 | 937b330（ci.yml go-1-26 job） | 关闭（F-B 已修复，该 job 不受影响） |
| D-1 / D-2（G5.7 drill） | 0.8.0 checksum manifest 从 git 历史不可复现（脏树记录，0/14 匹配）；演练密钥无持久公钥 | P1（发布流程） | 处置已定：0.13.0 发布时从干净发布 commit 重新生成 checksum manifest（release-process §7 items 3+5）；真实密钥+备份随 C-3 | **待 C-3 关闭**（非代码缺陷，流程证据缺陷） |
| L5 差分 harness findings（TS/Python/Kotlin） | 跨语言 exchange 发现的 wire-codec 缺陷：ValuePath schema-less wire 格式与 AssociationLocation 位置面缺失（TS/Python）；materialization-request version:0 拒绝语义缺失（TS/Python/Kotlin）；yaml tag `'!'` 前缀与 yaml provenance ordinal/role 缺失（Python） | P1 | 2f981df（L5 差分 harnesses + 修复）+ dbba9a4（CI 验证收口） | 关闭（三语言 differential 83/83 exchange 全绿；conformance 508/508 不变） |

**P0/P1 清零声明核验**：全周期 P0（M2-F2、Go fuzz ①）与 P1 全部修复并有回归钉死；关账后新增的 **F-A**（§5.1）与 **F-B**（§5.2）两项 P1 级证据缺陷已于 2209582 处置并审计验证——"无未解决 P0/P1"的声明恢复成立（§18.4）。

---

## 4. 本次核验实测记录（2026-08-10，Windows 11，go 1.26.5 / cargo 1.97.1）

核验对象：提交态 74e336e（历史提交，当时 Rust workspace 0.13.0 / Go CLI product_version 0.19.0）。本表为修复前实测记录——F-A/F-B 已由 2209582 处置并审计验证。本表 `scripts/go-verify-*.ps1` 引用指当时母仓 `scripts/` 下的脚本（六仓拆分后迁至各语言仓 `scripts/`，母仓残留副本已于 2026-08-13 删除）。

| # | 命令 | 结果 | 对应声称 |
|---|---|---|---|
| 1 | `go test -count=1 ./...`（worktree） | 18 包 ok / 1 包 FAIL（`conformance`：**digest 35bebc8d… ≠ 记录 e3d6578858…**，即 F-B）；其余全部 ok，含 cmd/consema e2e（5.439s）、pilot（1.395s）〔修复前实测记录——F-B 已由 2209582 处置（回填 35bebc8d…）并审计验证〕 | consema-go/README "all green" 在**本机 CRLF 工作树**成立；干净 checkout 下 F-B 使 conformance 包红 |
| 2 | runner 计数探针（worktree 临时测试文件，用后删除） | **TOTAL=508 PASSED=508 SKIPPED=0 FAILED=0**；DIGEST_OK=false | consema-go/go/README.md 的 0.18.0 历史态（「506 passed / 2 documented skips / 0 failed」，见 Capability parity 节；该历史态未标注后续 G5.3 翻转——ada5020 已将 2 个 skip 翻转执行为 508 全执行，consema-go/go/README 已注明演进；本探测 508/0/0 与翻转后口径一致） |
| 3 | `go test -count=1 -run TestCapabilityParity ./` | PASS（OperationSets + NoRustOnlyMandatoryBehavior） | capability parity 硬门禁（consema-go/go/README.md 的「Capability parity」节，74e336e 树 :797 / 现行 :878；行号可能漂移，以锚为准） |
| 4 | `gofmt -l .`、`go vet ./...`、`go build ./...`、`go mod tidy` | 全干净 | §6 门禁（go-implementation-plan.md） |
| 5 | `go test -race -count=1 ./conformance/...` 及其余包 | 全 ok（唯一 FAIL 系核验临时文件删除时序所致，已复跑确认） | race 门禁 |
| 6 | `cargo test -p consema-conformance --release --locked`（worktree） | exit 0；26 个 test binary 全 ok，179 passed / 0 failed（18 套 suite runner 全部 conformant） | Rust conformance 508/508 + 计数断言 |
| 7 | `cargo test --workspace --locked`（worktree） | exit 0；63 个 test binary 全 ok，1,629 passed / 0 failed | CHANGELOG.md 的 workspace 全绿（0.13.0 记录 1,617；当前提交态 1,629，增量来自 0.13.0 后 conformance 域） |
| 8 | `cargo fmt --check`（worktree） | 干净 | fmt 门禁 |
| 9 | `scripts/go-verify-byte-parity.ps1` | **byte parity 68/68 equal（51 pvce + 17 pgce），exit 0** | §16.1/§22.2 PVCE/PGCE byte-exact |
| 10 | `scripts/go-verify-normalized-differential.ps1` | **108/108 forward + 108/108 reverse，exit 0** | §22.2 normalized 结果一致 |
| 11 | `scripts/go-verify-protocol-exchange.ps1` | **40/40 accept + 43/43 reject（双向），exit 0** | §22.2 protocol cross-encode/decode 100% |
| 12 | `scripts/go-verify-shared-conformance.ps1` | **步骤 [1/6] digest 校验失败**（35bebc8d… ≠ e3d6578858…）→ F-B〔修复前实测记录——修复后 recorded=35bebc8d…（LF 口径），干净 checkout 通过、本机 CRLF 树差异属文档化行为〕 | G5.1 "independent aggregate digest check" 仅在本机 CRLF 工作树成立 |
| 13 | 主树聚合 digest 复算（PowerShell，文档化算法） | 本机 CRLF 工作树 = **e3d6578858…**（与当时记录一致）；干净 LF checkout = **35bebc8d…**〔修复前实测记录——修复后 recorded=35bebc8d…（LF 口径），干净 checkout 通过、本机 CRLF 树差异属文档化行为〕 | fc-manifest 第 35-41 行"值可精确复现"声称在干净 checkout 不成立 |
| 14 | 主树 `go test -count=1 ./...` | conformance ok（CRLF digest 命中）；**cmd/consema FAIL**（panic：e2e_test.go:442 `first[:len(first)-1]`，first 为空）→ F-A〔修复前实测记录——F-A 已由 2209582 处置并审计验证；历史记录，锚以处置注记为准〕 | 工作树 1.0.0-rc.1 版本推进破坏 envelope |

未重跑、引用最近实测记录（注明日期）：Go 16 fuzz targets 30s clean-run 与 8×2 benchmark（2026-08-10，consema-go/go/README.md 的「Release-candidate fuzz clean-run」节，74e336e 树 :661 / 现行 :724；「Benchmark baseline」节，74e336e 树 :745 / 现行 :819；行号可能漂移，以锚为准）；Rust fuzz 账本已续跑至 session 79 在途——runs.csv 13,005 行 / 79.427 CPU-hours（截取自 session 79 期间，2026-08-10；session 78 结束快照 12,937 行 / 78.971 CPU-hours、15:53:39；最接近格式 properties ≈20.6%；fuzz-evidence-0.13.0.md §3.2.1/§8，runs.csv 为唯一权威账本）；mutation corpus 174,921 case replay（2026-08-07，63.10s；原始输出未保留、时长不可复算——见 fuzz-evidence-0.13.0.md §8 证据链说明）；coverage 86.51/82.82/87.91（2026-08-07）；cargo audit 1,189 advisories / 0 漏洞、deny 四段（2026-08-07）；Linux/macOS 矩阵（从未实测，= C-1）；macOS Foundation differential 7 cases / 35 legs（0.17.0 记录）。

---

## 5. 本次核验新发现（F-A/F-B，均已由 2209582 处置并审计验证；本节保留修复前历史记录）

### 5.1 F-A（工作树版本推进回归）— 已于 2209582 修复

- **当前状态（已修复）**：按原选项 (a) 执行——RFC 0015 §3.3 已修订（docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md，
  2026-08-10 revision）：product-version 校验从严格 `MAJOR.MINOR.PATCH` 扩展为完整 SemVer 2.0 core 语法，
  接受 pre-release 后缀（`1.0.0-rc.1`、`1.0.0-beta.2`），其余约束不变（无 git hash、无 build metadata，
  `+` 后缀拒绝）；未动 v8 窗口，cli-v1 向量保持有效（RFC 0015 修订块明示 "the cli-v1 vectors pin no
  prerelease rejection, so the vectors stay valid"）。两语言校验器已放宽：Rust `is_semantic_version`
  （consema-rs/consema-protocol/src/cli.rs——行号可能漂移，以符号名为锚）与 Go `isSemanticVersion`（consema-go/go/protocol/cli.go——行号可能漂移，以符号名为锚），
  错误文案现为 "expected MAJOR.MINOR.PATCH[-prerelease] without leading zeros or build metadata"
  （cli.rs / cli.go——行号可能漂移，以符号名为锚）。`1.0.0-rc.1` 已提交（consema-rs/Cargo.toml 的 workspace version / consema-go/go/cmd/consema/version.go——行号可能漂移，以字段名为锚）。
  审计验证：cargo test -p consema-protocol 100 passed；go test ./cmd/consema 108 passed。
- **修复前状态（历史记录）**：
  - 现象：主树 `go test -count=1 ./...` → `cmd/consema` 包 panic（e2e_test.go:442 空 stdout 切片越界〔历史记录，锚以处置注记为准〕）；
    手动 `consema inspect --json` → exit 5 `core.protocol.invalid-value@1 at $.product_version:
    expected MAJOR.MINOR.PATCH without leading zeros`。
  - 根因：工作树把 `consema-rs/Cargo.toml`（workspace version）与 `consema-go/go/cmd/consema/version.go`（productVersion）从
    `0.13.0`/`0.19.0` 推进到 `1.0.0-rc.1`；而当时 Rust `is_semantic_version`（cli.rs）与 Go
    `isSemanticVersion`（cli.go——行号可能漂移，以符号名为锚）都是严格 `MAJOR.MINOR.PATCH`（无 pre-release 后缀），RFC 0015 §3.3
    与 RFC 0020（当时为未跟踪文件）均未修订该格式。提交态（0.19.0）对应测试当时全绿（实测 #1）。
  - 影响（当时）：若按当时工作树构建 RC-1，Rust 与 Go CLI 的每个信封命令都会 exit 5（错误完成状态，
    §18.4 P1 级）；Go CLI e2e 套件崩溃。C-3 阶段 0 与任何 RC 构建前必须处置。

### 5.2 F-B（提交态 vector 聚合 digest）— 已于 2209582 修复

- **当前状态（已修复）**：按原选项 (a) 执行——从干净 LF checkout 重算 digest = **35bebc8d384d…**，已回填
  fc-manifest-0.13.0.json digests.conformance_suite（`aggregate_sha256` 字段——以字段名为锚，行号可能漂移）与 consema-go/go/conformance/conformance_test.go（行号可能漂移，以符号名为锚）
  （recorded），两处实测一致；fc-manifest:41 note 已注明规范 checkout（LF）为权威口径、历史 CRLF 值被取代。
  审计验证：干净 LF worktree 上 go test digest 断言 PASS、手工复算 MATCH、shared-conformance 脚本 6/6 exit 0。
- **补注（本机差异，文档化）**：本机 CRLF 工作树（`core.autocrlf=true`）上仍算出 e3d6578858…，属文档化
  本机差异（rc-1.0.0-candidate.md 同述）；规范 checkout（LF）为权威口径，CI 不受影响。
- **修复前状态（历史记录）**：
  - 现象：干净 checkout（LF，`.gitattributes` 第 1 行 `* text=auto eol=lf`）下
    `consema-go/go/conformance` 的 `TestRunIsConformant`/`TestDigestAlgorithmMatchesManifest` FAIL、
    `scripts/go-verify-shared-conformance.ps1`〔当时母仓 scripts/ 持有，拆分后归 consema-go/scripts/〕步骤 [1/6] FAIL：computed `35bebc8d384d…` ≠
    recorded `e3d6578858fa1f…`（18 suites / 508 cases 计数不受影响）。
  - 根因：记录值 e3d6578858… 是在 2026-08-07 的 **CRLF 工作树**（本机 `core.autocrlf=true`，主树文件磁盘为
    CRLF）上按文档化算法算出的；git 提交内容为 LF（`git show HEAD:conformance/vectors/cli-v1.json` 实测 LF）。
    干净 checkout 产出 LF，逐文件 sha256 即不同 → 聚合 digest 不同。记录值只在"与记录机 checkout 状态相同"
    的机器上可复现，与 fc-manifest 第 40 行"值可精确复现"与 §28.5"可重建"声称不符。
  - 影响（当时，P1 级）：(a) C-1 的 go-1-26 CI job（ci.yml:321-331，`go test ./...` 于 ubuntu）在干净
    checkout 必红，C-1 完成路径硬阻塞；(b) 任何第三方 clone 复跑 shared-conformance 脚本必红；(c) 与 D-1
    同源纪律（"manifest 必须从干净发布 commit 重新生成"）在 vector 域同样适用。

---

## 6. 结论

### 6.1 五要素判定

| 要素 | 判定 | 一句理由 |
|---|---|---|
| §28.1 哲学统一 | **PASS** | 六条通过条件全部成立；无开放项依赖 |
| §28.2 语义一致 | **PASS** | 18 概念在 registry 与跨语言面上行为一致；命名漂移全部冻结、属 1.0.0 窗口命名清理而非语义不一致 |
| §28.3 逻辑自洽 | **PASS** | 三条操作链闭合、无隐藏同步、无权威循环（byte 权威单一 = Rust 编码器 + 双向差分反审计） |
| §28.4 真实有效 | **PASS** | corpus/迁移/pilot/零静默损失全部实测成立；供应链流程落地（真跑归 §28.5 口径） |
| §28.5 完整可靠 | **PARTIAL** | 实测 508/0/0、1,629 Rust 测试、108×2/68/83 全过（提交态 74e336e，历史记录）；F-A/F-B 已由 2209582 处置并审计验证；PARTIAL 理由：C-2/C-3 未关闭（partial）（C-3 含 D-1/D-2）+ RC soak 两项演练未记录（C-1 已闭环 2026-08-11，run #5 132/132 全绿） |

### 6.2 1.0.0 前剩余收口项（按依赖序）

1. **修 F-A**（工作树版本推进回归）——已验证（2209582，审计 PASS）：RFC 0015 §3.3 修订接受 pre-release
   后缀、两语言校验器放宽、1.0.0-rc.1 提交（cargo test -p consema-protocol 100 passed；go test
   ./cmd/consema 108 passed）；
2. **修 F-B**（vector digest 复现性）——已验证（2209582，审计 PASS）：从干净 LF checkout 重算并回填
   fc-manifest 与断言，与 D-1 纪律合并为"一切门禁证据以干净 checkout 为准"（干净 LF worktree 上 digest
   断言/复算/shared-conformance 6/6 全绿）；
3. **C-1**：推入 GitHub 真跑 10 job 全矩阵；回填 manifest——**已闭环（2026-08-11，run #5 132/132 steps 全绿（增补前 10+1 job，11 定义/17 次执行），head 437fd35，windows/ubuntu/macos；go-differential 2026-08-12 增补后 ci.yml 为 10+2 job/12 定义；结果已回填 fc-manifest，C-1 → closed）**；
4. **C-2**：每格式 72 CPU-hours fuzz 账本（clang 主机 cargo-fuzz 为主）；
5. **C-3**：真实密钥 + 备份 + 吊销证书；从干净发布 commit 按 release-process §7 十项顺序执行发布
   （checksum/SBOM/签名/tag/恢复演练复跑）；
6. **RC soak 阶段 1**：磁盘失败与部分权限失败演练（§22.7）、differential 追加、Go RC fuzz 记录、corpus 巡检、
   性能复测（每 48h 查 fuzz 账本）；
7. **P2-7**：Go CLI 合入后 exchange 复跑闭环——已闭环（rc-1.0.0-candidate.md，2026-08-10）；
8. 处置完成后重跑本终审：§28.5 条件 3/5 转 ✓ 即五要素全 PASS，进入 §29 最终确认。

### 6.3 诚实声明

- 三平台矩阵：Windows 本地实测，Linux/macOS 腿已随 C-1 闭环（2026-08-11，run #5 windows/ubuntu/macos 全矩阵全绿）；72 CPU-hours 账本已续跑至 session 79 在途（runs.csv
  13,005 行 / 79.427 CPU-hours，截取自 2026-08-10 session 79 期间；session 78 结束快照 12,937 行 /
  78.971 CPU-hours，15:53:39）；
- F-B 已修复（2209582）：干净 LF checkout 重算 35bebc8d… 并回填，"记录值在记录机（CRLF）复现"与
  "干净 checkout 不可复现"两侧差异现为文档化本机行为（§4 第 12/13 行，rc-1.0.0-candidate.md），
  规范 checkout 绿、CI 不受影响；
- F-A 已修复（2209582）：RFC 0015 §3.3 修订接受 pre-release 后缀，1.0.0-rc.1 已提交；本核验时点提交
  `74e336e`（历史）的 Go CLI 与 Rust 全部门禁实测通过（§4 第 1/6/7 行）。
- 附注（随本次文档修复）：consema-go/README.md "productVersion defaults to the Go milestone version `0.19.0`"
  文案陈旧（consema-go/go/cmd/consema/version.go 的 productVersion 现为 1.0.0-rc.1——行号可能漂移，以字段名为锚），已随本次文档修复同步修正（consema-go/README.md §Version）。

---

## 7. 五语言扩展审计（2026-08-12）

- 范围：五维交叉审计（哲学统一/语义一致/逻辑自洽/真实有效/完整可靠）在五语言面上执行，
  对应 §28 五要素 × 五语言（2026-08-11 用户决策：TS/Python/Kotlin 与 Rust/Go 同等地位，
  docs/multi-language-implementation-plan.md；五语言 CI 架构见 docs/five-language-ci-design.md）
- 审计对象 = 2026-08-12 工作树（三语言 L0-L5 全闭环 + 五语言 CI 全绿之后，dbba9a4）
- 判定体例照 §1-§6（表 + 判定 + 证据 file:line 或实测记录）

### 7.1 五维度 × 五语言审计结论

| 维度 | 判定 | 结论要点 |
|---|---|---|
| 哲学统一 | **PASS** | P1 python yaml `Document` 未 frozen 已修（consema-py/python/src/consema/yaml/document.py，本批次）；P2 TS `bytes()` 已修（consema-ts/typescript/src/document/source.ts，本批次）；P2 信息性 python 公开构造器记录在案（文档化，接受）；§1.1 六条既有结论在五语言面无新增反例 |
| 语义一致 | **PASS** | P1 Go 差分 gate 未接 CI 已修（consema-go ci-go.yml 新增 go-differential job，consema-go/scripts/go-verify-*.ps1 三 harness 进 CI，2026-08-12）；P2 Go/Kotlin 差分计数改精确（differential 测试计数断言，本批次）；P2 PortableGraph 别名统一（consema-go/go/graph、consema-ts/typescript/src/graph、consema-kt graph，本批次）；**187 error codes / 41 contracts 五语言注册表集合互差为 0（实测）** |
| 逻辑自洽 | **PASS** | 五语言 read/query/project、materialize/convert、edit/patch/apply 链闭合均以共享向量 508/508 为界（2026-08-12 审计时点基线——P2-B 补强后现行 519 cases / digest cfd6e296，见真实有效行；§1.3 六条在五语言面复验，无新增反例）；字节权威单一（Rust 编码器）与星型差分拓扑（Rust 锚居中，five-language-ci-design.md §2.3）不构成权威循环 |
| 真实有效 | **PASS** | 18 套 suite / 519 cases 与聚合 digest cfd6e296… 五 runner 复算一致；**132/132 steps 于 2026-08-12 经 GitHub Actions API 在线核实**（run #5，head 437fd35：17 次 job 执行 / 132 steps / 0 failed）；fuzz 快照 **62,432 行 / ~460 CPU-hours 复算**（2026-08-12 10:17 快照，追加式账本以 runs.csv 为准；现行账本 122,477 数据行 / 780.529 CPU-hours，2026-08-13 复算）；零依赖声称四语言（Go/TS/Python/Kotlin）全实（go.mod 零 require / npm ls --omit=dev 空 / pyproject dependencies=[] / kotlin runtimeClasspath 仅 kotlin-stdlib 2.2.0 及其传递 org.jetbrains:annotations——KGP 默认注入，非空）；P2 陈旧声称清单已修（§7.2 处置表） |
| 完整可靠 | **PARTIAL**（与 §28.5 同口径） | P1 根 CHANGELOG 已补五语言时间线（2026-08-12）；P2 三语言 README 已建（consema-ts/README.md、consema-py/README.md、consema-kt/README.md）；git 卫生零问题（5a040be purge 后无构建产物入库；.gitignore 覆盖 kotlin/build、node_modules、__pycache__、venv）；遗留项与 five-language-ci-design.md §10 声称一致（shared-conformance 脚本随 runner-CLI 批次、L-package、3-OS 矩阵处置仍为未来项）；§28.5 判定不变——C-2/C-3 未关闭（partial） |

### 7.2 五语言扩展审计 findings 处置表

| 维度 | 分级 | 描述 | 处置 |
|---|---|---|---|
| 哲学统一 | P1 | python yaml `Document` 可变（未 frozen，与不可变 Document 哲学相悖） | 已修（consema-py/python/src/consema/yaml/document.py，本批次） |
| 哲学统一 | P2 | TS `bytes()` 构造语义与其余语言不一致 | 已修（consema-ts/typescript/src/document/source.ts，本批次） |
| 哲学统一 | P2 | python 公开构造器信息性语义未记录 | 记录在案（文档化，接受；不构成语义漂移） |
| 语义一致 | P1 | Go 差分 gate 未接入 CI（consema-go/scripts/go-verify-*.ps1 仅本地执行 + 文档化完成路径） | 已修（consema-go ci-go.yml 新增 go-differential job，2026-08-12；§0.1「未接入 CI」表述随之过时） |
| 语义一致 | P2 | Go/Kotlin 差分测试计数断言不精确 | 已修（差分计数改精确，本批次） |
| 语义一致 | P2 | PortableGraph 别名面五语言不一致 | 已修（别名统一：consema-go/go/graph、consema-ts/typescript/src/graph、consema-kt graph，本批次） |
| 语义一致 | — | 187 error codes / 41 contracts 五语言注册表集合 | 互差为 0（实测；语义面与 §1.2 结论一致） |
| 真实有效 | P2 | 陈旧声称清单（版本推进 0.8.0、C-1 未真跑、ci.yml job 计数未反映 go-differential 增补、consema-go/README「无 Go job」、consema-kt ci-kotlin.yml 注释引用 gitignored 路径等） | 已修：根 CHANGELOG（五语言时间线补录 + C-1 closed）、根 README（0.8.0→1.0.0-rc.1、五语言共同证明、三语言一句）、consema-go/README（F1 closed、506/2 skip 历史态注记、Go job 如实化）、fc-manifest（product_version 1.0.0-rc.1、msrv/矩阵真跑）、five-language-ci-design §10（零 skip 断言分语言状态、go-differential 记录）、consema-kt 的 ci-kotlin.yml 头注释（指向 kotlin/verify/TestShim.kt 与直驱 K2JVMCompiler） |
| 完整可靠 | P1 | 根 CHANGELOG 未覆盖五语言时间线 | 已补（2026-08-12，a0c318b/5cf680b+cd26af3/2f981df/dbba9a4/c6c89bb/8d00c4f 六条目） |
| 完整可靠 | P2 | 三语言目录无 README（consema-go/README 有而 TS/Python/Kotlin 无） | 已建（consema-ts/README.md、consema-py/README.md、consema-kt/README.md，2026-08-12） |

**§7 结论**：五语言面上哲学统一/语义一致/逻辑自洽/真实有效 **PASS**（findings 全部处置），完整可靠 **PARTIAL**（与 §28.5 同口径：C-2/C-3 未关闭（partial））；五语言扩展未改变 §6.1 判定。

---

## 8. 第三轮六仓全内容交叉审计（2026-08-13，1.0.0-rc.1 候选期）

- 触发：`/loop` 收口循环（2026-08-12 晚启动）——"整个项目所有内容通过多要素交叉审计：哲学统一、语义一致、逻辑自洽、真实有效、完整可靠"
- 范围：**六个仓库全部文件**（母仓 consema + consema-rs/go/ts/py/kt），8 个并行审计员（母仓 docs 域 / 母仓 conformance+CI 域 / 五语言仓各一 / 跨仓一致性），全部只读静态审计 + 独立复算 + GitHub Actions API 在线核验
- 审计基线：母仓 HEAD d1bda22；语言仓 HEAD rs 16d4181 / go dabe4f3 / ts fc67a4c / py 2a825af / kt 1e2f3da
- 判定体例照 §1-§7；本批为第二轮的增量全量复核（第二轮覆盖至 dbba9a4）

### 8.1 五要素判定（第三轮）

| 要素 | 判定 | 结论要点 |
|---|---|---|
| 哲学统一 | **PASS** | 六仓无反例：不可变 Document（py frozen dataclass/slots、TS 防御性拷贝、kt immutable、go Completed objects）、显式操作、CLI 默认拒绝、零依赖面（go.mod 零 require / npm 零 prod dep / pyproject dependencies=[] / kt 运行时仅 kotlin-stdlib 2.2.0 及其传递 org.jetbrains:annotations——KGP 默认注入）全部实测成立 |
| 语义一致 | **PASS** | 519 cases / 聚合 digest cfd6e296… 在五仓全部独立复算命中（母仓 + go/ts/py/kt；含 TS runner 字节级复算——consema-rs 的 conformance job 校验 vendored 聚合 digest（cfd6e296）与 suite-count 18/519）；187 codes / 41 contracts 五语言注册表集合互差 0；差分 68/108/83 精确钉死；oracle 36 项实测 |
| 逻辑自洽 | **PASS** | 三操作链以共享向量为界闭合；Rust 编码器字节权威 + 双向差分反审计无权威循环；六仓拆分计数 179/26/5/7/7 逐仓复算命中 |
| 真实有效 | **PARTIAL** | 核心数字（519/cfd6e296/132 steps/179-26-5-7-7/版本 1.0.0-rc.1）全部为真；P2-B 后 508/35bebc8d 清扫不彻底（本批已全库清零——波 4 勘误：RFC 0016 §1/:24 与 §7/:208 两处 508 引用当时无历史快照注记，属未清零残留；已由波 4 加注，见 RFC 0016）；consema-rs 自有 CI fmt 全红（run#31，本批已修复待推绿）；docs-site 已部署（Pages 启用，docs-site run#3 700fa44 build/deploy/check 全 success，2026-08-13） |
| 完整可靠 | **PARTIAL** | 与 §28.5 同口径：C-2（fuzz 账本累计中，properties/yaml/ini 已过 72h 门槛）与 C-3（真实发布密钥）未关闭；consema-go 文档化共享 conformance 验证路径 508 断言已修（P1 关闭） |

### 8.2 findings 处置汇总（本批）

| 仓 | P1 | P2 | P3 | 关键处置 |
|---|---|---|---|---|
| 母仓 | 1 | 12 | 3 | fc-manifest 证据行号迁移至六仓布局（evidence_note + 13 处引用更新）；README 18/508→18/519；six-repo-split §6 同步 519/cfd6e296 + job 计数 + rs vendor 机制如实化；five-language-ci-design 行号/oracle 计数 72/JSON5 口径/kotlin jar 供给/版本政策行；corpus runbook 钉值 519/cfd6e296；release-process §7 产物名 1.0.0-rc.1；docs-site 三副本同步；coverage.ps1 508→519；stale.yml 权限收窄；mutation-v1.json tool 字段路径 |
| 母仓 | — | 1 | — | rc-soak-stage1-differential.md 死脚本引用 + 508 计数（round-4，2026-08-13：母仓 13 个 `*-verify-*.ps1` 删除、计数 508→519、runbook 指向各语言仓脚本） |
| consema-rs | 0 | 3 | 5 | README job 计数 9→11、ctrlc 依赖如实化、vendored conformance/README 重新 vendor；**cargo fmt 4 文件修复（CI run#31 全红根因，fmt --check 归零）**；gen_mutation_corpus tool 字符串同步；run_waves.ps1 已入库（d97a038，2026-08-13） |
| consema-go | 1 | 4 | 3 | **shared_run_test.go 508→519（文档化验证路径必红修复）**；SECURITY.md 依赖门禁段改编；ci-go.yml 头注释 3→6 job；README 旧 fuzz 表注记；.gitignore provision 数据忽略 + CONTRIBUTING 本地 provision 步骤 |
| consema-ts | 0 | 3 | 5 | "fmt" 虚假声称三处清除（README/job 名/CONTRIBUTING/CHANGELOG）；SECURITY.md 误挂 Rust 证据改为本仓真实机制+规范仓指针；**包版本 0.14.0→1.0.0-rc.1 统一**（用户决策 2026-08-12）；*.tgz 忽略 |
| consema-py | 1 | 4 | 3 | **版本 0.14.0→1.0.0-rc.1 统一**（pyproject/__init__/README/bug_report，check-version 门禁两处同步）；compileall 静态门禁落地（job 名如实化）；mojibake 10 处 + BOM 修复（UTF-8 无 BOM 字节验证）；gitignore 补齐；L0-L5 描述更新 |
| consema-kt | 1 | 4 | 4 | **「无 Gradle wrapper」声称 ×2 修复（§7.2 批次遗漏）**；计数 547→572/234→236 静态实测回填；jar 供给记录核实（脚本/CI 如实，仅母仓文档需修——已修）；TestShim.kt 标注 historical + 直驱模式描述重写；L4 标注 15 处→post-1.0.0（F-28.3-1 跟进） |

跨仓新确认：consema-go 未跟踪 conformance//docs/ 为**测试必需 provision 数据**（CI 多仓 checkout 从母仓取数，非第二权威），已 gitignore + 文档化；docs-site 根因 = Pages 未启用（workflow 无 bug）；C-1 证据链 132/132（run#5）在线核实为真。

### 8.3 本批遗留（随后续循环处置）

1. **C-2**：fuzz 账本继续累计（2026-08-12 24:00 快照 84,600 行 / ≈582 CPU-hours；xml 25.7h 最远，全家族 ≥72h 时关账并回填本表）；
2. **C-3**：真实发布密钥 + 备份 + 吊销证书（用户动作）；从干净发布 commit 按 release-process §7 执行（产物名已按 1.0.0-rc.1 更新）；
3. **consema-rs CI 推绿**：fmt 修复待提交推送后验证 run 全绿；
4. **docs-site 部署复核**：Pages 已启用、docs-site run#3（700fa44）build/deploy/check 全 success（2026-08-13）——部署链路已通，后续提交自动部署；
5. RC soak 剩余：磁盘失败演练（Linux runner 路径可用）、Rust 侧性能 -Check 复验（fuzz 关账后空闲执行）。

**§8 结论**：六仓全内容面上哲学统一/语义一致/逻辑自洽 **PASS**；真实有效/完整可靠 **PARTIAL**——本批 P1 全部处置（go 508 断言、py 版本矛盾、fc-manifest 证据行号、rs CI fmt、kt wrapper 声称），P2 全库清扫完成（508/35bebc8d 现行态清零——波 4 勘误：RFC 0016 两处 508 引用当时无历史快照注记，已由波 4 加注，见上）；**round-4（2026-08-13）追加清扫**：differential runbook 死脚本引用（母仓 13 个 `*-verify-*.ps1` 删除、计数 508→519、runbook 指向各语言仓脚本，§8.2 处置表）、CONTRIBUTING 聚合 digest 计数、RFC 0012-0015 Status 冻结、support-policy 五语言化（RFC 0020/SECURITY 同步）、fc-manifest 行号重核与六仓前缀、go/multi-language-implementation-plan 519 口径、C-3 证据更新、ci.yml oracles 注释如实化等（记录见 §8.2 处置表与 docs/fc-manifest-0.13.0.json）；剩余 PARTIAL 仅因 C-2（时间累计）与 C-3（用户密钥）未关闭，另加两项外部待办（rs CI 推绿验证、Pages 部署复核——run_waves.ps1 已随 d97a038 入库、docs-site 已随 700fa44 部署成功）。

---

## 9. 第四轮对抗性审计修复波（2026-08-13，adversarial-audit 常设阶段首波）

### 9.1 触发与执行

- 触发：稳标准常设阶段（用户 2026-08-13 明确要求：每轮修复落地后全仓全内容正反对打，loop-until-dry）
- 方法：adversarial-audit 工作流（9 镜头：母仓文档权威 / 五语言仓全内容 / 跨仓交叉 / 伪证伪门禁 / 逻辑·安全·可复现），Attack→Verify loop-until-dry（dryTarget=3，maxRounds=12）
- 执行：717 agents、零错误、约 3.3 小时、11,833 次工具调用；中途一次外部中断打死 13 个 verifier 导致 round-1 屏障死锁，经缓存恢复路径（resumeFromRunId）救援，仅 14 个 agent 重跑

### 9.2 审计结果

- 确认 **586 条**（P1×26 / P2×560 / P0×0）；seen 607；12 轮触及上限，dryStreak=0 **未打穿**（矿脉为系统模式批量实例，每轮从确认清单扫出新实例；按既定预案收波进修复，修复后重打验证）
- 归并：**170 模式组**（P1 组 20、跨仓组 66、冲突组 1、判断型组 1），586/586 条 1:1 归组零重复零遗漏
- 主要模式家族：行号失效（fc-manifest / 路线图 / go README，约 15%）；六仓拆仓死路径（crates/consema-* 跨仓约 1,400 处、裸 docs/、裸 go/）；SECURITY.md 幻影门禁 9 家族（Rust 事实冒充）；发布路径零验证；run_waves.ps1 证据链缺陷

### 9.3 关键裁决（总指挥）

1. **G124↔G047 冲突组 → 补齐机制**：rs conformance job 加 vendored 聚合 digest 断言（cfd6e296 全值）+ kt 加字面量 digest 步骤与 ref 钉（ad667021 / bd5734ea）（现行：spec 仓钉升为 096e5f8，2026-08-14 对抗审计波 2 修订）；8 处共钉声称 7 处转真不改、1 处（kt kotlin/README）微调 pin 位置表述；
2. **G001 → 方向 (a)**：go.mod 升 1.26 对齐冻结 RFC 0020 §9.2，CI matrix 1.26.x / 1.26.5（现行：1.26.0 + 1.26.5 精确腿，2026-08-14 对抗审计波 2 修订），1.24 表述零残留；
3. **G154 → 文档化**（3 条 P2：rs coverage 平台耦合、wall-clock 断言、go 0.5pp 缓冲，沿用 YAML dry-run 先例）；
4. **G053 → 接受保守方案**（修示例 + CI 编译运行），公开 API 签名变更记 post-1.0.0；
5. **G033 → 5,501 个 fuzz 证据日志解除忽略、随波入库**（12MB，证据可复现性）；
6. **G135/G158/G106 → 六仓统一**：audit 常设化入聚合 needs（rs 形态）、runner CLI 冒烟全语言接线、release tag==HEAD 校验三仓统一。

### 9.4 修复执行

六仓并行修复波（每仓一 agent，最小保守改动、禁自动改写、不提交）+ 跨仓一致性与残留修复波 + 处置：

- **批量 sweep**：crates/consema-* 前缀（rs 49 / go 278 / ts 374 / kt 332 / py 315 处）、裸 docs/ URL 化（go 108 / kt 199 等）、"checked-in case set"→"provisioned case set"、BOM 清零（ts 9 / kt 4）、Go 里程碑戳→L 体系、"not verified" 声称清零（kt 14 文件）；
- **机制类**：rs run_waves.ps1 证据链（FAIL 即停 exit 1 + 账本预检 + 会话锁 + 异步读）、9 个 fuzz/Cargo.lock 补齐、mutation --check 真门禁接线、G116 版本门禁精确匹配（rc→GA 拦截）、kt kotlinc jar sha256 无条件校验、G093 README 栅栏逐字节比对、发布路径测试门禁、零测试下限断言；
- **P0 事件（修复波自引入，非审计确认）**：ts 修复波 G135 引入聚合 needs 引用不存在 job 的断裂（audit / pr-labels 不在 ci-typescript.yml），跨仓复查程序化校验捕获；已按 rs 常设形态修复（npm-audit job 入主 workflow，needs 9 项全部命中同 workflow，missing: NONE）；
- **处置数字**：六仓合计改动文件 ~1,100+（母仓 74+5,501、rs 51+9、go 178+2、ts 261+、py 235、kt 226+146+2），零构建破坏回退；G120 一处契约性回退（RFC 0015 信封 0.12.0 为冻结向量字节，保留并注记）。

### 9.5 全门禁复验（六仓最终树）

| 仓 | 复验结果 |
|---|---|
| consema-rs | cargo test 1,636 passed / 0 failed、fmt --check 干净、digest 复算命中 |
| consema-go | go test 22 包全绿（20 含测试）、四脚本 68/108/83/519 |
| consema-ts | npm test 667、三脚本 68/108/83、needs 程序化校验 missing NONE |
| consema-py | pytest 703 passed / 4 skipped、三脚本 68/108/83 |
| consema-kt | gradle 572 tests 0 fail 0 skip、三脚本 68/108/83、CI digest 步骤复算命中 |
| 母仓 | fc-manifest JSON 校验、digest 复算 cfd6e296、runs.csv 122,477 数据行 / 780.529 CPU-h 复算一致 |

### 9.6 遗留（本波结束时点）

1. **判断型 P2 文档化组（G154）**：已记录在 COVERAGE/README；
2. **post-1.0.0 项**：G053 公开 API 变更、G030 SECURITY YAML 安全姿态段（避免行号连锁漂移）、G087 job 改名对应的 branch protection required checks 手动同步（用户侧动作）、docs-site Pages 部署（用户侧）；
3. **重打审计**：本波未打穿（dryStreak=0），修复落地后按常设阶段要求重打验证，seen 集已持久化。

**§9 结论**：本波确认 586 条（P1×26 / P2×560 / P0×0）全部 1:1 归入 170 模式组并处置落地，零构建破坏回退；六仓最终树全门禁复验通过（rs 1,636 / go 22 包（20 含测试）/ ts 667 / py 703 / kt 572，差分与 digest 复算全部命中）。12 轮 dryStreak=0 未打穿——矿脉为系统模式批量实例，每轮从确认清单扫出新实例；按既定预案收波进修复，修复落地后按常设阶段要求重打验证（seen 607 集已持久化）。

## 10. 第四轮对抗性审计第二波（2026-08-14，修复后重打）

### 10.1 触发与执行

- 触发：波 1 修复落地提交后，按常设阶段要求带持久化状态重打（stateFile loader 机制，2026-08-13 新增：loader agent 把波 1 的 586 条确认归并为模式组级去重上下文）
- 执行：619 agents、零错误、约 5.6 小时、19,953 次工具调用；12 轮触及 maxRounds、dryStreak=0 **仍未打穿**

### 10.2 审计结果

- 确认 **490 条**（P0×1 / P1×12 / P2×477）；seen 510
- 与波 1 对位：**62 条同 (repo,file,line) 复发**（三类根因：sweep 漏同类位置、声称修复但文件未动、修复引入新不实声称），428 条新发现
- P0：ts 包发布形态「源码直发」不可行（node 26 对 node_modules 拒绝类型剥离）→ 改编译产物 dist 发布，干净目录安装实测通过
- 归并：**116 模式组**（P0 组 1、含 P1 组 9、跨仓 67、波 1 复发 32、判断型 1、冲突 0），490/490 全覆盖零遗漏

### 10.3 关键决策与机制

1. **锚点约定（本波核心）**：行号引用失效类约 200 条不再改行号，统一改引稳定锚（§标题 / job 名 / step 名 / 键名 / 符号名），行号删除或括注「以锚为准」；fc-manifest 证据改「7e9de38 快照 SHA + 树内行号」（冻结树永不漂移）；
2. **provision 钉统一升级** ad667021 / 6cfd389 → **096e5f8**（升级前三 commit 向量 18/18 blob 字节全同、cfd6e296 不变、18/519 不变——程序化验证后执行）；
3. **rustc 统一钉 1.97.1**（四语言仓差分 job；rs 自身政策不动）；
4. **G162 SECURITY 口径**：实测 rs 40 个 typed decoder 臂 + Transport 类型化拒绝 = 全 typed 强 claim 属实（母仓 / rs / ts / py 保留）；go / kt 未 ship 记录 envelope 级为合法实现差异（各自注记）；
5. **发布形态**：ts 改 dist 编译产物；npm 11 预发布强制 --tag rc；kt Maven 端点改真实 staging 端点；G71 tag 守卫六仓统一 merge-base --is-ancestor；
6. **判断型 G113 文档化**（wall-clock 记录补齐）。

### 10.4 修复执行

- 六仓并行修复波（116 组按仓派工）+ 跨仓一致性收尾波 + 最终收口波；
- **六仓改动**：母仓 64+5 文件、rs 50、go 40、ts 53+1、py 226、kt 222（含 G77 全量 sweep 331 处裸路径 URL 化）；
- **真实稳性缺陷修复**：rs run_waves.ps1 的 PS 5.1 脚本块回调线程池崩溃（PSInvalidOperation / GetContextFromTLS，WER 实锤 24 次）——改 Add-Type C# 委托异步排空 + ABORT 路径记录；会话 916 无记录终止已诊断归因并写入 fuzz-evidence；
- **波 1 教训内化**：rs 门禁补 cargo doc（波 1 曾 CI 红）；sweep 全量覆盖含源码文件；G67 各语言 conformant() 加执行下限（0 执行即失败）。

### 10.5 验证与状态

- **六仓最终树全门禁复验**（并行执行中 / 已执行）：rs 1,636 tests + cargo doc、go 22 包 + 四脚本、ts 668 + dist pack、py 703 + 三脚本、kt 572 + digest 复算、母仓 JSON + digest + runs.csv 复算；
- **提交**：母仓 096e5f8（波 2 主修复）+ 5269d21（收尾注记）；五语言仓波 2 修复已全部提交——rs 5d010aa、go 81efd45、ts 6edbb12、py 9a84670、kt 53d3e14（本节初稿「待提交」为记录时点快照，已由后续提交覆盖，2026-08-14 更新）；
- **遗留**：release-sign.ps1 正则与 rc.1 tag 冲突（发布时处置，C-3 用户动作）；G70 rustc 政策差异已统一；branch protection required checks 同步（G087 job 改名，用户侧）；docs-site Pages 部署（用户侧）。

**§10 结论**：波 2 修复后仍未打穿（重打 12 轮 dryStreak=0）——按常设阶段继续波 3 重打；P0 已清零（波 2 唯一 P0 已修复），P1 全量处置；锚点约定落地后，行号失效矿脉预期大幅收缩。

## 11. 锚点修复处置注记（2026-08-14，波 3 W3-03 F2）

- **本批修复**：本文件全部裸行号锚改为「§标题/语义句 + 快照 SHA 树内行号」体例（波 3 纪律 3），
  行号括注「行号可能漂移，以锚为准」；含同根因兄弟位置（§1.1 第 2/6 行与 §1.3 第 6 行的
  consema-go/README.md 仓根幻影区间、§1.1 第 6 行 CHANGELOG .env 句裸锚）。
- **重核方法**：逐锚先在自钉核验提交 74e336e 上重核证据指向（`git show 74e336e:go/README.md`、
  `74e336e:CHANGELOG.md`、`74e336e:"Consema 1.0.0 产品路线图与双语言落地设计.md"`），确认语义后再落笔；
  「现行」行号逐条经现行树实测（母仓 ef8d583 / consema-go c150470）。
- **74e336e 复核结论**：旧锚在 74e336e 树上即不成立——go/README 政策 1 句实 :455（非 :460）、
  cgo 禁令实 :771（非 :784）、stdlib-only 实 :501（非 :567）、字节权威实 :588（非 :601）、
  registry v1-v7 计数实 :30-32（非 :35-38）、Capability parity 节实 :797（非 :817-）、
  operation registry 概述实 :430-433（非 :435-436）、clean-run 节实 :661（非 :674-727）、
  Benchmark 节实 :745（非 :758-）；CHANGELOG .env 句实 :190（非 :216；:216/:217 为 YAML 门禁/toml-test 行）；
  路线图 §28 起实 :2253（非 :2257）、§28.1-§28.5 起实 :2255/:2266/:2292/:2304/:2316（非
  :2259/:2270/:2296/:2308/:2320）、§4 起实 :239（该锚在 74e336e 上成立）、§8 起实 :613（成立）；
  仓根 consema-go/README.md 仅 176 行，旧引 :183-189/:298-301/:402-408 为幻影区间，语义实为
  go/README.md 各家族记录（yaml 族 :183-189、xml 族 :298-301、hcl 族 :402-405）；§9.5 consema-ts
  三脚本第三数字实为 83（68/108/83）。

## 12. 第四轮对抗性审计第三波（2026-08-14，修复后重打与收口）

### 12.1 审计与归并

- 触发：波 2 修复落地后按常设阶段重打（stateFile 带波 1+2 确认集与组级去重上下文）
- 结果：**120 条确认**（P0×2 / P1×5 / P2×113）；含 2 个新 P0（rs `cargo package --workspace` 发布门禁确定性失败、py `python -m build` 发布路径确定性失败——「发布路径从未真实演练」复发机制实证）
- 归并：六分片 1:1 归并为 **45 根因组**（`loop-state/disposition-2026-08-14-wave3.md`），**16 项总指挥当波裁决**（判断型组零跨波悬挂：披露渠道如实化 R1、release-sign 正则放宽 SemVer 预发布 R2、RFC 0016 误归因统一契约家族 R3、fc-manifest 副本保留+同步+SHA 注记 R12 等）

### 12.2 修复执行

- 阶段一 8 agent（跨仓家族/高优先）：conformance 六仓 re-vendor、五要素终审锚点 P1、fc-manifest 四仓副本同步、docs-site 构建 P1、SECURITY 六仓家族、release-sign、RFC/跨仓引用族 sweep（812 文件 ~12,500 处）、verify 脚本族（13 脚本 nonce + 双探测）
- 阶段二 6 agent（按仓并行）：45 组全部落地；六仓各仓多次 commit + push 全程即时提交
- 全程纪律执行：发布路径改动全部本地实测预演（cargo package 14/14 exit 0、python -m build + 端用户 pip install、npm pack + 干净目录消费、release-sign 完整签名路径 5 例全过、mdbook build exit 0）

### 12.3 收口验证（本机验证口径；CI 绿口径见波 4 勘误）

- **勘误（2026-08-15 波 4 P1 实证）**：本节原标题「六仓全绿」不成立——波 4 审计实测 consema-kt main CI 自 2026-08-14 10:53 起持续红（run 31797956126 / 31798354016 均 failure，后者在本记录写入前 12 分钟），根因为波 3 W3-29 引入的「verify cached gradle distribution」步骤硬编码 `$env:USERPROFILE\.gradle\wrapper\dists` 而 hosted runner 的 GRADLE_USER_HOME=D:\a\.gradle（波 4 P1，ci-kotlin.yml:183/:947）；consema-ts main CI 亦红于波 2 G33 引入的 clean-install smoke 步骤 PowerShell 转义缺陷（波 4 P0，ci-typescript.yml:609）。本节全部计数为本机验证结果（kt 573 未经 CI 执行，门禁在测试步骤前失败），**不是** CI 绿声明。
- rs 1,636 tests + cargo doc；go 22 包 build/test/vet/gofmt 全过；ts 668（663+5 skip）；py 703；kt 573（含 W3-45c 新增 TestFixturesTest 守卫测试）；母仓 JSON/YAML/runs.csv 复验（均为本机口径）
- 16/17 同根因零命中 grep 复验通过；唯一残留（docs-site §7.1 job 计数镜像未随权威更新）已修复并推送（波 4 勘误：docs-site 镜像同文件 §10 行「实际 job 数：ts 9、py 8、kt 7」为同文件第二处未同步行，随 docs-site G03 全量重随处理，见 docs-site 重随记录）
- 10 组抽查「处置记录 vs 文件实况」全部一致；vendored 副本 hash 表六仓实测吻合（R11 载体落地）
- 审计自身数字修正 1 处：波 3 记录的 trivia 272B 实测为 256B（A6 落笔以实测为准）

### 12.4 遗留（波 4 输入）

- F7 枚举模式外三类：裸 `(:NNN)` 省略行号、跨仓 `.py/.go/.ts` file:line 引用、散文「lines NNN-NNN」（冻结 RFC 正文内形态需裁决）
- docs-site 全量 G03 重随建议（发布视图副本与权威逐文件 diff）
- 按常设阶段继续波 4 重打（stateFile 含波 2+3 累积 571 条确认）。

**§12 结论**：波 3 修复后本机验证全绿、实况比对一致（CI 绿口径见 §12.3 勘误——kt/ts CI 由波 4 修复）；行号失效矿脉大幅收缩（裸 `RFC §x:y`、路线图 `§x:y`、`G114 印章` 六仓零命中）——锚点约定全面落地。继续波 4 重打验证。
