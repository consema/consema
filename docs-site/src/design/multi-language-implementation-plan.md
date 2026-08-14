# Consema TypeScript / Python / Kotlin 实现计划（规划阶段文档）

- 决策：2026-08-11（用户决策：TS/Python/Kotlin 三语言加入 1.0.0 release 标准，与 Rust/Go 同等地位；
  工具链不阻塞——先盲写，工具链后台安装后验证）
- 体例：照 `docs/go-implementation-plan.md`（里程碑拆分、多 agent 文件域、START GATE、硬门禁）
- 权威五元（路线图 §17.1「权威组成」——行号可能漂移，以节标题为锚）扩展到七元：normative prose + contract registry +
  machine-readable vectors + raw fixtures + independent runners（Rust / Go / TS / Python / Kotlin）

## 0. 总体结构

### 0.1 现状（2026-08-11 调研）

- Rust（0.13.0 Feature-Complete，1.0.0-rc.1 版本推进）与 Go（0.14.0-0.19.0 六里程碑）已完成
  conformance 508/508（P2-B 补强前时点；补强后 519/519）、PVCE/PGCE byte-exact、
  protocol exchange 83/83、normalized 108×2。
- 共享仲裁层：`conformance/vectors/`（18 套 / 519 cases，聚合 digest cfd6e296 五语言共钉；
  508/35bebc8d 为 2026-08-12 P2-B 补强前值，见 §7.1 关账表）、
  `conformance/fixtures/`、`conformance/corpora/`、`conformance/oracles/`；
  注册表：contract v7（41 条）/ error codes v7（187 码）；RFC 0016 为 Go API mapping v1 宪章（Go 专属契约面，非语言无关——标题即「Go API mapping v1」；TS/Python/Kotlin 实现不作其语言无关权威）。
- 字节权威 = **Rust 编码器**（PVCE/1、PGCE/1 golden 字节，双语言差分 harness 反向审计）。
- 工具链状态（2026-08-11）：Node 26.7 / Python 3.12 / Temurin 17 JDK / Kotlin 2.2.0 后台安装中；
  安装完成前允许盲写（本计划 §3 盲写纪律），完成后执行验证门禁（§7）。

### 0.2 目录布局（与 `go/` 并列）

| 目录 | 语言 | 构建/运行 | 模块 |
|---|---|---|---|
| `typescript/` | TypeScript（ES2022+，strict） | `npm` + `tsc`，测试 `node --test` 或 vitest | `package.json` 单一包，src/ 分域 |
| `python/` | Python 3.12 | `pyproject.toml`（setuptools 或 hatchling），测试 `pytest` | 单一包 `consema`，模块分域 |
| `kotlin/` | Kotlin 2.2.0 (JVM 17) | Gradle 或 kotlinc 直接编译，测试 kotlin.test | 单一 module，包分域 |

三语言均为**零第三方运行时依赖**（政策照 go.mod 零 require 先例；测试框架除外）。

### 0.3 与 Go 里程碑的对应（Go 六版本 → 每语言六里程碑 L0-L5）

Go 0.14.0-0.19.0 的 G0-G5 结构直接平移（语义面一致，实现语言惯用）：
L0=core+PVCE/PGCE+protocol（↔G0）、L1=document+json+toml（↔G1）、L2=yaml+ini+properties（↔G2）、
L3=xml+plist+hcl（↔G3/G4.1）、L4=全操作 parity+conformance runner+capability parity（↔G4.2-G4.4）、
L5=fuzz/bench/security matrix+CLI+release-candidate clean-run（↔G5）。
三语言之间完全并行；语言内部 L0→L1→…→L5 串行（前驱公共 API 输入），语言内里程碑内部可按
格式 family 并行（文件域隔离）。

## 1. 复用决策（照 go-implementation-plan §1，2026-08-11 用户原则补充）

