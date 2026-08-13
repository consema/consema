# 五要素终审（§28 收口记录，`1.0.0` 前哨）

- 对应门禁：路线图 §28《五要素终审》（第 2253-2326 行），对 §28.1-§28.5 的通过条件逐条核验
- 日期：2026-08-10（本地实测）
- 计数口径注记（2026-08-13 round-4 补充）：本文件多处「conformance 508/508」为
  2026-08-12 19:41（ad66702，P2-B 向量补强）之前撰写的记录，保留当时口径 508（自洽
  历史快照，不静默改写）；现行口径为 18 套 suite / 519 cases（digest cfd6e296…，
  fc-manifest-0.13.0.json:36-41）。
- 范围：0.13.0-0.19.0 全周期已积累审计证据的**最终状态核验**（不重跑审计，只核验修复后状态）；
  只读核验 + 实际抽查；所有声称标注证据（file:line）或实测记录
- 核验口径：
  - **提交态** = 当前 HEAD（含 2209582 的 F-A/F-B 修复与 1.0.0-rc.1 版本推进）；本核验时点提交
    `74e336e`（历史提交：Deliver Go 0.19.0 G5.6-G5.7，go/ 0.14.0-0.19.0 证据链终点），
    抽查在临时 worktree（`git worktree add ... 74e336e`，干净 checkout）执行；
  - **工作树** = 主仓库当前状态。版本推进（consema-rs 15 个 `Cargo.toml` +
    `consema-go/go/cmd/consema/version.go` 的 `0.13.0 → 1.0.0-rc.1`）与 RFC 0020 已于 2209582 提交（docs/rfcs/0020-compatibility-and-support-policy-v1.md，
    Accepted，2026-08-10）。工作树与提交态的历史差异如实区分（见 §5）；
  - 无法在本机复核的声称（三平台矩阵的 Linux/macOS 腿、72 CPU-hours 账本时长等）标注来源与日期，不冒充实测。

---

## 1. 五要素逐条核验

### 1.1 §28.1 哲学统一（第 2255-2264 行）— **PASS**

| # | 通过条件（原文引用 §28.1） | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 八个格式都以不可变 Document 为真实状态 | Rust：各家族 RFC 0012-0014 与 README（无损 Document、immutable）；Go：consema-go/README.md:455-457（§21.2 政策 1：Completed objects 逻辑不可变、访问器返回拷贝、唯一变更路径是显式 builder）。CHANGELOG.md:152、172（0.11.0/0.10.0 行"未修改 Document 字节精确往返"） | 通过 |
| 2 | PortableValue 不吞并 graph、XML tree 或 HCL program | YAML graph 归属 PortableGraph（RFC 0006/0007，CHANGELOG.md:239"PortableValue 未因 YAML 增加引用或 graph 类型"）；XML element-tree、HCL body/expression 各自有 `xml.element-tree@1`/`hcl.projection.body@1`/`hcl.expression@1` 记录（CHANGELOG.md:178、138、147）；IMPLEMENTATION.md:108（"PortableGraph 是与 PortableValue 平行的 immutable portable representation"）；Go 侧同名记录（consema-go/README.md:298-301、402-408） | 通过 |
| 3 | Projection、Materialization 和 Edit 都是显式操作 | RFC 0004（MaterializationRequest/Result、fidelity/report/provenance）；CLI 默认只读/dry-run、写操作显式参数（CHANGELOG.md:101"没有任何命令在无显式参数时写目标文件"）；失败形态原子（B-5，API-REVIEW-0.13.0.md:107"report:null,target:null 是诚实形态"）；Go 侧同样显式（pilot-go-0.19.0.md §2.7 六组原子拒绝） | 通过 |
| 4 | CLI 便利性不改变核心默认拒绝原则 | RFC 0015（default dry-run、`edit --write` usage 显式拒绝，consema-rs/consema/src/bin/consema/edit_cmd.rs:1020-1023 由测试钉死）；帮助文本已如实化（API-REVIEW-0.13.0.md:110：args.rs:194 "dry-run only"） | 通过 |
| 5 | Rust 与 Go 共享行为，不强制共享实现结构 | 路线图 §11（双实现原则）；RFC 0016 §1.1 cgo 禁令（consema-go/README.md:771-773）；Go stdlib-only 零第三方依赖（consema-go/go/go.mod 无 require，consema-go/README.md:554-557）；两语言独立 parser（consema-go/README.md 各家族"self-written"/"independent tokenizer"） | 通过 |
| 6 | 生产级范围没有把配置来源、evaluation 和治理平台塞入核心 | `.env` 明确为"后续 source adapter，而不是第九种配置格式 Profile"（CHANGELOG.md:224）；HCL 不求值（SECURITY.md:36、CHANGELOG.md:147）；无 schema/registry/remote-KV 进核心（路线图 §24 非目标清单，CHANGELOG.md:137、147） | 通过 |

### 1.2 §28.2 语义一致（第 2266-2290 行）— **PASS**

- 通过条件为 18 个概念（SourceSnapshot → Conformance）的清单 + "每个概念只有一个核心职责，不随格式或语言改变含义"。
- 证据：semantic-model v7 registry（41 contract / 187 error code，fc-manifest-0.13.0.json:26-28）在 Rust 与 Go 两侧逐字节一致（consema-go/README.md:30-34 注册表 v1-v7 计数；capability parity 硬门禁，consema-go/README.md:797-809）；语言无关行为不依赖 Rust 类型名（§15.2，API-REVIEW-0.13.0.md:10）。
- 实测：跨语言 normalized-result 差分 108/108（双向）、protocol exchange 83/83（双向）、byte parity 68/68（2026-08-10 本机重跑，见 §4 实测表）——18 个概念在跨语言面上行为一致。
- 命名漂移 findings（F2 `core.edit.incomplete-target@1` 双语义、F4 projection 拼写、F11 duplicate-group 词、F15 PascalCase 拼写等）全部**冻结且被 RFC/vector 钉死**，disposition = exempt-with-reason（API-REVIEW-0.13.0.md §1），修复窗口为 semantic-model v8 / 1.0.0 API 冻结；语义含义不随格式/语言漂移，属命名层清理而非语义不一致 → 不违反本条通过条件。
- 结论：通过（v8/1.0.0 命名清理项不阻塞本要素）。

