# Consema 0.14.0–0.19.0 Go 实现计划（规划阶段文档；发布与里程碑关闭被 §7 START GATE 门禁；实现启动经 2026-08-07 decision record 授权）

- 对应规范：路线图《Consema 1.0.0 产品路线图与双语言落地设计》§11（双实现原则）、§14.12（第 1345 行：只有第 15 节门禁全部通过才允许开始 0.14.0 Go 实现）、§15.7（Feature-Complete Manifest 为 Go 起点，第 1445 行）、§16（Go 阶段详细计划 §16.1-§16.6）、§17（语言无关 Conformance 架构）、§21.2（Go API 政策）、§22/§23（1.0.0 门槛与真实项目验证）；RFC 0016（Go API mapping charter，模块拓扑/值映射/API 形状/错误分类/conformance 集成契约/§8 冻结拼写/rejected alternatives 全部冻结）；docs/0.13.0-gate-plan.md（§4 M4/M9 与 §1.7：C-1/C-2/C-3 开放项）；docs/fc-manifest-0.13.0.json（当前门禁状态：gate_open / not_closed）
- 目标版本：0.14.0（Go core、PVCE、PGCE 与协议）→ 0.15.0（Document、JSON family 与 TOML）→ 0.16.0（YAML、INI 与 Properties）→ 0.17.0（XML 与 plist）→ 0.18.0（HCL 与全操作 parity）→ 0.19.0（双语言一致性与产品 Beta），全部对应路线图 §16.1-§16.6
- 先例：`docs/cli-implementation-plan.md`（0.12.0）与 `docs/0.13.0-gate-plan.md`（0.13.0）的多 agent 文件域计划体例；`conformance/oracles/hcl-go-v1/`（仓库内 Go 子目录 module 先例，仅差分 oracle）
- 语义权威顺序（沿用 `docs/IMPLEMENTATION.md`，0.13.0-gate-plan.md:6）：永久不变量 → 已接受 RFC → 语言无关 conformance vectors → 本实现计划与 Rust API → 第三方行为仅为实现细节
- **性质声明**：本文是只读调研产出的规划交付物。它**不**启动 Go 实现——0.14.0 的启动原由 §7 START GATE 门禁（0.13.0 Rust Feature-Complete Gate 全闭，即 fc-manifest 开放项 C-1/C-2/C-3 完成）决定；该"启动前置"条款已由 **2026-08-07 decision record**（fc-manifest decisions[0]：owner 按路线图 §0 冲突解决层级书面授权提前启动 go/ 0.14.0 G0.1-G0.3）修订——发布与里程碑关闭仍由 §7 START GATE 门禁决定，go/ 内已开工实现按 §6 门禁独立验证。除本文外本次不修改任何仓库文件，不运行 git commit（体例照 cli-implementation-plan.md:8）。

---

## 0. 总体结构

### 0.1 现状核查（本计划调研结论，2026-08-07）

**Go 工具链（环境备注，仅用于本计划环境章节，不构成实现开始）：**

- `go version` → `go1.26.5 windows/amd64`（2026-08-07 实测，`C:\Program Files\Go\bin\go`；GOROOT=`C:\Program Files\Go`，GOPATH=`C:\Users\franck\go`）。
- 与仓库内 Go 差分 oracle 的运行时 pin 一致：`conformance/oracles/hcl-go-v1/manifest.json` runtime 段记录 `go.version: go1.26.5 / go.os: windows / go.arch: amd64 / windows_build: 10.0.26200.0`。
- Go SDK 模块的 go.mod 最低版本须在 0.14.0 冻结并进 CI 验证（路线图 §21.2 第 1825、1831 行）；hcl-go-v1 oracle 的 `go 1.22` 指令是其创建时代遗留，**不是** SDK 版本政策（oracle 的 go.mod 由自身 manifest 钉管，见 §1.3）。

**RFC 0016 已接受；Go 实现已按 2026-08-07 decision record 启动（0.14.0 G0.1-G0.3）：**

- `docs/rfcs/0016-go-api-mapping-v1.md` 已冻结：模块拓扑（§3）、PortableValue/PortableGraph→Go 映射（§4）、formation/projection/materialization/edit API 形状（§5）、错误分类（§6）、conformance 集成契约（§7）、语言无关拼写（§8）、版本关系（§9）、rejected alternatives（§10）。
- 门禁记录：fc-manifest-0.13.0.json S-6（第 195-199 行）status=complete（"Go API mapping RFC 已接受；Go 实现 0.14.0 G0.1-G0.3 已按 2026-08-07 decision record 启动"）；0.13.0-gate-plan.md:169（G-8 交付）与 :74（§1.2 规范门禁表）。
- **2026-08-07 decision record（fc-manifest decisions[0]）**：owner 决定在 C-1/C-2/C-3 完成前启动 Go 实现（go/，0.14.0 G0.1-G0.3）；Go 里程碑顺序、验收门禁（§6）与 C-1/C-2/C-3 完成路径不变；go/ 以 fc-manifest 为能力起点（路线图 §15.7 第 1445 行），不以工作树偶然状态为起点。go/ 已存在 core/graph/protocol 三 package（2026-08-07 实测 go build/vet/test/race/gofmt 全绿）。

**0.13.0 Rust Feature-Complete Gate 当前状态（START GATE 的直接输入，未关闭）：**

- fc-manifest-0.13.0.json：`status: "gate_open"`（第 5 行），`feature_complete_judgment.verdict: "not_closed"`（第 505 行），status_meaning 原明示"仅在本判定翻转为 closed 后启动"（第 6 行）——已按 2026-08-07 decision record 修订为"已提前启动 go/ 0.14.0 G0.1-G0.3，C-1/C-2/C-3 完成路径不变"。
- 开放项（第 513-541 行）：C-1（CI 10 job 在 GitHub 干净 checkout 真跑全矩阵全绿，第 515-522 行）、C-2（每格式 72 CPU-hours release-candidate fuzz，当前 26.309 CPU-hours——2026-08-07 会话结束快照，runs.csv 4,063 行，第 524-531 行）、C-3（真实发布密钥与 0.13.0 发布执行，第 533-540 行）。
- 已关闭：全部功能/规范/性能门禁，质量除 Q-7 外、安全除 SEC-9 外、API 与产品除 A-4/A-9 外（第 506-512 行）。
- 原约束结论（0.13.0-gate-plan.md:136）："0.14.0 不得在判定翻转前开始"——2026-08-07 decision record 已修订为：C-1/C-2/C-3 完成前不得发布 0.14.0、不得宣称 Go 里程碑关闭，go/ 按 §6 门禁独立验证（见 §7）。

**Go 侧必须镜像的语言无关契约面（只读调研清单）：**