**根本原则（用户 2026-08-11 明示）**：
- **设计与细节完全语言无关**——规范、语义模型、注册表、字节格式、向量是唯一事实来源；
- **每语言同等地位**——TS/Python/Kotlin 与 Rust/Go 无主次之分，全部是完整实现；
- **Rust 仅是"第一权威语言"**——因最先实现、字节编码器是冻结基准，但这不是地位差异，只是
  时间顺序与仲裁参照；
- **实现必须走各自语言哲学与最佳实践，禁止抄其他语言的实现**——不得逐行翻译 Rust 或 Go，
  结构、命名习惯、惯用法、错误处理风格按本语言社区标准设计。

**数据来源优先级（提取冻结数据时）**：
1. `conformance/vectors/*.json`（语言无关、机器可读、双语言共钉聚合 digest）——首选；
2. RFC 0001-0015 + 0020 规范 prose（语言无关权威；0017-0019 不存在；0016 为 Go 专属宪章，不作语言无关面）——次选；
3. Rust 实现（第一权威语言：PVCE/PGCE 字节布局、注册表清单的最终仲裁者）——仅在 1/2 不足时；
4. Go 实现——**仅作交叉参照**（核对"另一实现也这么理解"），不作为提取来源；若 Rust 与 Go
   不一致，以 Rust + 向量为准并记录差异上报（不得自行裁决）。

**重新实现（语言惯用，非 Rust/Go 翻译）**：值模型、parser、projection、materialization、edit、
错误类型。不逐行翻译；命名拼写照 §1.4 冻结表（API-REVIEW-0.13.0.md §1 的 F2/F4/F11/F15 豁免项
不得在 new language 重新引入漂移——直接用钉死拼写）。

**禁止复用边界**：不 import/调用/FFI 到 Rust、Go 或彼此（cgo 禁令平移为各语言"不依赖他语言
产物"）；错误 text 不参与规范比较（language-neutral）；无隐藏共享状态。

**字节权威单一**：Rust 编码器；golden 向量逐字节转录进本语言测试（转录自向量文件，不是抄
Go 的测试）。

## 2. 里程碑拆分（每语言 L0-L5）

| 里程碑 | 依赖 | 并行性 | 内容（↔ Go 对应） |
|---|---|---|---|
| L0 | — | 三语言并行 | scaffold（包/模块/测试框架）+ core 值模型（十五 kind：Null/Boolean/String/Bytes/Integer/Decimal/BinaryFloat32/BinaryFloat64/Date/Time/LocalDateTime/OffsetDateTime/Object/Array/Entry + EntryMapping）、strict equal/hash、PVCE/1 codec（↔G0.1）、graph+PGCE/1（↔G0.2）、protocol（contract 41/error 187/Diagnostic/CLI records/ClassifyErrorCode，↔G0.3） |
| L1 | L0 | 三语言并行 | document（SourceSnapshot/Span/ProfileId/FormationStatus/ParseLimits/MaterializationRequest/SourcePatch，↔G1.1）+ json family（JSON/JSONC/JSON5，↔G1.2）+ toml（↔G1.3）+ 根面（Document union/Registry/convert，↔G1.4） |
| L2 | L1 | 三语言并行 | yaml（1.2/1.1、anchor/alias/graph，↔G2.1）+ ini（三 Profile，↔G2.2）+ properties（Reader/Latin-1，↔G2.3）+ 全操作补齐（↔G2.4） |
| L3 | L2 | 三语言并行 | xml（1.0 safe Profile，↔G3.1）+ plist（XML/binary，↔G3.2）+ hcl（native/tfvars，不求值，↔G4.1） |
| L4 | L3 | 三语言并行 | 全格式 materialize 全组合（↔G4.2）+ mandatory structural edit/SourcePatch/batch-plan（↔G4.3）+ examples/文档/capability parity 断言（↔G4.4） |
| L5 | L4 | 三语言并行 | conformance runner 全 519（↔G5.1；增补后口径——2026-08-12 P2-B 前为 508，见 fc-manifest-0.13.0.json:39、41）+ 跨语言差分（Rust↔TS/Python/Kotlin，↔G5.2）+ protocol exchange（↔G5.3）+ fuzz/bench/security matrix（↔G5.4）+ CLI beta（↔G5.6） |