### 1.3 §28.3 逻辑自洽（第 2292-2302 行）— **PASS**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | read/query/project 链闭合 | W1-W7 全工作流经公共 API 端到端（pilot-go-0.19.0.md §2.1-§2.7）；query 定义错误不晚于首个 Match（rc-1.0.0-candidate.md:48）；Go 三查询域 21 个（consema-go/README.md:430-433） | 通过 |
| 2 | materialize/convert 链闭合 | 两阶段 projection→PortableValue→materialization 组合（CHANGELOG.md:232）；canonical 生成字节必先重解析闭包验证（各家族 Correctness 段）；Go `Convert*` 8 入口（consema-go/README.md:437-443）；convert 组合 W6 全 Exact、W7 六组原子拒绝（pilot-go-0.19.0.md §2.6-2.7） | 通过 |
| 3 | edit/patch/apply 链闭合 | dry-run/commit 等价（EditPlan/SourcePatch/UntouchedByteProof，CHANGELOG.md:208）；plan/apply 双前置条件 + skipped-stale 状态机（pilot-go-0.19.0.md §2.8）；中断恢复 100%（53+47，pilot metric 11） | 通过 |
| 4 | Document 与 portable representation 之间没有隐藏同步 | 转换/物化全部显式两阶段 + 重解析闭包验证（CHANGELOG.md:150、171"失败不携带 Document/partial output"）；无共享缓存/隐式关联（架构层，IMPLEMENTATION.md 分层） | 通过 |
| 5 | format-specific edit 不伪装成 universal edit | 16 个 format-local operation registry（json 8/toml 7/yaml 8/ini 8/properties 5/xml 8/plist 6/hcl 6，fc-manifest-0.13.0.json:213-215；Go 侧同集，consema-go/README.md:430-433）；跨家族组合显式经 Document 投影/物化，不假借"通用编辑" | 通过 |
| 6 | YAML graph、XML tree 和 HCL expression 都有合法归属 | PortableGraph / `xml.element-tree@1` / `hcl.expression@1`（§1.1 第 2 行证据）；Go 侧同名记录实现（consema-go/README.md:183-189、298-301、402-408） | 通过 |
| 7 | Rust 先行与 Go 反向审计没有权威循环 | PVCE/PGCE 字节权威 = Rust 编码器（consema-go/README.md:559-590"Rust side is the authority for the bytes"）；golden 向量由 Rust 编码器生成、Go 逐字节转录，既有冻结字节零变动（CHANGELOG.md:85）；差分 harness 双向（Go 发射 → Rust consume）构成对 Rust 的独立反审计而非循环依赖；cgo 禁令排除 FFI 作弊（consema-go/README.md:771-773） | 通过 |

**Kotlin ChangeSet 结构差异（终审记录 F-28.3-1，2026-08-12，LOW）**：Kotlin 在 7/8 family 无一等公民 ChangeSet
（consema-kt/kotlin/src/main/kotlin/consema/json/Edit.kt:244-247 标注 "L4 milestone"——EditCommit 以有序 edit diagnostics 作为 fallback 事件代替）；
`core.change-set@1` 向量经 runner 本地 wire builder（镜像 Rust 构造器）通过，协议线格式面闭环；
功能闭合不受影响（conformance 508/508）。处置：不重构 Kotlin edit 管线（属 1.0.0 API 冻结决策，留待
冻结前评估）；建议在 1.0.0 API 冻结前对齐（见 §6.2 收口项）。

### 1.4 §28.4 真实有效（第 2304-2314 行）— **PASS**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 格式范围来自跨生态调查，而不是个人偏好 | 路线图 §4（第 239-357 行）生态调查与范围论证；RFC 0001-0014 逐个冻结 Profile 依据 | 通过 |
| 2 | `.env`、注册表和远程 KV 被正确归为来源 | CHANGELOG.md:215（`.env` 是后续 source adapter 而非第九种格式 Profile）；路线图 §24 非目标清单（注册表/远程 KV 不在 1.0.0 范围）——正确归类、未混入核心 | 通过 |
| 3 | 八个家族完成真实 corpus 和迁移工作流 | 钉版 corpus 12 文件（pilot-go-0.19.0.md §1，digest 登记）；三类真实批量迁移全部执行（版本/镜像更新、结构插入删除、跨格式转换，pilot-go-0.19.0.md §4.1-4.3）；fixtures 覆盖 9 目录（conformance/fixtures/，2026-08-10 实测） | 通过 |
| 4 | 每个格式不仅能 parse，还能保真、查询、投影、生成和编辑 | 路线图 §8 Mandatory Capability Matrix（第 613-643 行）；18 套语言无关 suite 508/508（实测 508 passed / 0 skipped / 0 failed，见 §4）；Go 侧 capability parity 全等（实测 PASS）；pilot W1-W5 覆盖全部八家族编辑 | 通过 |
| 5 | 用户可以用 CLI 安全 plan/apply | Rust CLI 与 Go CLI（consema-go/go/cmd/consema，74e336e）plan/apply 六步写前重验 + 原子替换 + 读回验证；stale/篡改/只读/中断负例全绿（pilot-go-0.19.0.md §2.8；rc-1.0.0-candidate.md:100-102（stale/中断）、162-189（演练 4 只读负例））；升级演练逐字节兼容（rc-1.0.0-candidate.md §3.2，:130-144） | 通过 |
| 6 | 性能、安全和供应链有可重放证据 | BENCHMARKS-0.13.0.md（冻结预算 + 复验机制 §12）；三处超线性修复复测（CHANGELOG.md:51）；security matrix（consema-go/README.md:719-749，32 行边界 + threat corpora）；供应链流程落地（release-process-0.13.0.md）——**但 0.13.0 真实发布未执行（C-3）且演练发现 D-1/D-2（checksum 不可复现、密钥无备份），见 §2 与 §3** | 通过（发布执行属 §28.5 口径） |
| 7 | 静默信息损失为零 | pilot metric 3 = 0（pilot-go-0.19.0.md:154）；M2-F2（P0 静默损失）已修复并带 trip-wire（fuzz-evidence-0.13.0.md:148、156）；audited conversion 全部 fidelity=Exact 或原子失败（pilot metric 4/5） | 通过 |