1. **conformance 向量**：`conformance/vectors/` 18 套 suite / 508 cases（本计划逐文件计数复核，2026-08-07）：v1.json 30、toml-v1 18、protocol-v1 32、source-v1 28、syntax-query-v1 19、protocol-v2 11、operations-v1 35、json-family-v2 33、portable-graph-v1 10、semantic-model-v5 22、yaml-v1 27、semantic-model-v6 25、ini-v1 20、java-properties-v1 22、xml-1-0-safe-v1 34、plist-v1 45、hcl-v1 57、cli-v1 40。聚合 sha256 `e3d6578858fa1fdcab0c19ee0094cd246923dca76e9be4679aabf86b482b68c8`（fc-manifest 第 38 行；聚合方式见第 40 行；2026-08-07 复核可精确复现——按文件名字节序排序，逐文件 sha256（小写 hex），行格式 `{basename}:{digest}` 以 `\n` 连接（无尾换行）后对 UTF-8 字节再 sha256）。
2. **registry**：semantic-model v7 = 41 条 contract / 187 个 error code（README.md:32；fc-manifest 第 26 行；`crates/consema-protocol/src/registry_manifest.rs` 为序列化源；0.13.0 audit F3 注册 `json.projection.incomplete-document@1`，186 → 187）。
3. **capability set**：8 families / 16 profiles / 21 query domains / 16 operation registries / 187 codes（fc-manifest 第 31 行；`consema capabilities` 实测）。
4. **协议 payload**：RFC 0015 v7 记录（`crates/consema-protocol/src/cli.rs`：CliOutputMessage、BatchPlanMessage、BatchResultMessage、CliCommand、Redaction、BatchPlanFileStatus/BatchResultFileStatus；exit 分类 `crates/consema-protocol/src/exit_class.rs:11` 起 Success/Usage/Data/Limit/Precondition/Internal 六类）。
5. **值模型**：PortableValue 八 kind（Object/Array/String/Integer/Decimal/BinaryFloat64/Boolean/Null，RFC 0016 §4.1 第 123-131 行）；对象有序条目且构造时拒重 key（第 141-143 行，RFC 0002 对象契约）；PVCE/1 与 PGCE/1 为唯一跨语言值字节面（§4.2 第 150-153 行）。
6. **规范边界事实**：差分 oracle exclusion inventory（HCL D-1..D-9、plist D-1..D-21、YAML 1 项，记录于 `conformance/oracles/hcl-go-v1/manifest.json` 与 `conformance/oracles/plist-macos-v1/manifest.json`）——这些是规范边界的冻结事实，Go 必须复现同样的接受/拒绝语义。
7. **上游语料**（语言无关输入，Go 按里程碑消费）：toml-test v2.2.0（205+474）、yaml-test-suite data-2022-01-17（402）、JSON5 v2.2.3（83/83）、INI/Properties 五套运行时 oracle 36 项（README.md:34-37；fc-manifest 第 44-49 行）。

**仓库内 Go 先例（只作差分 oracle，不作 SDK 实现）：** `conformance/oracles/hcl-go-v1/`（module `consema-hcl-go-differential`，依赖 hashicorp/hcl/v2 v2.21.0 + go-cty v1.13.0，29 case 文档化 skip_path）。它是"第三方行为钉"，不是 Consema Go SDK 的组成部分（§1.4）。

### 0.2 Go module 拓扑与仓库布局

**单一 module `consema`**（RFC 0016 §3.1 第 91-97 行冻结：单 module 结构冻结，SDK 与未来 Go CLI 共用一个 module，镜像 `crates/consema` facade + `[[bin]]` 结构）。

- module path 约定：`consema.dev/consema`；最终可发布路径是 0.14.0 的实现事实（RFC 0016 §2.2 第 83-85 行"publishable repository path is an implementation decision of 0.14.0"）。
- **仓库布局（本计划冻结）：`go/` 目录承载整个 module**（go.mod/go.sum、全部 package、cmd/）。依据：
  1. 仓库子目录 module 先例：`conformance/oracles/hcl-go-v1/`；
  2. 根 Cargo.toml workspace 不会拾取 `go/`（无 Cargo.toml），Rust 打包验证（scripts/verify-package-archives.ps1 覆盖 crates/ 下 14 个 crate）不受影响；
  3. CI 可 `cd go/` 独立运行（路线图 §21.2 第 1831-1832 行要求 Go 门禁进 CI）。
- Package 拓扑（RFC 0016 §3.2 第 99-109 行冻结）：

| Go package（import path `consema.dev/consema/...`） | 对应（Rust） | 职责 |
|---|---|---|
| `core` | consema-core + consema-pvce | PortableValue 八 kind、strict equality/hash、PVCE/1 codec、BigInteger/Decimal 包装 |
| `graph` | consema-graph | PortableGraph、graph equality、PGCE/1 codec |
| `protocol` | consema-protocol | language-neutral codecs、contract registry、error registry、Diagnostic、CLI machine protocol records（RFC 0015） |
| `document` | consema-document | SourceSnapshot、Span、NodeRef、ProfileId、FormationStatus、ParseLimits、MaterializationRequest、SourcePatch |
| `json`/`toml`/`yaml`/`ini`/`properties`/`xml`/`plist`/`hcl` | 各家族 crate | 每家族 documents、queries、projections、materializations、edits、operation registries |
| 根包 | crates/consema facade | `Document` union、`Convert*` 组合、`Registry` 面（families/profiles/query domains/operation registries） |
| `conformance` + `cmd/consema-conformance` | consema-conformance | Go conformance runner（§4） |

约束（RFC 0016 §3.2 第 111-117 行）：任何 package 不得 import 兄弟格式 package 的私有内部；跨家族组合（convert）只在根包；`core` 与 `graph` 不依赖模块内任何其他 package（路线图 §16.1 第 1453 行"先证明最底层值、图、编码和协议可以独立实现"）。

### 0.3 推进节奏与跨语言身份

- 语言无关行为完全一致面（路线图 §11.2 第 849-861 行；RFC 0016 §1 第 34-40 行）：PortableValue/PortableGraph 相等、PVCE/PGCE 字节、protocol decoding、Capability 声明、parse formation、diagnostic code/category/order、native result 规范化事实、query count/identity/order、projection/materialization report、edit 和 conflict 结果、resource-limit completion semantics。
- Go 不是 Rust 的翻译（路线图 §11.2 第 838-848 行）：内部树、缓存、算法自由；Go 惯用 package/error/iterator；completed public objects 逻辑不可变；并发读、`context.Context` 取消、资源限制按 Go 生态规范。
- 版本间严格串行：0.14.0 → 0.15.0 → … → 0.19.0，每版本收口对照 fc-manifest 复核（RFC 0016 §9 第 214 行"re-checks it at each Go milestone"）；版本内里程碑可并行（§2/§3）。
- Go module 版本随产品 release train（路线图 §11.4 第 877-889 行）：1.0.0 前为 v0.x；包版本不替代 contract version（RFC 0016 §9 第 212-213 行）。

---

## 1. 复用决策

### 1.1 直接复用（语言无关契约面：Go"读"而非"抄"）