每里程碑硬门禁（照 Go 先例）：对应 capability 的共享向量 100% 通过；PVCE/PGCE 字节与 Rust
一致；不依赖他语言产物；error text 不参与比较；unknown-field/canonicality 规则一致。

## 3. 盲写纪律（工具链未就绪期间）——已于 2026-08-11 解除

**状态更新（2026-08-11，用户指示"已有的语言不用盲写"）**：五语言工具链全部就绪——
Node 26.7 + npm + tsc（TS）、Python 3.12.13/3.12.10（Py，pytest 未装但 shim runner 等效实测）、
JDK 17.0.20 + kotlinc 2.2.0（Kt，直接 JVM 调用 K2JVMCompiler）、cargo 1.97.1（Rust）、go 1.26（Go）。
**此后派发的 agent 一律"边写边验证"**：写完立即用本语言工具链编译/运行测试再交付；
仅 L3 已派出（2026-08-11 17:20 前）的盲写 agent 保持原样，其产物按 §7 门禁验证。

- 允许：按本计划与权威契约写源码与测试；工具链就绪后边写边验证（编译/运行意图测试）。
- 必须：所有冻结数字/名称/字节从权威源提取（RFC/vectors/fc-manifest/Rust golden），不得凭记忆
  或猜测写码/标签；每个文件头注明数据来源（file:line）。
- 禁止：`--fix`/自动格式化改写（照 memory 子 agent 纪律）；修改 conformance/ 任何文件；
  修改 Rust/Go 代码或 docs/ 除本计划外文件。
- 验证时机：工具链就绪后（§7 START GATE）按 L 序逐里程碑验证；验证前不宣称任何门禁通过。

## 4. 多 agent 文件域划分

共享只读域：`conformance/`、RFC 文档、fc-manifest（任何 agent 不得修改）。
每语言一个总 agent（L0 起），L1+ 按格式 family 拆分 agent（照 go §3 表 A-T 平移），
文件域 = `typescript/src/<family>/`、`python/src/consema/<family>/`、`kotlin/src/main/kotlin/<family>/`
及各自测试域。并行 agent 无共享写域；scaffold（package.json/pyproject.toml/build）只经 L0 agent。

## 5. 风险清单

- 盲写期间无编译/类型检查 → 语法/类型错误积累：以 L0 骨架先行验证（工具链就绪后第一个验证对象），
  后续 L 验证前先跑骨架门禁。
- 三语言 × 八 family 工作量 ≈ 3 × 59k-84k 行（Go 体例估计）→ 严格按 L 里程碑收口，不并行跨 L。
- 各语言惯用差异（TS 结构性类型、Python 动态类型、Kotlin sealed class）可能导致语义面实现分歧：
  以 vectors 为准，差分 harness 兜底。
- 1.0.0 release 标准扩展：三语言加入后，§22 门禁/五要素审计/fc-manifest 范围同步扩展；
  C-2 fuzz 账本为 Rust/Go 专属、不按语言分列（ts/py/kt 的 L5 不含 fuzz/bench/security
  ——与 §7.1 关账表一致，2026-08-14 波 2 修正此前「按语言分列」的矛盾口径）。

## 6. 验收门禁总表（照 go-implementation-plan §6）

| 门禁 | 通过条件 |
|---|---|
| 构建 | 工具链就绪后各语言构建/测试命令 exit 0 |
| conformance | 全 18 套 / 519 cases runner 通过（与 Rust/Go runner 同批） |
| 字节 parity | PVCE/PGCE 与 Rust 编码器字节一致（golden 转录测试） |
| capability parity | mandatory capability set 与 fc-manifest 对齐；无 "Rust only" mandatory 行为 |
| 零依赖 | 运行时零第三方依赖（测试框架除外） |
| 命名冻结 | 无新拼写漂移（§1.4 冻结表） |