### 1.5 §28.5 完整可靠（第 2316-2326 行）— **PARTIAL**

| # | 通过条件 | 最终状态证据 | 核验结论 |
|---|---|---|---|
| 1 | 标准、Rust、Go、CLI 和 suite 同时完成 | RFC 0001-0020 冻结；Rust 0.13.0 Feature-Complete（fc-manifest 功能门禁全 complete）；Go 0.14.0-0.19.0 全部里程碑交付（74e336e）；Rust CLI 11 命令 + Go CLI beta（consema-go/go/cmd/consema，e2e 9 测试实测 PASS）；18 套 suite 508 cases 双 runner 全过（实测） | 通过 |
| 2 | 所有 mandatory capability 100% 通过 | 508/508（实测）；capability parity 8 families / 16 profiles / 21 query domains / 16 operation registries / 187 codes（实测 PASS）；无 "Rust only" mandatory 行为（consema-go/go/capability_parity_test.go） | 通过 |
| 3 | P0/P1 为零 | 通过：F-A/F-B 已修复并验证（2209582，审计 PASS），"无未解决 P0/P1"恢复成立——rc-1.0.0-candidate.md:63 记录"当前 0"（本次核验当时发现的 F-B 提交态证据缺陷与 F-A 工作树回归已分别处置，见 §5.1/§5.2） | **通过** |
| 4 | 两语言 observable mismatch 为零 | normalized differential 108/108 ×2、byte parity 68/68、protocol exchange 83/83（2026-08-10 全部重跑通过，§4）；pilot metric 12 = 0（pilot-go-0.19.0.md:164）；Go fuzz 4 缺陷修复后双语言契约一致（consema-go/README.md:683-714） | 通过 |
| 5 | 生产发布物可验证、可重建、可升级 | 发布流程与演练已落地（release-process-0.13.0.md、rc-1.0.0-candidate.md §3：升级/回滚逐字节兼容）；**但真实发布未执行（C-3 开放）**：无真实密钥、无发布 commit 上的 checksum/SBOM/签名；演练发现 D-1（0.8.0 checksum manifest 从 git 历史不可复现，脏树记录）与 D-2（演练密钥无持久公钥） | **部分（C-3 + D-1/D-2 阻塞）** |
| 6 | failure、recovery、cancellation、limits 和 conflict 都有正式语义 | RFC 0015 exit code 0-5 分类（穷尽映射测试）；limits 矩阵（Rust SECURITY.md + consema-go/go/conformance/limits_matrix_test.go 91 行 + consema-go/go/conformance/security_matrix_test.go 32 行）；batch 状态机 completed/failed/pending/skipped-stale；中断注入 seam（CONSEMA_APPLY_INTERRUPT_AFTER）；RC soak 待补：**仅磁盘失败演练未记录**（rc-1.0.0-candidate.md:100-102，P2-6，RC soak 阶段 1 必做：部分权限演练已闭环——演练 4，2026-08-10；磁盘失败环境阻塞——演练 5：C-1 已闭环（2026-08-11）后 Linux runner 完成路径可用，演练本身仍待执行） | 通过（仅磁盘失败演练归 RC soak 收口） |
| 7 | 没有通过 experimental 标签隐藏未完成的 1.0 承诺 | F-8 门禁 complete：无 mandatory capability 标记 experimental/stub/partial（fc-manifest-0.13.0.json:241-250）；全部边界是显式拒绝而非 stub（CHANGELOG.md:74-80） | 通过 |

---

## 2. 已知开放项对五要素的影响