| 共享件 | 复用方式 | 依据 |
|---|---|---|
| `conformance/vectors/*.json`（18 套 / 508 cases） | Go runner 直接消费（§4.3 读取方式）；向量是权威，禁止内嵌期望值进 runner | 路线图 §17.1 第 1565-1573 行；RFC 0016 §7 第 190 行；conformance/README.md 第 3-4 条 |
| `conformance/fixtures/`（raw 字节夹具） | 按仓库相对路径读取，跨语言相同字节 | 路线图 §17.3 第 1595-1596 行；README"未来 Go 实现必须直接消费相同向量和 fixture" |
| registry 与 error code 数据（v7：41/187） | 冻结清单是数据；Go 的注册表代码自写，内容与 v7 序列化一致 | README.md:32；fc-manifest 第 26 行 |
| 协议 payload 固定字段与 exit 分类（`core.cli-output@1`/`core.batch-plan@1`/`core.batch-result@1`、`core.query-definition@1`、ProjectionRequest/MaterializationRequest 等） | 字段形状是契约；typed decoder 重验交叉约束照 v6/v7 先例 | RFC 0015；RFC 0016 §5.1/§6；cli-implementation-plan.md:197（Go CLI 同 schema 先例）、:199 |
| 上游官方 suite 数据（toml-test、yaml-test-suite、JSON5、五套 INI/Properties runtime oracle 记录） | 语言无关输入/事实，按对应里程碑消费 | README.md:34-37；fc-manifest 第 44-49 行；路线图 §17.4 第 1605-1617 行 |
| oracle exclusion inventory（HCL D-1..D-9、plist D-1..D-21、YAML 1 项） | 规范边界事实，Go 复现同样接受/拒绝 | hcl-go-v1/manifest.json、plist-macos-v1/manifest.json |
| mutation corpus（46 fixtures / 174,921 cases）与 fuzz regression 流程 | 语言无关语料与"regression 永久入 corpus"纪律 | fc-manifest 第 49-51 行；路线图 §15.3 第 1383 行 |
| FC manifest digest（conformance_suite 聚合 sha256） | runner 启动校验（§4.5） | fc-manifest 第 35-41 行 |

### 1.2 重新实现（Go 惯用实现，非 Rust 翻译）

- **值模型**（RFC 0016 §4.1 第 121-146 行冻结）：`core.Value` 封闭接口八 kind，exhaustive matching 无静默 `default`（第 134-136 行）；`core.Object` = 有序 `[]core.Entry`（**绝不用 `map[string]Value`**，第 125 行）；`core.Integer` 包装 `*big.Int`（第 128 行）；`core.Decimal` 规范化十进制、无 float round-trip（第 129 行）；`core.BinaryFloat64` 精确 IEEE-754 binary64（第 130 行）；`Equal`/`Hash` 与顺序相关（第 137-140 行）；对象构造时拒重 key（第 141-143 行）。
- **PVCE/1、PGCE/1 codec**：从协议规范 + 向量重实现；字节与 Rust codec 相等由向量和跨语言字节断言证明（RFC 0016 §4.2 第 150-153 行；路线图 §16.1 第 1469 行硬门禁）。
- **canonical JSON 传输**（RFC 0015 §3.2）：严格规范解码器，与 `consema-protocol` 的 canonical JSON 字节一致（RFC 0016 §4.2 第 152-153 行；protocol-v1/v2 双传输等价 32+11 case 先例）。
- **protocol 注册表校验**：Diagnostic 构造校验未知 code / category 矛盾即协议错误（RFC 0016 §6 第 182 行；RFC 0011）；`protocol.ClassifyErrorCode` 一次实现（第 184 行），SDK 自身不分类。
- **各家族 parser/query/projection/materialization/edit** 全套（0.15.0-0.18.0 按 §2 排期）。
- **内部树、缓存、算法**自由选择（路线图 §11.2 第 849 行）。

### 1.3 第三方依赖决策（含 rejected alternatives）

**政策：`go/` 模块运行时依赖仅 Go 标准库**（math/big、unicode/utf16 等）。依据：

1. RFC 0016 §10 全部 rejected alternatives：cgo/FFI 包装 Rust（第 218 行）、序列化 Rust 私有 AST（第 219 行）、bindgen 式代码生成（第 220 行）、Go map 表达 Object（第 221 行）、复用 Rust conformance runner（第 222 行）——全部拒绝；
2. 仓库零新外部依赖传统（cli-implementation-plan.md:19、:293——plist base64/date 自写先例）；Rust 侧 deny.toml `[sources]` 仅 crates.io 钉版（cli-implementation-plan.md:19）；
3. 双实现审计价值：任何第三方 parser 基座都会使"两个实现均独立，不通过 FFI 或私有中间结果作弊"（路线图 §22.2 第 1884 行）失去意义。

**具体拒绝清单（0.14.0 决策时记录于 RFC/实现文档的 rejected alternatives）：**

| 候选 | 拒绝理由 |
|---|---|
| `github.com/hashicorp/hcl/v2` + `zclconf/go-cty`（0.18.0 HCL） | HCL 实现必须自写。oracle 中 hashicorp/hcl 只是差分对侧（hcl-go-v1/manifest.json authority 段：go-cty "evaluation: never invoked"），SDK 导入即违反 §11.2 独立实现原则 |
| go-yaml 类 YAML parser（0.16.0） | 同上；YAML 1.2/1.1 Profile、anchor/alias/graph 语义（RFC 0007）与第三方库行为不兼容 |
| stdlib `encoding/xml`（0.17.0） | XML 1.0 safe Profile 的 entity deny-by-default、确定性恢复、byte-exact span 语义（SECURITY.md:32；RFC 0012）与 stdlib 行为不兼容；stdlib 只用于非契约辅助（如 encoding/hex） |
| `float64` 表达 Integer/Decimal | math/big 是 stdlib 且是 charter 指定基座（RFC 0016 §4.1 第 128 行）；无精度降级（README.md:5 向量字符串表示纪律） |

**go.mod 最低版本**：0.14.0 冻结（路线图 §21.2 第 1825、1831 行"Go 最低版本遵循公开支持政策并在 CI 验证"）。建议 `go 1.26`（当前安装 go1.26.5 为稳定版，与 hcl-go-v1 oracle 的 runtime pin 同版本）；任何例外须 RFC 级记录。

### 1.4 禁止复用边界

- 不得 import/链接/调用 Rust（cgo 禁止；RFC 0016 §1.1 第 48-50 行；路线图 §11.2 第 842 行；§16.1 第 1471 行硬门禁）。
- 不得消费序列化 Rust 私有 AST（RFC 0016 §1.1 第 51-53 行、§10 第 219 行）；唯一跨语言字节面：PVCE/1、PGCE/1、protocol transports（canonical JSON）、shared vectors（RFC 0016 §1.1 第 52-53 行）。
- 不得 import `conformance/oracles/hcl-go-v1/` 的 Go 代码（oracle 是第三方行为钉，与 SDK 是两个独立 module）。
- 不复制 Rust 枚举名漂移：一个注册 code 一个 Go 名字（RFC 0016 §5.3 第 173 行 F3、§8 第 205 行 F2/F3）。
- 语言无关拼写必须逐字节复现（RFC 0016 §8 第 198-208 行）：suite/family id（F13，第 202 行）、syntax-kind 拼写（F15：xml/plist kebab-case vs hcl/yaml PascalCase，第 203 行）、query operator id（F11，第 204 行）、projection/edit code（F4/F2，第 205 行）；v8 统一提案若通过则双语言一起改（第 207-208 行）。