## 7. START GATE（最高优先级条款）

工具链就绪（node/tsc、python+pytest、JDK+kotlinc 均可运行）后，先执行：
1. L0 骨架构建 + 值模型单测 + PVCE golden 字节测试；
2. 通过后才允许宣称 L0 关闭并进入 L1。
每个 L 关闭同理（先验证后宣称）。任何 agent 的派发受本 GATE 约束；
GATE 未过期间的代码统称"盲写产物"，不得进入任何发布证据。

### 7.1 L0-L5 关账状态（2026-08-12 更新：L0-L4 全部关闭；L5 关闭面 = 差分 harness + CI 已交付，fuzz/bench/security matrix 为 Rust/Go 专属，ts/py/kt 的 L5 不含——以 five-language-ci-design.md §10 实况为准；L0 的 L-differential 组成腿 shared-conformance 脚本尚未合入（该设计 §1.2/§10），L0 关闭面按其口径收窄）

| 批次 | 载体 commit | 证据 |
|---|---|---|
| L0-L4（三语言） | 5cf680b（实现入库；errata 见 CHANGELOG 2026-08-12 勘误） | 每语言 conformance 508/508（增补前——18 套 / digest 35bebc8d 共钉；2026-08-12 P2-B 向量补强至 519 / cfd6e296 后见 fc-manifest-0.13.0.json digests.conformance_suite——以字段名为锚，行号可能漂移）+ capability parity；CHANGELOG 勘误记录 commit message 仅标注 fuzz 账本、实际携带三语言实现 |
| Python 补充 | a0c318b | .gitignore 排除 node_modules（CHANGELOG 勘误同述） |
| L5 harnesses + CI | 2f981df | 跨语言差分 harness（normalized/protocol exchange）+ 各语言 CI workflow；差分发现的 wire-codec 缺陷随本 commit 修复（五要素终审 §3.2 关账表） |
| CI 修复 | dbba9a4 | 五语言 CI 全绿（python fixtures 路径、kotlin jar 供给等首跑缺陷修复；ci.yml run#9 + ci-typescript/ci-python/ci-kotlin 各 run#2，见 rc-1.0.0-candidate.md §4.1） |

- 每语言 conformance 519/519（增补后；digest cfd6e296da5b… 五 runner 共钉，
  fc-manifest-0.13.0.json:39 为权威）+ capability parity + 差分（68/108/83）
  全绿；五语言 CI 在 dbba9a4 全绿。
- **L5 关闭面如实界定**：ts/py/kt 的 L5 关闭面 = 差分 harness + 各语言 CI
  （含零 documented skip 断言与 `L-package` job，2026-08-12 上线）；
  **fuzz/bench/security matrix 为 Rust/Go 专属**（C-2 fuzz 账本仅覆盖
  Rust+Go，rc-1.0.0-candidate.md §1 C-2 行 / §22.4），ts/py/kt 的 L5
  不含 fuzz/bench/security——以 five-language-ci-design.md §10 实况为准。
- 未来工作（诚实记录）：fc-manifest 扩展 `languages` 节（five-language-ci-design.md §7.4 提案）尚未落地，
  随 1.0.0 发布收口执行。

## 8. 相关文件

- 体例：`docs/go-implementation-plan.md`（§1-§7 平移）
- 契约：RFC 0016（Go API mapping 宪章——Go 专属契约面，仅 Go 侧消费）、RFC 0006/0007（graph/PGCE）、RFC 0015（CLI 协议）
- 注册表：`docs/fc-manifest-0.13.0.json`（41 contract / 187 codes / capability 门禁）
- 向量：`conformance/vectors/*.json`（18 套 / 519 cases）
- 字节权威：consema-rs/consema-pvce（PVCE/1）、consema-rs/consema-graph（PGCE/1）