| 开放项 | 状态（fc-manifest open_items / rc-1.0.0-candidate） | 依赖它的 §28 条件 | 影响判定 |
|---|---|---|---|
| C-1：CI 10 job GitHub 干净 checkout 全矩阵全绿 | **已闭环（2026-08-11：GitHub Actions run #5，head 437fd35，132/132 steps 全绿，10+1 job（增补前，11 定义/17 次执行）windows/ubuntu/macos 全矩阵；go-differential 2026-08-12 增补后 ci.yml 为 10+2 job/12 定义；fc-manifest open_items C-1 → closed）** | §28.5 条件 1/3/4（三平台全矩阵、SEC-9 Linux/macOS 验证、A-4 msrv 真验证、A-9 package 真跑、semver approved-failure 落定） | **C-1 腿阻塞已解除**（run #5 真跑全绿：三平台全矩阵、SEC-9、A-4、A-9 随 manifest C-1.closes 满足）；§28.5 仍 **PARTIAL**——C-2/C-3 未关闭（partial）；**延伸（2026-08-12，head dbba9a4）**：五语言 CI 全绿（ci.yml run#9 Rust 10+1 + ci-typescript/ci-python/ci-kotlin 各 run#2 全绿；go-differential 上线：2026-08-12，run#12 全绿）——§28.5 条件 1（标准/Rust/Go/CLI/suite 同时完成）的证据由双语言扩展到五语言在 CI 中 live（five-language-ci-design.md §10） |
| C-2：每格式 ≥72 CPU-hours release-candidate fuzz | partial（runs.csv 13,005 行 / 79.427 CPU-hours，截取自 session 79 期间，2026-08-10；最接近格式 properties ≈20.6%（14.8/72）；零新 crash；Go 16 targets 30s clean-run 已有记录）；**2026-08-12 10:17 复算快照（runs.csv 权威复算，快照时点标注）**：62,432 行 / ~460 CPU-hours，零新 crash（非零退出仅已知 session-9 分类）；**properties 85.5h（118.8%）、yaml 75.8h（105.3%）、ini 72.8h（101.1%）三单位已过 72h 门槛**；hcl 55.5h（77.1%）、json 55.1h（76.5%）最接近门槛的开放单位，toml 33.3h、protocol-decode 29.1h、plist 26.7h、xml 19.6h 仍开放 | §28.5 条件 3（P0/P1=0 的 fuzz clean-run 证据完整性，§22.4:1905） | **阻塞 §28.5 通过**（Q-7 未闭）；不依赖其他四要素 |
| C-3：真实发布密钥与 0.13.0 发布执行 | partial（演练密钥仅流程验证；默认 keyring 无真实密钥；docs/release 仅 0.8.0 演练产物；D-1/D-2 处置随本项） | §28.5 条件 5（生产发布物可验证/可重建/可升级——发布物、SBOM、签名、checksum、build provenance 真跑）；§28.4 条件 6 的供应链侧 | **阻塞 §28.5 通过**；D-1 要求"manifest 必须从干净发布 commit 重新生成"（rc-1.0.0-candidate.md:16）与 F-B 同源纪律（干净 checkout 复现） |
| RC soak 阶段 1（磁盘失败、部分权限失败演练、differential 追加、Go RC fuzz 记录、corpus 巡检、性能复测） | 部分权限失败演练已闭环（rc-1.0.0-candidate.md §3.5 演练 4，2026-08-10）；磁盘失败演练环境阻塞（演练 5；C-1 已闭环 2026-08-11 后 Linux runner 完成路径可用，演练本身仍待执行）；differential 追加、Go RC fuzz 记录、corpus 巡检、性能复测状态按 rc-1.0.0-candidate.md §4.1 | §28.5 条件 6（failure/limits 演练完整性，§22.7"stale/部分权限/中断/磁盘四类演练"——仅磁盘失败未记录，部分权限已闭环） | 阻塞 §28.5 的 RC 收口（RC soak 本身是 §16.6 硬门禁的法定例外） |
| Go CLI 合入后的 cross-language exchange 复跑（P2-7） | 已闭环（2026-08-10，rc-1.0.0-candidate.md:314：G5.6 合入后四 harness 复跑 83/83 + 108/108 + 68/68） | §22.2（rc-1.0.0-candidate.md:38 边界）→ §28.5 条件 4 的 CLI 侧核对 | 不阻塞（SDK 面 83/83 已实测；CLI 侧已闭环） |
| 版本推进 `1.0.0-rc.1`（F-A） | 已随 2209582 提交（consema-rs/Cargo.toml:31 / consema-go/go/cmd/consema/version.go:15）并通过两语言门禁（审计实测） | §28.5 条件 5 的发布准备、C-3 阶段 0 执行 | 不阻塞（F-A 已修复，§5.1） |
| vector 聚合 digest 干净 checkout 不可复现（F-B，提交态） | 已修复（2209582）：干净 LF checkout 重算 35bebc8d… 并回填 fc-manifest:38 与 conformance_test.go:106，与 D-1 纪律合并记录（一切门禁证据以干净 checkout 为准） | §28.5 条件 5（可重建证据）、C-1（go-1-26 job）、fc-manifest"值可精确复现"声称 | 不阻塞（已修复；C-1 推入与 C-3 发布按原路径执行） |

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
| — | round-2 findings：human-mode 失败零 stdout 字节、apply env seam 文档化、`json.projection.incomplete-document@1` 注册进 v7（186→187）、typed `WriteError::ReadBackMismatch`、locale-stable 信封、RFC §4.4 示例字节修正、mutation-corpus regression 工作流修复、yaml compose eager-span 性能（~26-29×） | P1/P2 混合 | 92a244a | 全部关闭（v7 187 code 断言实测通过，cli_m4.rs:160） |
| M2-F1 | fuzz：Recovered JSON 文档被 project/edit 接受（错误完成状态） | P1 | 094f5d1（RecoveredDocument 门，projection.rs:330,363 / edit.rs:262,305；严格断言 operation_fuzz.rs:123） | 关闭 |
| M2-F2 | fuzz：yaml 引号 `"~"` 标量解码为空（静默损失） | **P0** | 094f5d1（exact_empty_scalar 仅 plain 样式；trip-wire property_graph.rs:20-34） | 关闭（trip-wire 计数即失败） |
| F-2 | yaml 335 KB 转换超线性（69.4 s） | P1 | 094f5d1（RawByteResolver 单遍偏移，offsets.rs:1-80） | 关闭（复测 1.01 s，~69×；pilot-go §5 再次复核线性） |
| B-6 / B-9 | java-properties 源 convert/project 不可达（bug）；`inspect --profile` 格式本地 code 诊断 exit 5 内部错误（bug） | P1 | 92a244a/8b5c738（project_cmd.rs:65-73 族前缀特例；inspect.rs fallback 绑定） | 关闭（回归测试矩阵） |
| F2/F3/F4/F10/F11/F13/F15 + 2 philosophy | API 命名漂移（注册 code / 枚举名 / 拼写） | P2 | exempt-with-reason（全部被 RFC + vector 冻结；修复窗口 semantic-model v8 / 1.0.0 API 冻结） | 关闭（豁免类，已入 fc-manifest known_accepted_limitations） |

### 3.2 0.14.0-0.19.0 Go 里程碑审计发现