---

## 2. 里程碑拆分（0.14.0–0.19.0，对应路线图 §16.1-§16.6）

行数估计为规划级（Go 源码含同模块测试），参考 Rust 各 crate 实测行数（本计划调研 2026-08-07：core 5604、graph 2364、protocol 18904、document 5038、json 8022、toml 5911、yaml 11610、ini 8287、properties 6435、xml 12813、plist 23697、hcl 24188），Go 语法更紧凑按 0.6-0.8 系数估计（体例照 cli-implementation-plan.md:8 的估计惯例）。`M` 为必须串行（前驱产物直接输入），`‖` 为可并行（文件域隔离，互不 import 对方中间产物，仅依赖共享公共 API）。

| 产品版本 | 子里程碑 | 依赖 | 并行性 | 预估规模 | 交付物（路线图交付清单） |
|---|---|---|---|---|---|
| 0.14.0 | G0.1-G0.5 | — | G0.1 → [G0.2 ‖ G0.3] → [G0.4 ‖ G0.5] | 11k-16k | §16.1 第 1455-1465 行九项 |
| 0.15.0 | G1.1-G1.5 | 0.14.0 | G1.1 → [G1.2 ‖ G1.3] → [G1.4 ‖ G1.5] | 11k-16k | §16.2 第 1479-1488 行 |
| 0.16.0 | G2.1-G2.4 | 0.15.0 | G2.1 → [G2.2 ‖ G2.3] → G2.4 | 12k-17k | §16.3 第 1496-1503 行 |
| 0.17.0 | G3.1-G3.3 | 0.16.0 | [G3.1 ‖ G3.2] → G3.3 | 13k-18k | §16.4 第 1515-1522 行 |
| 0.18.0 | G4.1-G4.4 | 0.17.0 | G4.1 → [G4.2 ‖ G4.3] → G4.4 | 12k-17k | §16.5 第 1530-1537 行 |
| 0.19.0 | G5.1-G5.7 | 0.18.0 | [G5.1 ‖ G5.2 ‖ G5.3 ‖ G5.4 ‖ G5.5] → [G5.6 ‖ G5.7] | 14k-23k | §16.6 第 1545-1555 行 |

总规模估计：0.14.0-0.18.0 Go SDK 约 59k-84k 行（对照 Rust 面约 137k 行，系数约 0.5-0.6），0.19.0 CLI 与编排另计。版本间严格串行（每版本有独立硬门禁与收口复核）。

### 2.1 0.14.0 — Go core、PVCE、PGCE 与协议（路线图 §16.1 第 1451-1473 行）

- **G0.1（串行起点）**：`go/` scaffold（go.mod 最低版本冻结、目录骨架）+ `core` package——PortableValue 八 kind、有序 Object/Array、strict equality/hash、BigInteger/Decimal/BinaryFloat64、PVCE/1 encode/decode（RFC 0016 §4.1/§4.2）。2500-3500 行。
- **G0.2（‖，依赖 G0.1）**：`graph` package——PortableGraph、graph equality/hash、节点身份顺序（RFC 0006）、PGCE/1 codec（RFC 0016 §4.1 第 144-146 行）。1000-1500 行。
- **G0.3（‖，依赖 G0.1）**：`protocol` package——language-neutral codecs、contract registry（v7 41 条）、error registry（v7 187 码）、Diagnostic 构造校验、Capability/Profile 描述符、QueryDefinition validation/binding、CLI machine protocol records（RFC 0015 v7：CliOutputMessage/BatchPlanMessage/BatchResultMessage）、`ClassifyErrorCode`（RFC 0016 §5.4/§6）。3500-5500 行。
- **G0.4（串行，依赖 G0.1-G0.3）**：`conformance` package + `cmd/consema-conformance`——Go runner（§4.3）。2000-3000 行。
- **G0.5（‖ G0.4，依赖 G0.1-G0.3）**：Go fuzz targets（Go 原生 fuzzing，对标路线图 §16.1 第 1465 行"Go fuzz targets"）+ 跨语言 PVCE/PGCE 字节相等 harness（§4.4）。1500-2200 行。

**硬门禁（§16.1 第 1469-1473 行）**：Rust 与 Go 的 PVCE/PGCE bytes 完全一致；shared vectors（适用 capability，§4.2）100% 通过；Go 不导入或调用 Rust；Go error text 不参与规范比较；protocol unknown-field/canonicality 规则一致。

### 2.2 0.15.0 — Go Document、JSON family 与 TOML（路线图 §16.2 第 1475-1490 行）

- **G1.1（串行起点）**：`document` package——raw SourceSnapshot、encoding facts、Span（byte offset）、NodeRef、ProfileId、FormationStatus（封闭二值 Complete/Recovered，RFC 0016 §5.1 第 160 行 F10）、ParseLimits、MaterializationRequest、SourcePatch（RFC 0016 §3.2 第 106 行）。2500-3500 行。
- **G1.2（‖，依赖 G1.1）**：`json` package——JSON/JSONC/JSON5 形成、native/syntax query、projection/materialization/provenance、scalar/structural edit、ChangeSet、`context.Context` 取消适配（§16.2 第 1487 行）。2500-3500 行。
- **G1.3（‖，依赖 G1.1）**：`toml` package——同 G1.2 全能力面。2000-2800 行。
- **G1.4（串行，依赖 G1.1-G1.3）**：根包起步——`Document` union、`Registry` 面（families/profiles/query domains/operation registries）、JSON↔TOML `Convert*` 两阶段组合（RFC 0016 §3.2 第 108 行；convert 只在根包）。1500-2200 行。
- **G1.5（‖ G1.4）**：cross-language normalized-result differential harness（§16.2 第 1488 行；§4.4）。1500-2500 行。

**硬门禁（第 1490 行）**：对应 Rust capability set 的共享向量 100% 一致。

### 2.3 0.16.0 — Go YAML、INI 与 Properties（路线图 §16.3 第 1492-1509 行）

- **G2.1（串行起点，本版本最大）**：`yaml` package——YAML 1.2/1.1 compatibility、anchor/alias/tag/graph、全操作与 security limits。5500-7500 行。
- **G2.2（‖，依赖 G1.1）**：`ini` package——Portable/Windows/Python ConfigParser 三 Profile（RFC 0009）。3000-4200 行。
- **G2.3（‖，依赖 G1.1）**：`properties` package——Reader/Latin-1 两 Profile（RFC 0010）、Java UTF-16 code units。2800-3800 行。
- **G2.4（串行，依赖 G2.1-G2.3）**：全操作补齐（query/projection/materialization/edit 闭包）+ security limits 矩阵 + Rust/Go cross-run fixtures（§16.3 第 1503 行）。1500-2500 行。