| ID | 描述 | 分级 | 修复 commit | 关账状态 |
|---|---|---|---|---|
| G0 审计 P1 | graph-domain distinct-by-identity 语义（(parent, ordinal)，consema-rs/consema-graph/src/query.rs:65-78）；portable-domain identity 经全路径 | P1 | 7f9c3c1（最小反例回归） | 关闭 |
| G1.1 finding | records_source.go 5 个未注册 wire code（core.source.patch-*）映射错误 | P1 | 372d182（remap 到注册 code，与 Rust 一致） | 关闭 |
| 差分 harness findings | 外族源 parse 失败不统一（invalid-sequence@1）；query 参数缺失/错误不统一（invalid-argument@1）；非法 UTF-8 escape 损失语义不标准；compareFacts 接受重复键；operations default 分支非显式失败；**registry-v3/protocol-v3-dual-transport 死 case label 误跳为 documented skip（协议 suite 覆盖缺口）** | P1 | 8d9c567（含 4 个新负向 case 钉死 U+FFFD 语义） | 关闭（"protocol 线格式/覆盖缺口"类 findings 的最完整仓库记录：另一处为 0.13.0 P1-5；两处均关闭） |
| yaml anchor-dependency | yaml 编辑 anchor 依赖验证过度拒绝（无关删除被拒） | P1 | e420ad7（只收集删除子树，照 Rust edit.rs；3 个回归测试） | 关闭 |
| 结构性债务 | 7 项 drift 统一到 Rust 参考（含 toml/ini/yaml 潜在 UntouchedByteProof 算法分歧）；protocol operator 表 147 行 diff 缺 `ini.duplicate-group` | P1 | e420ad7（108/108 + 68/68 证明零可观察变化） | 关闭 |
| G3.3 finding | plist materialization 失败路径 debug println 残留（污染 stderr） | P2 | 24d6ca2 | 关闭 |
| G4.2 finding | consema-go/go/plist materialization provenance 面缺失（direct/generated 关系） | P1 | 79df437（照 Rust build_provenance） | 关闭 |
| G5.3 exchange findings | core.query-result@1 Native match wire 字段等 6 项（unknown-field、Bytes replacement wrong-type、batch-plan profile_default:null、stale doc comments） | P1 | ada5020（83/83 双向通过；2 个遗留 documented skip 翻转为执行，508 全执行） | 关闭 |
| Go fuzz 4 缺陷（G5.4） | ① plist.binary trailer limit 越界报 false Complete（无 native model、无诊断）② json strict trailing-comma 诊断 category panic ③ yaml plain-block 无限循环（`e0: e0\n s:[a,t`）④ plist.xml 恢复循环 OOB panic + tokenizer 卡死循环 | ①P0（伪成功）②③④P1 | 937b330（每个失败输入钉入 testdata/fuzz/ 回归种子；①保留 Foundation 冻结事实） | 关闭（30s×16 target clean-run 实测 2026-08-10） |
| G5.5 F1 | §21.2 最低版本 CI 腿未落（go-1-26 job） | P2 | 937b330（ci.yml go-1-26 job） | 关闭（F-B 已修复，该 job 不受影响） |
| D-1 / D-2（G5.7 drill） | 0.8.0 checksum manifest 从 git 历史不可复现（脏树记录，0/14 匹配）；演练密钥无持久公钥 | P1（发布流程） | 处置已定：0.13.0 发布时从干净发布 commit 重新生成 checksum manifest（release-process §7 items 3+5）；真实密钥+备份随 C-3 | **待 C-3 关闭**（非代码缺陷，流程证据缺陷） |
| L5 差分 harness findings（TS/Python/Kotlin） | 跨语言 exchange 发现的 wire-codec 缺陷：ValuePath schema-less wire 格式与 AssociationLocation 位置面缺失（TS/Python）；materialization-request version:0 拒绝语义缺失（TS/Python/Kotlin）；yaml tag `'!'` 前缀与 yaml provenance ordinal/role 缺失（Python） | P1 | 2f981df（L5 差分 harnesses + 修复）+ dbba9a4（CI 验证收口） | 关闭（三语言 differential 83/83 exchange 全绿；conformance 508/508 不变） |

**P0/P1 清零声明核验**：全周期 P0（M2-F2、Go fuzz ①）与 P1 全部修复并有回归钉死；关账后新增的 **F-A**（§5.1）与 **F-B**（§5.2）两项 P1 级证据缺陷已于 2209582 处置并审计验证——"无未解决 P0/P1"的声明恢复成立（§18.4 第 1689 行）。

---

## 4. 本次核验实测记录（2026-08-10，Windows 11，go 1.26.5 / cargo 1.97.1）

核验对象：提交态 74e336e（历史提交，当时 Rust workspace 0.13.0 / Go CLI product_version 0.19.0）。本表为修复前实测记录——F-A/F-B 已由 2209582 处置并审计验证。本表 `scripts/go-verify-*.ps1` 引用指当时母仓 `scripts/` 下的脚本（六仓拆分后迁至各语言仓 `scripts/`，母仓残留副本已于 2026-08-13 删除）。

| # | 命令 | 结果 | 对应声称 |
|---|---|---|---|
| 1 | `go test -count=1 ./...`（worktree） | 18 包 ok / 1 包 FAIL（`conformance`：**digest 35bebc8d… ≠ 记录 e3d6578858…**，即 F-B）；其余全部 ok，含 cmd/consema e2e（5.439s）、pilot（1.395s）〔修复前实测记录——F-B 已由 2209582 处置（回填 35bebc8d…）并审计验证〕 | consema-go/README "all green" 在**本机 CRLF 工作树**成立；干净 checkout 下 F-B 使 conformance 包红 |
| 2 | runner 计数探针（worktree 临时测试文件，用后删除） | **TOTAL=508 PASSED=508 SKIPPED=0 FAILED=0**；DIGEST_OK=false | consema-go/README.md:809 的 0.18.0 历史态「506 passed / 2 documented skips / 0 failed」（该历史态未标注后续 G5.3 翻转——ada5020 已将 2 个 skip 翻转执行为 508 全执行，consema-go/README 已注明演进；本探测 508/0/0 与翻转后口径一致） |
| 3 | `go test -count=1 -run TestCapabilityParity ./` | PASS（OperationSets + NoRustOnlyMandatoryBehavior） | capability parity 硬门禁（consema-go/README.md:797-809） |
| 4 | `gofmt -l .`、`go vet ./...`、`go build ./...`、`go mod tidy` | 全干净 | §6 门禁（go-implementation-plan.md:323） |
| 5 | `go test -race -count=1 ./conformance/...` 及其余包 | 全 ok（唯一 FAIL 系核验临时文件删除时序所致，已复跑确认） | race 门禁 |
| 6 | `cargo test -p consema-conformance --release --locked`（worktree） | exit 0；26 个 test binary 全 ok，179 passed / 0 failed（18 套 suite runner 全部 conformant） | Rust conformance 508/508 + 计数断言 |
| 7 | `cargo test --workspace --locked`（worktree） | exit 0；63 个 test binary 全 ok，1,629 passed / 0 failed | CHANGELOG.md:68 的 workspace 全绿（0.13.0 记录 1,617；当前提交态 1,629，增量来自 0.13.0 后 conformance 域） |
| 8 | `cargo fmt --check`（worktree） | 干净 | fmt 门禁 |
| 9 | `scripts/go-verify-byte-parity.ps1` | **byte parity 68/68 equal（51 pvce + 17 pgce），exit 0** | §16.1/§22.2 PVCE/PGCE byte-exact |
| 10 | `scripts/go-verify-normalized-differential.ps1` | **108/108 forward + 108/108 reverse，exit 0** | §22.2 normalized 结果一致 |
| 11 | `scripts/go-verify-protocol-exchange.ps1` | **40/40 accept + 43/43 reject（双向），exit 0** | §22.2 protocol cross-encode/decode 100% |
| 12 | `scripts/go-verify-shared-conformance.ps1` | **步骤 [1/6] digest 校验失败**（35bebc8d… ≠ e3d6578858…）→ F-B〔修复前实测记录——修复后 recorded=35bebc8d…（LF 口径），干净 checkout 通过、本机 CRLF 树差异属文档化行为〕 | G5.1 "independent aggregate digest check" 仅在本机 CRLF 工作树成立 |
| 13 | 主树聚合 digest 复算（PowerShell，文档化算法） | 本机 CRLF 工作树 = **e3d6578858…**（与当时记录一致）；干净 LF checkout = **35bebc8d…**〔修复前实测记录——修复后 recorded=35bebc8d…（LF 口径），干净 checkout 通过、本机 CRLF 树差异属文档化行为〕 | fc-manifest 第 35-41 行"值可精确复现"声称在干净 checkout 不成立 |
| 14 | 主树 `go test -count=1 ./...` | conformance ok（CRLF digest 命中）；**cmd/consema FAIL**（panic：e2e_test.go:442 `first[:len(first)-1]`，first 为空）→ F-A〔修复前实测记录——F-A 已由 2209582 处置并审计验证〕 | 工作树 1.0.0-rc.1 版本推进破坏 envelope |

未重跑、引用最近实测记录（注明日期）：Go 16 fuzz targets 30s clean-run 与 8×2 benchmark（2026-08-10，consema-go/README.md:661-763）；Rust fuzz 账本已续跑至 session 79 在途——runs.csv 13,005 行 / 79.427 CPU-hours（截取自 session 79 期间，2026-08-10；session 78 结束快照 12,937 行 / 78.971 CPU-hours、15:53:39；最接近格式 properties ≈20.6%；fuzz-evidence-0.13.0.md §3.2.1/§8，runs.csv 为唯一权威账本）；mutation corpus 174,921 case replay（2026-08-07，63.10s）；coverage 86.51/82.82/87.91（2026-08-07）；cargo audit 1,189 advisories / 0 漏洞、deny 四段（2026-08-07）；Linux/macOS 矩阵（从未实测，= C-1）；macOS Foundation differential 7 cases / 35 legs（0.17.0 记录）。

---

## 5. 本次核验新发现（F-A/F-B，均已由 2209582 处置并审计验证；本节保留修复前历史记录）

### 5.1 F-A（工作树版本推进回归）— 已于 2209582 修复

- **当前状态（已修复）**：按原选项 (a) 执行——RFC 0015 §3.3 已修订（docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md:184-193，
  2026-08-10 revision）：product-version 校验从严格 `MAJOR.MINOR.PATCH` 扩展为完整 SemVer 2.0 core 语法，
  接受 pre-release 后缀（`1.0.0-rc.1`、`1.0.0-beta.2`），其余约束不变（无 git hash、无 build metadata，
  `+` 后缀拒绝）；未动 v8 窗口，cli-v1 向量保持有效（RFC 0015 修订块明示 "the cli-v1 vectors pin no
  prerelease rejection, so the vectors stay valid"）。两语言校验器已放宽：Rust `is_semantic_version`
  （consema-rs/consema-protocol/src/cli.rs:870-911）与 Go `isSemanticVersion`（consema-go/go/protocol/cli.go:1012-1044），
  错误文案现为 "expected MAJOR.MINOR.PATCH[-prerelease] without leading zeros or build metadata"
  （cli.rs:197,321 / cli.go:799,912）。`1.0.0-rc.1` 已提交（consema-rs/Cargo.toml:31 / consema-go/go/cmd/consema/version.go:15）。
  审计验证：cargo test -p consema-protocol 100 passed；go test ./cmd/consema 108 passed。