**硬门禁（第 1507-1509 行）**：Go graph identity 和 query ordering 满足同一 contract；alias bomb、cycle、INI dialect 和 Properties encoding 的负向向量一致；Go map 的随机迭代顺序不得影响任何公共结果。

### 2.4 0.17.0 — Go XML 与 plist（路线图 §16.4 第 1511-1524 行）

- **G3.1（‖）**：`xml` package——XML 1.0 safe Profile（RFC 0012）、namespace/mixed content、entity deny-by-default、byte-exact span、确定性恢复。5500-7500 行。
- **G3.2（‖）**：`plist` package——plist XML/binary 双表示、bplist offset/object-ref 编解码（照 Rust property_plist.rs 的每合法宽度 property tests 先例，fc-manifest 第 276 行）、binary offset hardening。6000-8000 行。
- **G3.3（串行，依赖 G3.2）**：macOS Foundation differential run（§16.4 第 1522 行）——消费 `conformance/oracles/plist-macos-v1/manifest.json` 的固定事实与 exclusion（D-1..D-21）。1000-1500 行。

**硬门禁（第 1524 行）**：Rust 与 Go 在 native normalized facts、报告、诊断 code/order 和 edit bytes 上一致。

### 2.5 0.18.0 — Go HCL 与全操作 parity（路线图 §16.5 第 1526-1539 行）

- **G4.1（串行起点，本计划最大单一交付）**：`hcl` package——HCL native/tfvars（RFC 0014）、expression/template native view（**不求值**，SECURITY.md:36；hcl-go-v1 oracle 先例 "evaluation: never invoked"）、HCL D-1..D-9 exclusion 语义。7000-9500 行。
- **G4.2（‖，依赖各家族）**：全格式 Materialization 补齐（根包 convert 全组合面）。2000-3000 行。
- **G4.3（‖，依赖各家族）**：全格式 mandatory structural Edit、SourcePatch 与 batch-plan protocol（RFC 0016 §5.3；RFC 0004）。2000-3000 行。
- **G4.4（串行，依赖 G4.1-G4.3）**：Go SDK examples 与完整文档（§16.5 第 1537 行）+ **capability parity 断言**：Go mandatory capability set 与 Rust Feature-Complete Manifest 对齐（第 1539 行硬门禁）。2000-3000 行。

### 2.6 0.19.0 — 双语言一致性与产品 Beta（路线图 §16.6 第 1541-1557 行）

- **G5.1（‖）**：shared conformance runner orchestration（§16.6 第 1547 行）——双 runner 同批执行与结果汇总（§4）。1500-2500 行。
- **G5.2（‖）**：Rust/Go bidirectional differential runs（第 1548 行）——双方向规范化结果比较 + differential corpus 追加（§17.4 第 1615 行）。1500-2500 行。
- **G5.3（‖）**：cross-language protocol exchange（第 1549 行）——Rust CLI 与 Go CLI 互认 machine output（§22.2 第 1882 行 cross-encode/decode 100%）。1000-1800 行。
- **G5.4（‖）**：full corpus、fuzz、benchmark 和 security matrix（第 1550 行）——Go 侧 release-candidate fuzz clean-run（§22.4 第 1903 行）与三平台验证（第 1907 行）。2000-3000 行。
- **G5.5（‖）**：SDK usability review（第 1551 行）——Go public API 稳定性审查（§22.2 第 1885 行；§21.2 六项政策核对：未导出字段/只读方法、context 只做取消、error code 与 message 分离、有序结果不用 map、iterator 显式 Close、最低版本 CI 验证）。文档。
- **G5.6（串行，依赖 0.14.0-0.18.0 全部）**：Go CLI beta——复用 RFC 0015 machine protocol（RFC 0016 §2.2 第 80-81 行；RFC 0015 是语言无关 schema，cli-implementation-plan.md:197 先例）；镜像 Rust CLI 的 11 命令面与 exit 分类（`protocol.ClassifyErrorCode` 单次实现，RFC 0016 §6 第 184 行）。5000-8000 行。
- **G5.7（串行）**：real-repository migration pilots（§23.2 必做工作流；§22.7 第 1937 行"Rust 与 Go 分别完成至少一个端到端 SDK pilot"）+ release/upgrade/rollback drill + `1.0.0-rc.1` 候选清单（§16.6 第 1555 行）。1500-2500 行。

**硬门禁（第 1557 行）**：第 22 节 `1.0.0` 门槛除 RC soak 外全部通过。

---

## 3. 多 agent 文件域划分表

每个并行里程碑派发一个 agent，文件域互不重叠；共享只读域为 `conformance/vectors/`、`conformance/fixtures/`、`conformance/corpora/`、`conformance/oracles/`、RFC 0016 与 fc-manifest（任何 agent 不得修改）。**任何 agent 的派发都受 §7 START GATE 约束。**

| Agent | 文件域 | 里程碑 | 前置（公共 API 输入） |
|---|---|---|---|
| A | `go/go.mod`、`go/go.sum`（政策零依赖，首版可能无 sum）、`go/core/` | 0.14.0 G0.1 | 无（最先）——但受 §7 START GATE |
| B | `go/graph/` | 0.14.0 G0.2 | core 公共 API |
| C | `go/protocol/` | 0.14.0 G0.3 | core |
| D | `go/conformance/` + `go/cmd/consema-conformance/` | 0.14.0 G0.4 | core+graph+protocol |
| E | `go/**/*_fuzz_test.go`、跨语言 PVCE/PGCE 字节 harness（`go/conformance/differential/` 雏形 + scripts） | 0.14.0 G0.5 | core+graph+protocol |
| F | `go/document/` | 0.15.0 G1.1 | core |
| G | `go/json/` | 0.15.0 G1.2 | document |
| H | `go/toml/` | 0.15.0 G1.3 | document |
| I | 根包（`go/*.go`：Document union、Registry、convert 组合） | 0.15.0 G1.4 | document+json+toml |
| J | `go/conformance/differential/`（normalized-result 双向 harness）+ 脚本 | 0.15.0 G1.5 | json/toml |
| K | `go/yaml/` | 0.16.0 G2.1 | document |
| L | `go/ini/` | 0.16.0 G2.2 | document |
| M | `go/properties/` | 0.16.0 G2.3 | document |
| N | `go/xml/` | 0.17.0 G3.1 | document |
| O | `go/plist/` | 0.17.0 G3.2 | document |
| P | `go/hcl/` | 0.18.0 G4.1 | document |
| Q | 全操作补齐（根包 convert 全组合、全格式 materialize、mandatory structural edit、SourcePatch、batch-plan） | 0.18.0 G4.2/G4.3 | 各家族 |
| R | examples + 文档 + capability parity 断言 | 0.18.0 G4.4 | 各家族 |
| S | `go/cmd/consema/`（Go CLI beta） | 0.19.0 G5.6 | protocol + 根包 |
| T | orchestration/differential/bench/security matrix | 0.19.0 G5.1-G5.4 | 全部 |
| U | pilots + release drill + `1.0.0-rc.1` 清单 | 0.19.0 G5.7 | 全部 |