- **修复前状态（历史记录）**：
  - 现象：主树 `go test -count=1 ./...` → `cmd/consema` 包 panic（e2e_test.go:442 空 stdout 切片越界）；
    手动 `consema inspect --json` → exit 5 `core.protocol.invalid-value@1 at $.product_version:
    expected MAJOR.MINOR.PATCH without leading zeros`。
  - 根因：工作树把 `consema-rs/Cargo.toml`（workspace version）与 `consema-go/go/cmd/consema/version.go`（productVersion）从
    `0.13.0`/`0.19.0` 推进到 `1.0.0-rc.1`；而当时 Rust `is_semantic_version`（cli.rs:870-885）与 Go
    `isSemanticVersion`（cli.go:1013-1032）都是严格 `MAJOR.MINOR.PATCH`（无 pre-release 后缀），RFC 0015 §3.3
    与 RFC 0020（当时为未跟踪文件）均未修订该格式。提交态（0.19.0）对应测试当时全绿（实测 #1）。
  - 影响（当时）：若按当时工作树构建 RC-1，Rust 与 Go CLI 的每个信封命令都会 exit 5（错误完成状态，
    §18.4 P1 级）；Go CLI e2e 套件崩溃。C-3 阶段 0 与任何 RC 构建前必须处置。

### 5.2 F-B（提交态 vector 聚合 digest）— 已于 2209582 修复

- **当前状态（已修复）**：按原选项 (a) 执行——从干净 LF checkout 重算 digest = **35bebc8d384d…**，已回填
  fc-manifest-0.13.0.json:38（`conformance_suite.aggregate_sha256`）与 consema-go/go/conformance/conformance_test.go:106
  （recorded），两处实测一致；fc-manifest:40 note 已注明规范 checkout（LF）为权威口径、历史 CRLF 值被取代。
  审计验证：干净 LF worktree 上 go test digest 断言 PASS、手工复算 MATCH、shared-conformance 脚本 6/6 exit 0。
- **补注（本机差异，文档化）**：本机 CRLF 工作树（`core.autocrlf=true`）上仍算出 e3d6578858…，属文档化
  本机差异（rc-1.0.0-candidate.md:314 同述）；规范 checkout（LF）为权威口径，CI 不受影响。
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
7. **P2-7**：Go CLI 合入后 exchange 复跑闭环——已闭环（rc-1.0.0-candidate.md:314，2026-08-10）；
8. 处置完成后重跑本终审：§28.5 条件 3/5 转 ✓ 即五要素全 PASS，进入 §29 最终确认。

### 6.3 诚实声明

- 三平台矩阵：Windows 本地实测，Linux/macOS 腿已随 C-1 闭环（2026-08-11，run #5 windows/ubuntu/macos 全矩阵全绿）；72 CPU-hours 账本已续跑至 session 79 在途（runs.csv
  13,005 行 / 79.427 CPU-hours，截取自 2026-08-10 session 79 期间；session 78 结束快照 12,937 行 /
  78.971 CPU-hours，15:53:39）；
- F-B 已修复（2209582）：干净 LF checkout 重算 35bebc8d… 并回填，"记录值在记录机（CRLF）复现"与
  "干净 checkout 不可复现"两侧差异现为文档化本机行为（§4 第 12/13 行，rc-1.0.0-candidate.md:314），
  规范 checkout 绿、CI 不受影响；
- F-A 已修复（2209582）：RFC 0015 §3.3 修订接受 pre-release 后缀，1.0.0-rc.1 已提交；本核验时点提交
  `74e336e`（历史）的 Go CLI 与 Rust 全部门禁实测通过（§4 第 1/6/7 行）。
- 附注（随本次文档修复）：consema-go/README.md:531 "productVersion defaults to the Go milestone version `0.19.0`"
  文案陈旧（consema-go/go/cmd/consema/version.go:15 现为 1.0.0-rc.1），已随本次文档修复同步修正（consema-go/README.md §Version）。

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
| 逻辑自洽 | **PASS** | 五语言 read/query/project、materialize/convert、edit/patch/apply 链闭合均以共享向量 508/508 为界（§1.3 六条在五语言面复验，无新增反例）；字节权威单一（Rust 编码器）与星型差分拓扑（Rust 锚居中，five-language-ci-design.md §2.3）不构成权威循环 |
| 真实有效 | **PASS** | 508/508 与聚合 digest 35bebc8d… 五 runner 复算一致；**132/132 steps 于 2026-08-12 经 GitHub Actions API 在线核实**（run #5，head 437fd35：17 次 job 执行 / 132 steps / 0 failed）；fuzz 快照 **62,432 行 / ~460 CPU-hours 复算**（2026-08-12 10:17 快照，追加式账本以 runs.csv 为准）；零依赖声称四语言（Go/TS/Python/Kotlin）全实（go.mod 零 require / npm ls --omit=dev 空 / pyproject dependencies=[] / kotlin runtimeClasspath 空）；P2 陈旧声称清单已修（§7.2 处置表） |
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
| 哲学统一 | **PASS** | 六仓无反例：不可变 Document（py frozen dataclass/slots、TS 防御性拷贝、kt immutable、go Completed objects）、显式操作、CLI 默认拒绝、零依赖面（go.mod 零 require / npm 零 prod dep / pyproject dependencies=[] / kt 仅测试依赖）全部实测成立 |
| 语义一致 | **PASS** | 519 cases / 聚合 digest cfd6e296… 在六仓全部独立复算命中（含 TS runner 字节级复算）；187 codes / 41 contracts 五语言注册表集合互差 0；差分 68/108/83 精确钉死；oracle 36 项实测 |
| 逻辑自洽 | **PASS** | 三操作链以共享向量为界闭合；Rust 编码器字节权威 + 双向差分反审计无权威循环；六仓拆分计数 179/26/5/7/7 逐仓复算命中 |
| 真实有效 | **PARTIAL** | 核心数字（519/cfd6e296/132 steps/179-26-5-7-7/版本 1.0.0-rc.1）全部为真；P2-B 后 508/35bebc8d 清扫不彻底（本批已全库清零）；consema-rs 自有 CI fmt 全红（run#31，本批已修复待推绿）；docs-site 从未部署成功（Pages 未启用，README 已如实化） |
| 完整可靠 | **PARTIAL** | 与 §28.5 同口径：C-2（fuzz 账本累计中，properties/yaml/ini 已过 72h 门槛）与 C-3（真实发布密钥）未关闭；consema-go 文档化共享 conformance 验证路径 508 断言已修（P1 关闭） |