约束（沿用体例）：

- 向量/语料与 runner 必须同批：runner 是向量的唯一权威执行者（cli-implementation-plan.md:423 体例；conformance/README.md 第 4 条）——Go runner 新增 suite 与向量变更同批合入，改期望必失败。
- 并行 agent 之间无共享写域；`go.mod` 变更只经 agent A（最低版本冻结权）。
- 双语言差分 harness（E/J/T）与 runner（D）分工：E/J 覆盖跨语言字节/规范化结果比较，D 覆盖 Go 侧单语言向量执行——两类不可互替。
- 质量基线（memory 约定）：Go 公共符号文档注释密度、错误处理模式（typed errors + `Code()` 接口，RFC 0016 §6 第 183 行）、命名（§1.4 拼写冻结）对齐仓库既有成熟 crate 体例；每个实质任务先派审计 agent 量化差距再派修复 agent。

---

## 4. conformance 集成细节

### 4.1 双 runner 契约（路线图 §17.1 第 1563-1573 行；RFC 0016 §7 第 190-194 行）

- **同一向量、两个 runner**：Rust runner（`crates/consema-conformance`）与 Go runner（`go/conformance` + `cmd/consema-conformance`）各自独立实现、各自执行全部 18 套共享向量。"Rust 测试通过不能代替 Go 测试，Go 测试通过也不能证明规范没有歧义"（§17.1 第 1573 行）；权威来自规范含义与两实现共同验证。
- 权威组成五元（§17.1 第 1565-1571 行）：normative prose + contract registry + machine-readable vectors + raw fixtures + independent Rust and Go runners。
- Go runner 直接消费 `conformance/vectors/*.json`（向量文件是权威，RFC 0016 §7 第 190 行）与 `conformance/fixtures/`（raw 字节，§17.3 第 1595 行）。

### 4.2 向量台账与里程碑适用面（18 套 / 508 cases，本计划逐文件计数）

| suite | cases | 首次适用里程碑 | 说明 |
|---|---|---|---|
| protocol-v1 | 32 | 0.14.0 | PVCE 双传输、registry、error code（RFC 0016 §4.2 第 150 行引用） |
| protocol-v2 | 11 | 0.14.0 | v2 双传输、伪造事实拒绝 |
| portable-graph-v1 | 10 | 0.14.0 | PGCE/1 固定字节 |
| semantic-model-v5 | 22 | 0.14.0 | registry v1-v4 冻结、payload 双传输 |
| semantic-model-v6 | 25 | 0.14.0 | v1-v5 冻结、外部 query payload |
| v1.json | 30 | 0.14.0（core/PVCE 面）→ 0.15.0（JSON 面） | 按 case 的 capability 分派 |
| source-v1 | 28 | 0.15.0 | SourceSnapshot/encoding/SourcePatch |
| json-family-v2 | 33 | 0.15.0 | JSON/JSONC/JSON5 全操作 |
| toml-v1 | 18 | 0.15.0 | TOML 全操作 |
| syntax-query-v1 | 19 | 0.15.0（json/toml 面） | 随家族扩展 |
| operations-v1 | 35 | 0.15.0（json/toml 面） | 随家族扩展至 0.18.0 |
| cli-v1 | 40 | 0.14.0（envelope/exit-class/batch 类型面）→ 0.19.0（detection/redaction CLI 面） | 协议面由 protocol codec 支撑；CLI 面随 Go CLI |
| yaml-v1 | 27 | 0.16.0 | YAML 1.2/1.1 全操作 |
| ini-v1 | 20 | 0.16.0 | 三 Profile |
| java-properties-v1 | 22 | 0.16.0 | 两 Profile |
| xml-1-0-safe-v1 | 34 | 0.17.0 | XML 1.0 safe |
| plist-v1 | 45 | 0.17.0 | XML/binary |
| hcl-v1 | 57 | 0.18.0 | HCL native/tfvars |

- 0.18.0 收口：18/508 全量 100%、零 documented skip；0.19.0 保持并叠加 cross-language 编排层（§17.2 第 1590 行）。
- 中途里程碑的通过标准：**适用 capability 的 case 100% 通过**；未实现 capability 的 case 进入 documented skip（带 capability 与原因，绝不静默，RFC 0016 §7 第 191 行）；skip 计数入 runner 报告。

### 4.3 Go runner 设计（镜像 `consema-conformance` 体例）

- **布局**：`go/conformance/` 一个 suite 家族一个 runner 文件（protocol_v1.go、portable_graph_v1.go、source_v1.go、…照 `crates/consema-conformance/src/lib.rs:3-25` 的模块清单对偶）；`cmd/consema-conformance` 为 CLI 驱动。
- **向量读取（不 embed 副本）**：`go:embed` 无法引用 module 目录树外的 `conformance/vectors/`（路径越界被拒绝）；且副本会造成第二权威源（违反 README 第 3 条"防止把预期值硬编码进 runner"精神）。决策：runner 通过显式路径参数读取仓库向量与 fixtures（`-vectors <repo>/conformance/vectors`、`-fixtures <repo>/conformance/fixtures`），与 RFC 0016 §7 第 190 行"reads conformance/vectors/*.json directly"一致；CI 以仓库路径运行；`go test` 内嵌测试用仓库相对路径解析。
- **每个 runner 固定校验**（conformance/README.md 第 4 条；lib.rs 自检体例）：suite id 校验、case id 去重、**case 计数断言**（改向量必失败）、按 capability 分派处理器、未知 action 拒绝。
- **数据驱动**：input/expected 实际驱动执行；禁止把期望值硬编码进 runner。
- **报告形态**：与 Rust runner 同构（suite id、case id、passed/skipped/failed 计数、skip 原因）；机器可读输出走 RFC 0015 信封语义（0.19.0 Go CLI 消费，cli-implementation-plan.md:197 先例）。
- **skip 纪律**：documented skip = success、never silent（RFC 0016 §7 第 191 行；oracle `skip_path` 先例：hcl-go-v1/manifest.json skip_path 段、wrapper exit 3）；0.18.0 后零 skip。

### 4.4 差分 harness 设计（跨语言）

- **0.14.0（硬门禁）**：跨语言 PVCE/PGCE 字节相等（RFC 0016 §7 第 192 行；§16.1 第 1469 行）——Go 侧 encode/decode 与 Rust 侧 encode/decode 双向字节相等 + 向量中的 pvce/graph hex 字段断言。
- **0.15.0**：cross-language normalized-result differential harness（§16.2 第 1488 行）——同一输入，Rust/Go 分别运行，比较规范化结果：parse formation、native facts、query count/identity/order、projection/materialization report、edit bytes（§11.2 第 849-861 行十二面）。
- **0.19.0**：bidirectional differential（§16.6 第 1548 行）+ cross-language protocol exchange（第 1549 行）——Rust CLI 与 Go CLI 互认 machine output（§22.2 第 1882 行 cross-encode/decode 100%）。
- differential corpus 追加式入 conformance（§17.4 第 1615 行"Rust/Go differential corpus"）；pilot 发现的缺陷入 regression corpus（§22.7 第 1938 行）。

### 4.5 聚合 digest 校验

Go runner 每次执行校验 `conformance/vectors/` 聚合 sha256 与 fc-manifest 的 `conformance_suite` 记录一致（fc-manifest 第 35-41 行：聚合方式"按文件名排序，逐文件 sha256，聚合 sha256(concat of 'name:digest' 行)"，当前值 e3d6578858…）——防止双 runner 各跑不同向量集；manifest 变更必须双 runner 同批更新。

---

## 5. 风险清单

| # | 风险 | 说明与缓解 | 复核时机 |
|---|---|---|---|
| R-1 | **START GATE 未关即开工**：0.13.0 门禁（C-1/C-2/C-3）开放时派发 Go 实现 agent | §7 门禁 + gatekeeper 检查；go/ 下任何文件创建前先核 fc-manifest status；违反即回滚该波次 | 每次派发前 |
| R-2 | parity drift：Go 证明规范歧义或 Rust 行为不可移植 | 路线图 §11.3 七步流程（第 863-875 行）：暂停对应 capability → 建立最小跨语言反例 → 分类（实现/测试/规范缺口）→ 先修正规范与 conformance → 公共行为改变则发布新 contract ID → Rust 先通过修订向量 → Go 再继续；禁止把偶然实现细节提升为标准（第 875 行）。RFC 0016 §7 第 193 行：FC Baseline 不是"Rust 永远正确" | 每个差分不一致 |
| R-3 | 契约解释分歧：同一向量两边解释不同 | 最小跨语言反例 + §11.3；oracle exclusion inventory（HCL D-1..D-9、plist D-1..D-21）是"规范边界须文档化"的既有先例 | 每 suite 首跑 |
| R-4 | 第三方实现诱惑（go-yaml/hashicorp-hcl/cty/encoding-xml 作基座） | §1.3 拒绝清单；oracle 只作差分对侧（hcl-go-v1/manifest.json authority 段）；违反即失去"独立实现"审计价值（§22.2 第 1884 行） | 0.16.0-0.18.0 每家族 |
| R-5 | Go map 迭代顺序泄漏进公共结果 | Object 用有序 `[]core.Entry`（RFC 0016 §4.1 第 125 行）；`-race` + 顺序断言测试；§16.3 第 1509 行硬门禁 | 0.16.0 起每里程碑 |
| R-6 | Go error text / 内部类型参与跨语言比较 | 错误文本是 human presentation only（RFC 0016 §6 第 186 行；§16.1 第 1472 行）；向量只比较稳定字段（§17.3 第 1600 行） | 每里程碑 |
| R-7 | canonical JSON / PVCE 字节漂移 | protocol-v1/v2 双传输等价向量（32+11 case）+ 双 runner 字节断言 | 0.14.0 起 |
| R-8 | 双 runner 向量集漂移（各自跳过不同 case） | case 计数断言 + 聚合 digest 校验（§4.5）；skip 必须文档化（§4.3） | runner 每跑 |
| R-9 | Go 工具链/最低版本漂移 | go.mod 最低版本 0.14.0 冻结，三平台 CI 验证（§21.2 第 1831 行）；门禁含 gofmt/vet/race/fuzz（第 1832 行） | 每个里程碑 |
| R-10 | 数值语义漂移（Integer/Decimal 精度） | math/big 基座、无 float64 round-trip（RFC 0016 §4.1 第 128-130 行）；向量字符串表示纪律（README.md:5） | 0.14.0 起 |
| R-11 | context.Context 滥用（隐藏业务参数） | 只用于取消/deadline（§21.2 第 1827 行；RFC 0016 §5.1 第 159 行） | 0.15.0 起 |
| R-12 | 差分覆盖不足 | differential corpus 追加式（§17.4 第 1615 行）；pilot 缺陷入 regression（§22.7 第 1938 行） | 0.15.0 起 |
| R-13 | Go CLI 与 Rust CLI 的 machine schema 漂移 | 同一 RFC 0015 protocol + cross-language protocol exchange（§16.6 第 1549 行）；machine schema 无 Rust 类型名（cli-implementation-plan.md:496 先例） | 0.19.0 |
| R-14 | Go 侧 72h fuzz 等价物缺失 | Go 原生 fuzzing（`go test -fuzz`）对标 §15.3；0.19.0 需 release-candidate fuzz clean-run（§22.4 第 1903 行） | 0.19.0 |
| R-15 | 行数/工期膨胀（hcl 24k、plist 23k 是 Rust 侧最大家族） | 版本内并行波 + 每版本收口复核（RFC 0016 §9 第 214 行）；HCL 最后交付即最大风险面，0.18.0 预留并行波（G4.2/G4.3） | 0.17.0-0.18.0 |

---

## 6. 验收门禁总表

| 门禁 | 体例来源 | 适用里程碑 |
|---|---|---|
| `gofmt -l` 干净、`go vet ./...`、`go test ./...`、`go test -race ./...`、`go mod tidy` 干净、`go build ./...` | 路线图 §21.2 第 1832 行（go vet、static analysis、race detector、fuzz 进发布门禁） | 每个里程碑 |
| 适用 capability 向量 100% + case 计数断言（中途 documented skip 计入报告） | RFC 0016 §7；conformance/README.md | 每个里程碑（0.14.0 起） |
| 聚合 digest 校验（fc-manifest conformance_suite） | fc-manifest 第 35-41 行 | runner 每次执行 |
| 跨语言 PVCE/PGCE 字节相等（双向） | §16.1 第 1469 行；RFC 0016 §4.2/§7 | 0.14.0 起每个里程碑 |
| protocol unknown-field / canonicality 规则一致 | §16.1 第 1473 行 | 0.14.0 |
| Go 不导入或调用 Rust（cgo 禁令） | §16.1 第 1471 行；RFC 0016 §1.1 | 每里程碑（依赖面审查） |
| Go error text 不参与规范比较 | §16.1 第 1472 行 | 每里程碑 |
| normalized-result 差分（parse/query/projection/materialization/edit） | §16.2 第 1488 行；§22.2 第 1883 行 | 0.15.0 起 |
| graph identity 与 query ordering 同一 contract；负向向量（alias bomb/cycle/INI dialect/Properties encoding）一致 | §16.3 第 1507-1508 行 | 0.16.0 |
| Go map 迭代顺序不影响任何公共结果 | §16.3 第 1509 行 | 0.16.0 起 |
| native normalized facts、报告、诊断 code/order、edit bytes 一致 | §16.4 第 1524 行 | 0.17.0 |
| macOS Foundation differential run | §16.4 第 1522 行 | 0.17.0 |
| **Go mandatory capability set == Rust Feature-Complete Manifest capability set，无 "Rust only" mandatory 行为** | §16.5 第 1539 行硬门禁 | 0.18.0 |
| 18/508 全量 100%、零 documented skip | §22.2 第 1880 行 | 0.18.0 起 |
| bidirectional differential + cross-language protocol exchange 100% | §22.2 第 1882 行 | 0.19.0 |
| Go public API 稳定性审查（§21.2 六项 + 文档注释门禁） | §22.2 第 1885 行；§16.6 第 1551 行 | 0.19.0 |
| Rust 与 Go 分别完成至少一个端到端 SDK pilot | §22.7 第 1937 行 | 0.19.0 |
| Go release-candidate fuzz clean-run + 三平台（Windows/Linux/macOS）全矩阵 | §22.4 第 1903、1907 行 | 0.19.0 |
| §22 全部门槛除 RC soak | §16.6 第 1557 行 | 0.19.0 收口 |
| 每 Go 里程碑开始时复核 fc-manifest（Go 起点与能力对齐不漂移） | RFC 0016 §9 第 214 行 | 每里程碑 |