### 8.2 findings 处置汇总（本批）

| 仓 | P1 | P2 | P3 | 关键处置 |
|---|---|---|---|---|
| 母仓 | 1 | 12 | 3 | fc-manifest 证据行号迁移至六仓布局（evidence_note + 13 处引用更新）；README 18/508→18/519；six-repo-split §6 同步 519/cfd6e296 + job 计数 + rs vendor 机制如实化；five-language-ci-design 行号/oracle 计数 72/JSON5 口径/kotlin jar 供给/版本政策行；corpus runbook 钉值 519/cfd6e296；release-process §7 产物名 1.0.0-rc.1；docs-site 三副本同步；coverage.ps1 508→519；stale.yml 权限收窄；mutation-v1.json tool 字段路径 |
| 母仓 | — | 1 | — | rc-soak-stage1-differential.md 死脚本引用 + 508 计数（round-4，2026-08-13：母仓 13 个 `*-verify-*.ps1` 删除、计数 508→519、runbook 指向各语言仓脚本） |
| consema-rs | 0 | 3 | 5 | README job 计数 9→11、ctrlc 依赖如实化、vendored conformance/README 重新 vendor；**cargo fmt 4 文件修复（CI run#31 全红根因，fmt --check 归零）**；gen_mutation_corpus tool 字符串同步；run_waves.ps1 入库建议（待批次） |
| consema-go | 1 | 4 | 3 | **shared_run_test.go 508→519（文档化验证路径必红修复）**；SECURITY.md 依赖门禁段改编；ci-go.yml 头注释 3→6 job；README 旧 fuzz 表注记；.gitignore provision 数据忽略 + CONTRIBUTING 本地 provision 步骤 |
| consema-ts | 0 | 3 | 5 | "fmt" 虚假声称三处清除（README/job 名/CONTRIBUTING/CHANGELOG）；SECURITY.md 误挂 Rust 证据改为本仓真实机制+规范仓指针；**包版本 0.14.0→1.0.0-rc.1 统一**（用户决策 2026-08-12）；*.tgz 忽略 |
| consema-py | 1 | 4 | 3 | **版本 0.14.0→1.0.0-rc.1 统一**（pyproject/__init__/README/bug_report，check-version 门禁两处同步）；compileall 静态门禁落地（job 名如实化）；mojibake 10 处 + BOM 修复（UTF-8 无 BOM 字节验证）；gitignore 补齐；L0-L5 描述更新 |
| consema-kt | 1 | 4 | 4 | **「无 Gradle wrapper」声称 ×2 修复（§7.2 批次遗漏）**；计数 547→572/234→236 静态实测回填；jar 供给记录核实（脚本/CI 如实，仅母仓文档需修——已修）；TestShim.kt 标注 historical + 直驱模式描述重写；L4 标注 15 处→post-1.0.0（F-28.3-1 跟进） |

跨仓新确认：consema-go 未跟踪 conformance//docs/ 为**测试必需 provision 数据**（CI 多仓 checkout 从母仓取数，非第二权威），已 gitignore + 文档化；docs-site 根因 = Pages 未启用（workflow 无 bug）；C-1 证据链 132/132（run#5）在线核实为真。

### 8.3 本批遗留（随后续循环处置）

1. **C-2**：fuzz 账本继续累计（2026-08-12 24:00 快照 84,600 行 / ≈582 CPU-hours；xml 25.7h 最远，全家族 ≥72h 时关账并回填本表）；
2. **C-3**：真实发布密钥 + 备份 + 吊销证书（用户动作）；从干净发布 commit 按 release-process §7 执行（产物名已按 1.0.0-rc.1 更新）；
3. **consema-rs CI 推绿**：fmt 修复待提交推送后验证 run 全绿；
4. **docs-site 部署**：用户动作——consema 仓库 Settings → Pages → Source = "GitHub Actions"；
5. **run_waves.ps1 入库**（consema-rs 根，账本驱动可追溯性）；
6. RC soak 剩余：磁盘失败演练（Linux runner 路径可用）、Rust 侧性能 -Check 复验（fuzz 关账后空闲执行）。

**§8 结论**：六仓全内容面上哲学统一/语义一致/逻辑自洽 **PASS**；真实有效/完整可靠 **PARTIAL**——本批 P1 全部处置（go 508 断言、py 版本矛盾、fc-manifest 证据行号、rs CI fmt、kt wrapper 声称），P2 全库清扫完成（508/35bebc8d 现行态清零）；**round-4（2026-08-13）追加清扫**：differential runbook 死脚本引用（母仓 13 个 `*-verify-*.ps1` 删除、计数 508→519、runbook 指向各语言仓脚本，§8.2 处置表）、CONTRIBUTING 聚合 digest 计数、RFC 0012-0015 Status 冻结、support-policy 五语言化（RFC 0020/SECURITY 同步）、fc-manifest 行号重核与六仓前缀、go/multi-language-implementation-plan 519 口径、C-3 证据更新、ci.yml oracles 注释如实化等（记录见 §8.2 处置表与 docs/fc-manifest-0.13.0.json）；剩余 PARTIAL 仅因 C-2（时间累计）与 C-3（用户密钥）未关闭，另加三项外部待办（rs CI 推绿验证、Pages 启用、run_waves 入库）。