---

## 7. START GATE（起始门禁；本计划最高优先级条款）

> **C-1/C-2/C-3 完成之前，不得发布 0.14.0、不得宣称任何 Go 里程碑关闭；`go/` 内实现按 §6 门禁独立验证。**（2026-08-07 decision record 修订：owner 已书面授权提前启动 go/ 0.14.0 G0.1-G0.3，原"门禁全闭前不创建任何实现文件"条款不再适用于已开工的 G0.1-G0.3。）

**2026-08-07 决策记录（owner 书面授权；路线图 §0 冲突解决层级：改路线图、不静默缩小承诺）：**

owner 决定：在 C-1/C-2/C-3 完成前启动 Go 实现（`go/`，0.14.0 G0.1-G0.3）。Go 里程碑顺序（§2）、验收门禁（§6）与 C-1/C-2/C-3 完成路径不变；`go/` 以 fc-manifest 为能力起点（路线图 §15.7 第 1445 行），不以工作树偶然状态为起点。决策记录落于 `docs/fc-manifest-0.13.0.json` 顶层 `decisions[0]`（2026-08-07）。

**§7 START GATE 条款（修订后）**：C-1/C-2/C-3 完成前不得发布 0.14.0、不得宣称任何 Go 里程碑关闭；go/ 内已开工的 0.14.0 G0.1-G0.3 按 §6 门禁独立验证（每波次实测 go build/vet/test/race/gofmt 全绿）。门禁翻转判定权仍在 fc-manifest 的书面状态（§7.3），下文 §7.1-§7.3 保留为"发布/里程碑关闭"侧的门禁条款。

### 7.1 门禁条件（全部满足才允许发布 0.14.0 / 宣称 Go 里程碑关闭）

1. `docs/fc-manifest-0.13.0.json` 的 `status` 由 `"gate_open"` 翻转为 `"closed"`（第 5-6 行），且 `feature_complete_judgment.verdict` 为 `"closed"`（第 504-506 行）；
2. 开放项全部关闭（第 513-541 行）：
   - C-1：CI 10 job 在 GitHub 干净 checkout 全矩阵全绿（closes A-4/A-9/SEC-9，第 515-522 行）；
   - C-2：每格式 72 CPU-hours release-candidate fuzz，零未解释问题（closes Q-7，第 524-531 行）；
   - C-3：真实发布密钥生成（含备份与吊销证书）与 0.13.0 发布执行，版本推进与 registry digest 回填（closes SEC-8 发布物侧，第 533-540 行；fc-manifest 第 16-18、28 行）；
3. 门禁记录由 0.13.0 gatekeeper / release owner 在 manifest 中书面确认（owner 字段：fc-manifest 第 521、530、539 行）。

### 7.2 依据（file:line）

- 路线图 §14.12 第 1345 行："只有第 15 节 Rust Feature-Complete Gate 全部通过，才允许开始 `0.14.0` 的 Go 实现"；
- 路线图 §15.7 第 1445 行：Go 以 Feature-Complete Manifest 为起点，不以本地工作树偶然状态为起点；
- 路线图 §11.1 第 826-836 行：Rust 全部功能实现 → 全部门禁通过 → Feature-Complete Baseline 冻结 → 才开始 Go 正式实现（"Go 开发不得提前与 Rust 格式实现并行"）；
- fc-manifest-0.13.0.json 第 6 行（status_meaning："仅在本判定翻转为 closed 后启动"）、第 506 行（verdict_meaning："0.14.0 Go 实现不得提前开始"）——以上为 2026-08-07 decision record 修订前的原文表述（修订后见 fc-manifest decisions[0] 与本文件 §7 决策记录）；
- docs/0.13.0-gate-plan.md:136（"0.14.0 不得在判定翻转前开始"）、:4（目标版本声明）。

### 7.3 执行规则

- 本计划文档是规划阶段唯一交付物：允许的 Go 侧活动仅限只读调研（`go version` 等环境检查）与本文档维护；任何实现活动（agent 派发、文件创建、依赖引入）必须等到 §7.1 全部满足。**2026-08-07 decision record 例外**：go/ 0.14.0 G0.1-G0.3（core/graph/protocol）已获 owner 书面授权开工并独立验证（§6），不适用本款"等待 §7.1"约束；0.15.0+ 里程碑派发仍按本款执行（除非另行书面决策）。
- 门禁翻转动作：0.13.0 gatekeeper 在 fc-manifest 中翻转判定并记录证据；**本计划不授权任何 agent 自行判定门禁已闭**——判定权只在 manifest 的书面状态。
- 启动后复核：每个 Go 里程碑开始时重新核对 fc-manifest（RFC 0016 §9 第 214 行）；manifest 或能力集变更必须双语言同批处理（RFC 0016 §8 第 207-208 行 v8 窗口纪律）。
- 门禁开放期间发现的任何"Go 侧预研"结论不得进入实现状态：按 §11.3 流程留档（路线图第 863-875 行），待门禁关闭后作为 0.14.0 输入。

---

## 8. 交付物与体例说明

- 本文档（`docs/go-implementation-plan.md`）是本次规划阶段的唯一新增文件；只读调研未触碰任何其他仓库文件；未运行 git commit。
- 行数估计为规划级（体例照 cli-implementation-plan.md:8），以 Rust 各 crate 实测行数为基准（§2 注）。
- 后续 0.14.0 实施时，本计划 §2/§3/§4 的里程碑、文件域与 conformance 契约作为派发 agent 的任务输入；§7 门禁状态必须先于一切任务核验。
