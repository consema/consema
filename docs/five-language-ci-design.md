# Consema 五语言 CI 与跨语言验证架构设计（规划阶段文档）

- 决策：2026-08-11（用户决策：TS/Python/Kotlin 三语言加入 1.0.0 release 标准，与 Rust/Go 同等地位）
- 体例：照 `docs/go-implementation-plan.md`（证据文化：每条声称标注 file:line；估计量标注"估计"）；
  本设计是 `docs/multi-language-implementation-plan.md` §5/§7 的 CI 落地面
- 范围声明：本文是规划阶段唯一交付物（只读调研产出）；不修改任何仓库文件、不运行 git commit
- 权威输入：`docs/multi-language-implementation-plan.md`、`docs/go-implementation-plan.md` §4/§6/§7、
  `.github/workflows/ci.yml`（现 10+2 job：10 Rust + go-1-26 + go-differential；**六仓拆分 2d7494f 后此句为拆分前快照——10 Rust 门禁归 consema-rs 仓、go-1-26 / go-differential 归 consema-go 仓，母仓 ci.yml 重建为 oracles / shared-conformance-digest / check 三 job**）、`conformance/README.md`、`docs/fc-manifest-0.13.0.json`、
  路线图 §17.1（第 1565-1575 行）/§21.2（第 1825-1834 行）/§22.2（第 1879-1887 行）/§22.4（第 1902-1910 行）

---

## 0. 总体结构

### 0.1 现状核查（2026-08-11 调研）

- **CI**：`.github/workflows/ci.yml` 单一 workflow，11 个 job = 10 个 Rust 门禁（lint/test/coverage/
  msrv/conformance/deny/audit/semver/oracles/package，ci.yml:25-307）+ `go-1-26`（ci.yml:321-331）。
  C-1 开放项记录此 10 job 需在 GitHub 干净 checkout 全矩阵全绿（fc-manifest-0.13.0.json:786-802）。〔注：本节为 2026-08-11 调研快照，已由 §10 实况取代——拆分前母仓 ci.yml 为 10+2 job（go-1-26 ci.yml:321 + go-differential ci.yml:344-375）；六仓拆分 2d7494f 后 go-differential 归 consema-go 仓（ci-go.yml:172-246），母仓 ci.yml 现为 oracles / shared-conformance-digest / check 三 job〕
- **差分 harness 现状（关键事实）**：`scripts/go-verify-byte-parity.ps1`、`go-verify-normalized-
  differential.ps1`、`go-verify-protocol-exchange.ps1`、`go-verify-shared-conformance.ps1` 目前**未接入
  CI**（.github 全域检索 `go-verify` 零命中）；按 go/README.md:821-850 的既定分工，.github 是 Rust
  门禁域，Go 的验证以本地执行 + 文档化完成路径为准。差分证据链：byte parity 68/68（51 PVCE + 17
  PGCE，go/README.md:776-798）、normalized 108/108 双向、protocol exchange 83/83 双向（
  five-element-review-1.0.0.md:35；实测 2026-08-10 本机重跑）。case 集：`conformance/differential/
  cases.json`（68，manifest `consema.differential.byte-parity@1`）、`normalized/cases.json`（108，
  `consema.differential.normalized@1`）、`protocol-exchange/cases.json`（83，
  `consema.differential.protocol-exchange@1`）——2026-08-11 逐文件实测；2026-08-12 自
  `go/conformance/differential/` git mv 迁移至共享位置（§3.5 已执行，单一权威）。
- **三语言 scaffold（盲写产物，工具链后台安装中）**：`typescript/`（package.json:16-19 的
  `check`=tsc --noEmit / `test`=node --test；devDeps 仅 typescript ~5.9.0 + @types/node，package.json:29-32；
  tsconfig strict，typescript/tsconfig.json:3-15）、`python/`（pyproject.toml:20 requires-python >= 3.12、
  :25 dev extra pytest、:30-32 testpaths=tests）、`kotlin/`（build.gradle.kts:6-7 kotlin 2.2.0、
  :13-15 jvmToolchain(17)、:18-22 kotlin.test + JUnit5、:24-26 useJUnitPlatform）。三语言均**零第三方
  运行时依赖**（测试框架除外，multi-language-implementation-plan.md:30）。
- **缺口（CI 上线前置，本设计 §7 列为实施批次）**：三语言均无测试目录（2026-08-11 Glob 实测）；
  `typescript/` 无 package-lock.json（npm ci 必需）；`kotlin/` 无 gradle wrapper（gradlew /
  gradle/wrapper/ 缺失）。

### 0.2 设计不变量（本设计不得违反）

1. **单字节权威**：Rust 编码器是 PVCE/1、PGCE/1 字节的唯一权威（multi-language-implementation-plan.md:18、
   go/README.md:559-590 "Rust side is the authority for the bytes"；路线图 §16.1 硬门禁）。每个新语言
   的字节证明只能对着 Rust golden 做，golden 转录自向量文件或 Rust 编码器输出，不是抄 Go 的测试
   （multi-language-implementation-plan.md:65）。
2. **单 digest**：conformance/vectors 聚合 sha256 `cfd6e296…`（fc-manifest-0.13.0.json:38）是五个 runner
   共钉的**同一个值**——digest 只覆盖语言无关的向量文件本身（fc-manifest-0.13.0.json:40），因此五个
   runner 各自计算必然得到同一值（§4）。
3. **每 runner 是向量的唯一执行者**：某语言的 conformance 测试只由该语言 runner 执行，不得跨语言
   委托、不得复用他语言 runner 的结果（conformance/README.md:81 第 3 条；go-implementation-plan.md:234
   "向量与 runner 必须同批"）。
4. **禁止复用边界**：不 import/调用/FFI 到 Rust、Go 或彼此（multi-language-implementation-plan.md:62；
   路线图 §22.2 第 1886 行"两个实现均独立，不通过 FFI 或私有中间结果作弊"扩展到五语言）。
5. **零运行时依赖**：运行时依赖保持零（测试框架除外），CI 强制验证（§1.3）。
6. **双向差分不弱化**：normalized 差分对每个新语言保持 forward（Rust 发射 → 语言比较+发射）与
   reverse（Rust consume 语言证据）两个方向（go-verify-normalized-differential.ps1:12-29），四语言
   各自独立双向，不合并、不抽样。

### 0.3 与既有体例的对应

- job 命名与结构照 ci.yml 既有风格（显式命名 job、timeout-minutes、strategy 仅用于 OS 矩阵）。
- 门禁体例照 go-implementation-plan.md §6（验收门禁总表）与 multi-language-implementation-plan.md §6
  （验收门禁总表）。
- START GATE 体例照 multi-language-implementation-plan.md §7（第 125-131 行）：工具链就绪后先执行
  L0 骨架构建 + 值模型单测 + PVCE golden 字节测试，通过后才允许宣称 L0 关闭；**CI job 随语言 L0
  门禁关闭同批上线**（§5）。

---

## 1. CI 矩阵设计

### 1.1 既有 10+2 job 到五语言映射

| 既有 job（ci.yml 行） | 性质 | 五语言等价物 / 处置 |
|---|---|---|
| lint（fmt+clippy+rustdoc，3 OS，:25-46） | Rust 专属 | 每语言各自的格式/类型门禁（§1.2 gates job）：TS = `tsc --noEmit` strict（package.json:17）；Python/Kotlin L0 无强制 linter（零依赖政策不引入 ktlint/ruff 等工具依赖，L5 可选文档化） |
| test（cargo test --workspace，3 OS，:48-61） | Rust 专属 | TS = `npm ci` + `npm test`（node --test）；Python = `pip install -e '.[dev]'` + `pytest`；Kotlin = `./gradlew --no-daemon test` |
| coverage（cargo-llvm-cov 硬地板 + -Trend，:77-113） | Rust 专属 | 三语言**无覆盖地板**（multi-language-implementation-plan.md §6 验收门禁无覆盖项）；每语言覆盖率趋势为 L5 可选，估计量：非 1.0.0 门禁项 |
| msrv（Rust 1.85 全门禁，:118-144） | Rust 专属 | 每语言最低版本验证（§1.2）：TS node >= 26（package.json:8 engines；CI 钉 '26.x'）；Python 3.12（pyproject.toml:20；CI 钉 '3.12.x'）；Kotlin 2.2.0 + JVM 17（build.gradle.kts:6-7, 13-15）。注意与 Rust 的差别：Rust 的 stable ≠ msrv 是两套工具链；三语言 CI 钉的版本**就是**最低版本（"really verified in CI" 由构造满足，路线图 §21.2 第 1833 行精神） |
| conformance（cargo test -p consema-conformance + suite-count 断言，:145-173） | Rust runner 腿 | 每语言独立 conformance job（§2）：TS/Python/Kotlin 各一，runner 内做 18/519 + digest 断言（不复制 ci.yml:155-173 的内联 PS 脚本——断言进各语言 runner 测试，单一来源） |
| deny（cargo deny check，:175-184） | Rust 依赖政策 | 每语言零运行时依赖断言 + 开发依赖审计（§1.3）：TS `npm ls --omit=dev` 空 + `npm audit`（L5）；Python `dependencies = []`（pyproject.toml:22）断言 + `pip check`；Kotlin runtimeClasspath 空断言 + gradle 依赖锁定/验证（L5） |
| audit（cargo audit / RustSec，:186-199） | Rust 供应链 | 同 deny 行。安全面 = 运行时零依赖 → 供应链面只剩 dev 工具（typescript/@types/node、pytest、kotlin.test+junit-jupiter）；L5 收口时逐语言审计并记录（照 SEC-6 体例，fc-manifest-0.13.0.json:510-518） |
| semver（cargo-semver-checks，:201-235） | Rust API 稳定性 | **Rust 专属**。三语言 API 稳定性门禁属 1.0.0 收口（路线图 §22.2 第 1887 行"Rust/Go public API 都完成稳定性审查"扩展至五语言；multi-language-implementation-plan.md:111）：TS exports 冻结审查 / Python `__all__` 审查 / Kotlin public API dump（kotlinx binary-compatibility-validator 属 dev 依赖，政策允许），全部 L5+ |
| oracles（差分 oracle 3 OS，:251-281） | 语言无关（第三方行为钉） | **不变**，仍由 Rust job 执行。注意：java-properties-v1 oracle 钉 OpenJDK 25.0.4（conformance/README.md:25）、python-configparser-v1 钉 CPython 3.14.6（:26）——这是第三方行为 pin，与 SDK 工具链（Kotlin JVM 17 / Python 3.12）是两回事，不得混淆 |
| package（verify-package-archives，:283-307） | Rust 归档验证 | Rust 专属。每语言打包验证为 L5/1.0.0 门禁（§5）：TS `npm pack` + 干净目录安装；Python build wheel + 干净 venv 安装；Kotlin gradle jar + 干净 JVM 运行 |
| go-1-26（拆分前母仓 ci.yml:321-331；六仓拆分后归 consema-go 仓） | Go 门禁（最低版本） | **保持原位**（不迁移，见 §5.2 决策）；是三个新语言 gates job 的直接模板 |
| go-differential（拆分前母仓 ci.yml:344-375，2026-08-12 增补，见 §10；六仓拆分后归 consema-go 仓 ci-go.yml:172-246） | Go 差分 gate（byte parity + normalized + protocol exchange） | **保持原位**；是三个新语言 differential job 的直接模板 |

### 1.2 新语言 job 定义（每语言三个 job，L0 版）

对语言 L ∈ {ts, python, kotlin}，随其 L0 门禁关闭上线三个 job（§5.2）：

| job 名 | name | runs-on | 步骤（L0 版） |
|---|---|---|---|
| `L-gates` | "L gates (fmt/type + unit tests + zero-dep)" | ubuntu-latest，timeout 30 | checkout → 工具链（TS: actions/setup-node@v4 node-version '26.x' + cache npm；Python: actions/setup-python@v5 python-version '3.12.x'；Kotlin: actions/setup-java@v4 Temurin 17 + gradle/actions/setup-gradle@v4 cache）→ 静态/类型检查（TS: `npm ci` + `npm run check`；Kotlin: `./gradlew --no-daemon compileKotlin` 或 build 前段；**Python 无 fmt/type 步骤——python-gates 实际为 compileall + pytest + zero-dep（2026-08-13 修复后），job 名中的 "fmt/type" 是设计期措辞，Python 侧以 pytest 全量套件代替**）→ 单元测试（`npm test` / `pytest` / `./gradlew --no-daemon test`）→ 零依赖断言（§1.3） |
| `L-conformance` | "L conformance runner (18 suites / 519 cases)" | ubuntu-latest，timeout 60 | checkout → 工具链 → 运行该语言 runner（§2.2）。runner 内部完成：digest 校验 + 18/519 计数断言 + 逐 case 执行 + documented skip 报告；L5 起零 skip 断言 |
| `L-differential` | "L differential vs Rust (byte parity [+ normalized] [+ protocol exchange])" | ubuntu-latest，timeout 60 | checkout → cargo（swatinem/rust-cache@v2）→ 工具链 → 逐脚本运行 `scripts/L-verify-byte-parity.ps1`（L0 起）、`scripts/L-verify-normalized-differential.ps1`（L1 起）、`scripts/L-verify-protocol-exchange.ps1`（L4 起）、`scripts/L-verify-shared-conformance.ps1`（L4 起，§3.6）；脚本内断言"测试必须 RUN 而非 SKIP"（照 go-verify-byte-parity.ps1:117-124 体例） |

### 1.3 零运行时依赖政策的 CI 强制（deny/audit 的五语言等价物）

- **TS**：`npm ls --omit=dev` 必须空输出（package.json:29-32 仅 devDependencies 即满足）；package-lock.json 必须入库（npm ci 前置）。
- **Python**：pyproject.toml:22 `dependencies = []` 由 CI 断言（脚本读取 pyproject 校验）+ `pip check` 干净。
- **Kotlin**：Gradle `configurations.runtimeClasspath` 为空断言（build.gradle.kts:18-22 的依赖全在 testImplementation/testRuntimeOnly）；gradle 依赖锁定（gradle.lockfile）与 wrapper `distributionSha256Sum` 钉版（§6 R-4）。
- 该断言放 gates job 末步；违反即红（等价于 deny job 的角色）。

---

## 2. 共享 conformance runner（五 runner 契约）

### 2.1 五 runner 原则

- **同一向量、五个 runner**：Rust（crates/consema-conformance）、Go（go/conformance + cmd/
  consema-conformance）、TS、Python、Kotlin 各自独立实现、各自执行全部 18 套共享向量
  （conformance/vectors/，18 文件 / 519 cases，2026-08-12 实测）。权威五元扩展为七元
  （multi-language-implementation-plan.md:6-7：normative prose + contract registry + machine-readable
  vectors + raw fixtures + independent runners × 5）。"Rust 测试通过不能代替 Go 测试"（路线图 §17.1
  第 1575 行）平移为"任何语言 runner 的通过都不能代替其他语言 runner"。
- **无跨语言委托**：`L-conformance` job 只运行 L 语言 runner；Rust runner 不为新语言代跑；新语言
  runner 之间互不调用。
- **向量读取方式（照 Go 先例）**：不 embed 副本（go-implementation-plan.md:278 论证：副本造成第二
  权威源）；runner 通过显式仓库相对路径读取 `conformance/vectors/` 与 `conformance/fixtures/`。
  Rust runner 保持现状（嵌入向量、无 digest check——该缺口由共享 conformance 脚本补，
  go-verify-shared-conformance.ps1:16-17）；Go 与三新语言 runner 每次执行自验 digest（§4.2）。
- **oracle 套件执行边界（2026-08-12 审计决策，rc 前六角色审计 P2）**：`conformance/oracles/` 的 7 套件
  / 72 cases（java-properties-v1 11、python-configparser-v1 9、dotnet-ini-v1 7、windows-ini-v1 5、
  qt-ini-v1 4、plist-macos-v1 7、hcl-go-v1 29；manifest 实测，旧口径 102/28/38 与 manifest 不符，
  以 manifest 为准）是外部运行时行为钉（OpenJDK 25.0.4、CPython 3.14.6
  embeddable、.NET SDK 10.0.302、Windows wide profile API、Qt 6.10.2 MinGW、macOS Foundation/plutil、
  HCL v2.21.0 Go module），**不扩展给 TS/Py/Kt runner**：三语言 CI 无法原生运行被钉的外部运行时；
  且每个 oracle 的 comparison 契约（ConfigParser defaults/raw 视图与 casefold、异常分类映射、
  plist five-leg 对比表、HCL accept/reject 映射、TSV 传输与 hex digest）是随录制运行时冻结的适配器
  语义，逐语言复刻 = 复制 Rust runner 逻辑，违反"runner 只是执行器"（conformance/README.md 第 3 条）。
  oracle 的跨语言覆盖由 Rust（java-properties / python-configparser / dotnet-ini / windows-ini /
  qt-ini 五套件 36 cases，权威）+ 规范仓 CI oracles job（run-hcl-go-oracle.ps1 /
  run-plist-macos-oracle.ps1，29 + 7 cases，exit 3 = documented skip）+ Go（plist-macos-v1 7 cases）
  执行，再加 §3 双向差分 harness（byte parity / normalized / protocol exchange，对照 Rust 发射器）
  保证；
  TS/Py/Kt 的同一行为面由 519 共享向量 + fixture round-trip 门禁（2026-08-12 审计批次，
  TS `typescript/src/conformance/fixtures.test.ts`、Python `python/tests/{yaml,ini,properties}/
  test_fixtures.py`、Kotlin `kotlin/src/test/kotlin/consema/conformance/FixtureRoundTripTest.kt`）覆盖。

### 2.2 每语言 runner 设计（镜像 go/conformance 体例，go-implementation-plan.md:275-282）

| 项 | 设计 |
|---|---|
| TS | `typescript/src/conformance/`：node:test 驱动（package.json:17 的 `node --test src/` 即覆盖），每 suite 一个 test 文件（protocol_v1.test.ts…照 crates/consema-conformance/src/lib.rs:3-25 模块清单对偶）；`npm run conformance` 脚本可选（CLI 形式） |
| Python | `python/src/consema/conformance/` runner 模块 + `python/tests/conformance/` pytest 套件（pyproject.toml:30-32 testpaths 即覆盖）；可选 `python -m consema.conformance` CLI（照 cmd/consema-conformance 先例） |
| Kotlin | `kotlin/src/test/kotlin/consema/conformance/` kotlin.test/JUnit5 套件（build.gradle.kts:24-26 useJUnitPlatform 即覆盖） |
| 固定校验（每 runner 必做） | suite id 前缀 `consema.*` 校验（ci.yml:164-166 体例）；case id 去重；**case 计数断言 18/519**（conformance/README.md:81-82 第 4 条"每个 suite 必须验证 case 数量"）；聚合 digest 断言（§4.2）；未知 action 拒绝 |
| 数据驱动 | input/expected 实际驱动执行；禁止把期望值硬编码进 runner（conformance/README.md:73、:80 第 3 条"runner 只是执行器"） |
| skip 纪律 | 未实现 capability 的 case 进 documented skip（带 capability + 原因，绝不静默；RFC 0016 §7 第 191 行，go-implementation-plan.md:273）；L5 起零 skip |
| 报告形态 | 与 Rust/Go 同构的共享报告（§2.3）：suite file、case id、passed/skipped/failed 计数、skip 原因；机器可读输出照 RFC 0015 信封语义（go-implementation-plan.md:281） |

### 2.3 共享报告契约（五 runner 对比的公共语言）

- 既有事实：Rust 侧由 `emit_conformance_reports.rs` 产出 `shared-conformance.json`（
  go-verify-shared-conformance.ps1:157-167）；Go 侧由 runner CLI 产出同形报告、`go/conformance/
  shared.go` 转成共享契约后逐 case 对比（go-verify-shared-conformance.ps1:203-248）。
- 设计：**共享报告契约 v1**（JSON：每 suite 的 file 名、case id、verdict passed/skipped/failed、
  skip 的 capability+reason；无 error text）——三新语言 runner 各自产出同形报告，语言侧对比测试
  复刻 `shared_run_test.go` 的逐 case 对比语义（same verdict both sides；skip 必须两侧同 skip，
  -StrictSkips 时不对称即阻断，go-verify-shared-conformance.ps1:33-47）。
- **对比拓扑 = 星型（Rust 锚居中）**：只做 Rust vs 每语言（4 对）；不做全对（10 对）。
  理由：(a) 每 runner 是唯一执行者——对比的语义是"语言 X 与锚一致"，不是"X 与 Y 一致"；
  (b) O(N²) 无新信息——任何两非 Rust 语言的分歧必然先在一对 Rust 对比中显现；(c) 若未来某对
  非 Rust 语言出现 Rust 仲裁不见的分歧，再追加可选 pairwise job（记录为 rejected alternative，不
  入本期设计）。

---

## 3. 差分 harness 从 2 语言扩展到 5 语言

### 3.1 总体形状：每语言一套脚本、同一组 Rust 例子

- Rust 侧四个例子**零改动**：`emit_parity_bytes.rs`、`emit_normalized_results.rs`（emit + `--consume`
  双模式）、`emit_protocol_exchange.rs`（emit + `--verify` 双模式）、`emit_conformance_reports.rs`
  （crates/consema-conformance/examples/，2026-08-11 实测存在）。它们只消费 case 文件与输出目录，
  天然支持任意语言侧。
- 每语言新增 4 个脚本，命名照 `go-verify-*` 惯例：
  `scripts/{ts,python,kotlin}-verify-byte-parity.ps1`、
  `-verify-normalized-differential.ps1`、`-verify-protocol-exchange.ps1`、`-verify-shared-conformance.ps1`。
  结构镜像各自 go 双胞胎（自包含、Windows PowerShell 5.1 兼容、无第三方依赖；pwsh 在 ubuntu runner
  上运行，ci.yml:90/157/265 先例）。

### 3.2 字节 parity（Rust 编码器 = 字节权威）

- 流水线照 go-verify-byte-parity.ps1:11-21 平移：cargo build（--locked -p consema-conformance
  --example emit_parity_bytes，swatinem/rust-cache 缓存）→ 共享 case 集（§3.4）→ 语言侧测试
  （TS: `typescript/src/differential/parity/`；Python: `python/tests/differential/`；Kotlin:
  `kotlin/src/test/kotlin/consema/differential/`）在 golden 目录环境变量存在时执行：本语言编码字节
  vs `<case-id>.hex` golden 逐字节相等 + **双向方向**（golden 字节 → 本语言 decode → 本语言
  re-encode，照 differential_test.go 体例，go/README.md:781-785）。
- 环境变量：沿用 `CONSEMA_DIFFERENTIAL_RUST_DIR` 命名（它就是 Rust 侧 golden 目录，语义不变）；
  语言侧测试缺变量时 documented skip、绝不静默（go/README.md:783-785）；脚本断言测试 RUN 而非
  SKIP（go-verify-byte-parity.ps1:117-124）。
- 每语言同时覆盖向量文件内 `pvce.*`/`pgce.*` hex 字段（portable-graph-v1.json 的固定字节，
  go/README.md:567-589）——两条 golden 路径互补。

### 3.3 normalized-result 差分（双向 × 4，不弱化）

- 对每个语言独立跑完整双向流水线（照 go-verify-normalized-differential.ps1:12-29）：
  forward = Rust emit_normalized_results 发射 `<case-id>.txt` golden → 语言测试逐字段比较
  （case id + field + 两侧值，分歧即红）并发射该语言证据文件 → reverse = Rust `--consume
  <lang-evidence-dir>` 重算并逐字段对比（exit 1 = 分歧）。
- 每语言脚本各自设置证据目录环境变量（go 脚本用 CONSEMA_DIFFERENTIAL_NORMALIZED_GO_DIR；
  新语言用 CONSEMA_DIFFERENTIAL_NORMALIZED_{TS,PYTHON,KOTLIN}_DIR，golden 侧沿用
  CONSEMA_DIFFERENTIAL_NORMALIZED_RUST_DIR）。
- 比较面 = 语言无关行为面十二项（路线图 §11.2，go-verify-normalized-differential.ps1:32-38：
  parse formation、diagnostic code/order（非 text）、query count/identity/order、projection/
  materialization report、edit bytes、resource-limit completion）——**error text 不参与**（RFC 0016
  §6 第 186 行）。
- 分歧处置 = §11.3 流程（最小跨语言反例 → 分类实现/测试/规范缺口；禁止静默"修 Rust"，
  go-verify-normalized-differential.ps1:38）。

### 3.4 protocol exchange（五语言 cross-encode/decode）

- 照 go-verify-protocol-exchange.ps1:11-28 平移：Rust emit 模式产出 `<case-id>.json.hex`/
  `.pvce.hex`/`.error.txt`（Rust 侧自验 decode/re-encode 字节同一性 + 拒绝码）→ 语言测试
  （字节 parity + Rust 字节 → 语言 decode 记录等价 + 字节同一 re-encode + 语言侧拒绝码）→
  语言侧发射自己编码器文件 → Rust `--verify` 模式闭合语言 → Rust 方向（记录等价 + 字节同一
  re-encode + 拒绝码一致）。路线图 §22.2 第 1884 行"protocol cross-encode/decode 100%"扩展至
  五语言。

### 3.5 共享 case 集（消除五份拷贝）

- **现状（已执行 2026-08-12）**：三份 case 文件原在 `go/conformance/differential/` 下（68/108/83，
  实测）。语言无关的 case 集（kind/format/profile/source/steps，go/README.md:776-781）放在某语言
  目录下，会随语言数增长成 5 份拷贝 → 拷贝漂移 = 差分 corpus 碎片化，违反单权威精神。
- **设计（已执行）**：新语言 case 集放共享只读位置 `conformance/differential/`（新目录）：
  `cases.json`（byte-parity 68）、`normalized/cases.json`（108）、`protocol-exchange/cases.json`
  （83）；**现有 go/ 下三文件已随本批次 git mv 迁移**（2026-08-12：go 侧测试由内嵌改为运行时
  读取——`CONSEMA_DIFFERENTIAL_CASES_DIR` 或默认向上探测，五语言 harness 与 12 个 verify 脚本
  同步更新，同一批——照"向量与 runner 必须同批"纪律，go-implementation-plan.md:234）。
- 每语言完整性测试断言：manifest id（`consema.differential.byte-parity@1` / `normalized@1` /
  `protocol-exchange@1`）+ **精确 case 计数**（68/108/83）+ 下限（>= 40，照 go-verify-byte-parity.ps1:
  56-59 体例）——单文件、五处共钉，任何一侧漂移即红。
- corpus 追加纪律扩展：任何语言差分发现的 case 追加到共享文件（go-verify-normalized-
  differential.ps1:40-59 的 1-2-3 步骤，加入"语言无关"声明）；语言无关缺陷进
  conformance/corpora/mutation-v1.json 的 regressions 数组（脚本只读，不写）。

### 3.6 shared-conformance 双 runner 对比扩展到五

- 每语言 `scripts/L-verify-shared-conformance.ps1`：digest 独立验证（§4）→ Rust 报告
  （emit_conformance_reports）→ 语言 runner CLI 同 18 套 → 语言侧对比核心（复刻
  go/conformance/shared.go 逐 case 对比）→ 每 suite 双侧计数表 → 总判定。
- 对比语义照 go-verify-shared-conformance.ps1:33-47：passed/passed、skipped/skipped（同 case 同
  capability 同文档化）、failed/failed 一致；单侧 documented skip 不对称默认报告、-StrictSkips 阻断；
  未文档化 skip / pass-vs-fail / 清单漂移 = 硬不匹配。

---

## 4. 聚合 digest：五 runner 共钉一个值

### 4.1 算法与口径（不变）

- SHA-256 聚合，算法冻结于 fc-manifest-0.13.0.json:40：按文件名字节序排序（Ordinal），逐文件
  sha256（小写 hex），行格式 `{basename}:{digest}` 以 `\n` 连接（无尾换行），对该 UTF-8 字节串再
  sha256。实现参考 go-verify-shared-conformance.ps1:104-123。
- **口径 = 规范 checkout 字节（LF，.gitattributes:1 eol=lf）**；CRLF 工作树（core.autocrlf=true）
  下逐文件 sha256 不同属预期（fc-manifest-0.13.0.json:40；go-implementation-plan.md:293）。
- digest 只覆盖 18 个向量文件（语言无关）→ 五个 runner 各自计算必然同一值——这是"五语言共享
  一个 digest"的机制本身，无需任何跨语言通信。

### 4.2 钉值位置与双重校验

1. **manifest 记录（运行期校验）**：`docs/fc-manifest-0.13.0.json` `digests.conformance_suite`
   （第 35-41 行：suites=18 / cases=519 / aggregate_sha256=`cfd6e296da5b22b62d37b076d35bf6bbf58b0678ceddb37eea51a8b47200ab6a`）。
   每个新语言 runner 启动时校验 computed == 记录值（照 Go runner 的 -manifest 行为，cmd/
   consema-conformance/main.go:27-29；Rust runner 无此检查，由共享 conformance 脚本补齐一次，
   go-verify-shared-conformance.ps1:16-17）。
2. **每 runner 测试内硬钉（变更即红）**：每个语言的 runner 测试把聚合值 `cfd6e296…` 与计数
   18/519 作为常量断言（"双语言共钉"扩展到"五语言共钉"，multi-language-implementation-plan.md:15）。
   该硬钉是 suite-count 断言（ci.yml:155-173）的语言内等价物——向量增删而不更新五处 = CI 红。

### 4.3 变更纪律（同批五处）

向量文件变更 → 同批更新：fc-manifest 记录（gatekeeper）+ 五个 runner 的硬钉常量 + 五份语言
conformance job 全绿。此纪律是 go-implementation-plan.md:293 "manifest 变更必须双 runner 同批
更新"的五语言推广。

---

## 5. 分阶段实施（绑定 START GATE）

### 5.1 门禁绑定

multi-language-implementation-plan.md:125-131 §7 START GATE：工具链就绪后先验证 L0 骨架构建 +
值模型单测 + PVCE golden 字节测试，通过后才允许宣称 L0 关闭。**CI 上线是 L0 关闭批次的组成部分**：
`ci-L.yml` 文件与 fc-manifest 的 L0 关闭记录同批合入；盲写产物（门禁未过）不得进入任何 CI 证据
（multi-language-implementation-plan.md:131）。

### 5.2 推荐 CI 形状：每语言一个 workflow 文件（拒绝单矩阵）

**推荐：`ci.yml` 保持不变（Rust 10 job + go-1-26 原位），新增三个文件**：
`ci-typescript.yml`、`ci-python.yml`、`ci-kotlin.yml`。理由：

1. **START GATE 分期**：语言 L 的 workflow 文件随 L 的 L0 关闭同批新增——不触碰 Rust 门禁文件，
   Rust gate 零回归风险；单文件矩阵方案则每次语言上线都要改 gatekeeper 域文件（ci.yml 注释
   :1-10 明示其为 Rust gate 域）。
2. **多 agent 文件域纪律**：go-implementation-plan.md:235-237 与 go/README.md:821-822 确立 ".github 是
   Rust 门禁域"；五语言下自然演化为"每语言文件域含自己的 workflow 文件"，语言 agent 只碰自己的
   CI 文件（仍须经 gatekeeper 合入批次）。
3. **工具链异构**：setup-node / setup-python / setup-java+gradle 各不相同；单矩阵必然长出按语言
   分叉的条件步骤，与仓库"显式命名 job"文化（ci.yml 11 个显式 job）相悖。
4. **GitHub 侧隔离**：语言 A 的 workflow 语法错误不影响语言 B 与 Rust gate（文件级失败隔离）；
   每语言可独立回滚。

**rejected alternative**：单 ci.yml + strategy.matrix（语言维度）。拒绝理由：改动共享门禁文件、
矩阵内条件步骤可读性差、语言间失败耦合、违反 .github 域纪律。

### 5.3 每语言 rollout 顺序（job 内容随里程碑成长）

| 里程碑关闭 | 该语言 CI 内容（L-differential job 逐步加脚本） |
|---|---|
| L0（core+PVCE/PGCE+protocol） | `L-gates`（构建+单测+零依赖）、`L-conformance`（runner 全 18 套、未实现 capability 进 documented skip；digest+18/519 硬钉）、`L-differential` = byte parity + shared-conformance |
| L1（document+json+toml） | `L-differential` += normalized differential（json/toml 面使然） |
| L2/L3（yaml/ini/properties/xml/plist/hcl） | 无新 job；conformance job 的 skip 数随 capability 收敛 |
| L4（全操作 parity + capability parity） | `L-differential` += protocol exchange；`L-conformance` 断言 capability parity（照 go/capability_parity_test.go 体例，go/README.md:797-809） |
| L5（runner 全 519 + fuzz/bench/security + CLI beta） | `L-conformance` 断言**零 documented skip**；新增 `L-package`（§1.1 package 行）；fuzz/bench/security 冒烟进 CI（短时长）；三平台矩阵按 Go 先例走文档化完成路径（go/README.md:814-850，"completion path documented, not a CI job"）或显式 3-OS 矩阵 job——二选一在 L5 批次记录（**已处置 2026-08-12：文档化完成路径，§10 记录**） |
| 1.0.0 收口 | 每语言 API 稳定性门禁（§1.1 semver 行）；五语言全部 job 全绿入 §22/五要素审计（multi-language-implementation-plan.md:111） |

**语言间并行**：三语言 L0-L5 完全并行（multi-language-implementation-plan.md:38-39 "三语言之间
完全并行"）；各语言独立按自己门禁上线，先过先上。go-1-26 job 保持原位（迁移它需要触碰 ci.yml，
无收益；其存在已满足 Go 最低版本 CI 验证，go/README.md:493-497）。

---

## 6. 风险清单

| # | 风险 | 缓解 |
|---|---|---|
| R-1 | **跨平台**：新语言仅 ubuntu（估计） | 三语言均跨平台（无 Windows 专属 API 面）；单 OS 照 go-1-26 先例（ci.yml:321-331）；3-OS 全矩阵属 L5/1.0.0（路线图 §22.4 第 1909 行），按 Go 先例文档化完成路径（go/README.md:814-850）。差分脚本均为 pwsh（ubuntu runner 可用，ci.yml:90 先例） |
| R-2 | **Kotlin Gradle 依赖下载**（首次构建拉 Gradle 发行版 + Kotlin 插件 + JUnit，估计 2-5 分钟，网络不稳定时更长） | gradle wrapper 入库 + `distributionSha256Sum` 钉版（当前 wrapper 缺失，§0.1 缺口）；gradle/actions/setup-gradle@v4 缓存；gradle.lockfile 依赖锁定；timeout 60 分钟余量 |
| R-3 | **Python 版本钉**：CI 误用最新版（3.14+）掩盖 3.12 最低版本语义 | setup-python 显式 '3.12.x'；pyproject.toml:20 requires-python >= 3.12 为声明 + CI 钉为验证（"really verified" 由构造满足）；注意与 python-configparser-v1 oracle 的 CPython 3.14.6 pin（conformance/README.md:26）区分——那是第三方行为钉，不是 SDK 工具链 |
| R-4 | **npm registry 访问 / 供应链** | package-lock.json 必须入库（npm ci 前置，当前缺失 §0.1）；devDeps 仅 2 项（package.json:29-32）；npm audit 于 L5 收口；引擎钉 node '26.x'（package.json:8 engines >= 26） |
| R-5 | **wall-clock 预算** | 现状估计：Rust 全套 ~10-15 分钟（并行 job）；新增 9 job（3 语言 × 3）各估计 5-15 分钟（gates 3-8 / conformance 2-5 / differential 5-10，Rust 例构建由 rust-cache 摊销、cargo build --locked 每次仅增量）；并行下总 wall-clock 估计 +15-35 分钟；timeout 与并发组照 ci.yml:18-20 模式。**估计量**：具体数字待首批 job 实测后回填 |
| R-6 | **digest / 计数五处漂移** | §4.2 双重复核（manifest 运行期校验 + 五处硬钉常量）+ §4.3 同批纪律；skip 差异由 shared-conformance 对比（-StrictSkips）阻断（§3.6） |
| R-7 | **JDK 工具链混淆**：Kotlin jvmToolchain(17)（build.gradle.kts:13-15）vs java-properties oracle 的 OpenJDK 25.0.4 pin | 两者是不同对象（SDK 编译工具链 vs 第三方行为钉）；CI 中 setup-java Temurin 17 只服务于 kotlin/ 构建；oracle 仍在 Rust job 内运行 |
| R-8 | **node 版本漂移**：本地 Node 26.7 vs CI '26.x' | engines >= 26（package.json:8）+ CI 钉 '26.x'；未来 node 27 发布不破坏 engines 约束 |
| R-9 | **差分 harness 双向弱化**（新语言只做单方向） | §0.2 不变量 6：每语言 forward+reverse 全跑；脚本内断言 summary 行存在（go-verify-byte-parity.ps1:129-135 体例） |
| R-10 | **三语言盲写期无 CI 兜底**（语法/类型错误积累，multi-language-implementation-plan.md:106） | L0 门禁先行验证（§5.1）；CI 上线即锁定 |

---

## 7. 文件级实施计划

### 7.1 .github/workflows

| 文件 | 动作 | 内容 |
|---|---|---|
| `.github/workflows/ci.yml` | **不改**（Rust 门禁域 + go-1-26 原位） | 现 11 job 全保留（§1.1 映射表） |
| `.github/workflows/ci-typescript.yml` | 已新增（2026-08-12 上线全绿，见 §10） | `ts-gates`、`ts-conformance`、`ts-differential`（§1.2）；L5 加 `ts-package` |
| `.github/workflows/ci-python.yml` | 已新增（2026-08-12 上线全绿，见 §10） | `python-gates`、`python-conformance`、`python-differential`；L5 加 `python-package` |
| `.github/workflows/ci-kotlin.yml` | 已新增（2026-08-12 上线全绿，见 §10） | `kotlin-gates`、`kotlin-conformance`、`kotlin-differential`；L5 加 `kotlin-package` |

### 7.2 scripts/ 新增（命名照 go-verify-* 惯例；自包含、pwsh、零第三方依赖）

- `scripts/ts-verify-byte-parity.ps1` / `ts-verify-normalized-differential.ps1` /
  `ts-verify-protocol-exchange.ps1` / `ts-verify-shared-conformance.ps1`
- `scripts/python-verify-byte-parity.ps1` / `python-verify-normalized-differential.ps1` /
  `python-verify-protocol-exchange.ps1` / `python-verify-shared-conformance.ps1`
- `scripts/kotlin-verify-byte-parity.ps1` / `kotlin-verify-normalized-differential.ps1` /
  `kotlin-verify-protocol-exchange.ps1` / `kotlin-verify-shared-conformance.ps1`
- 结构镜像各 go 双胞胎：布局 sanity → case 集校验 → cargo build（--locked，缓存）→ 语言侧执行
  （env 传入 golden/证据目录，断言 RUN 非 SKIP）→ summary 行解析 → exit 0/非 0。
- 环境变量命名：golden 目录沿用 `CONSEMA_DIFFERENTIAL_RUST_DIR` /
  `CONSEMA_DIFFERENTIAL_NORMALIZED_RUST_DIR` / `CONSEMA_EXCHANGE_RUST_DIR`（语义不变）；
  证据目录用语言后缀（`…_TS_DIR` / `…_PYTHON_DIR` / `…_KOTLIN_DIR`）。
- 共享 conformance 脚本沿用 `-RustOutDir` / `-ReportFile` 参数与 `-StrictSkips` 开关（
  go-verify-shared-conformance.ps1:1-5）。

### 7.3 语言侧新增（各语言 L 里程碑批次内）

- TS：`typescript/src/conformance/*.test.ts`（runner + digest/计数硬钉）、
  `typescript/src/differential/{parity,normalized,exchange}/` 测试（缺 golden env 时 documented
  skip）、`typescript/package-lock.json`（npm ci 前置，L0 批次必须入库）、package.json scripts
  扩展（conformance / differential 入口）。
- Python：`python/src/consema/conformance/` runner 模块、`python/tests/conformance/`、
  `python/tests/differential/`。
- Kotlin：`kotlin/src/test/kotlin/consema/conformance/`、`.../differential/`、
  `kotlin/gradlew` + `kotlin/gradle/wrapper/*`（含 distributionSha256Sum，L0 批次必须入库）、
  `kotlin/gradle.lockfile`（L5 锁定）。
- 共享：`conformance/differential/`（新目录，§3.5 迁移自 go/，第二个语言 harness 合入批次执行）
  ——**已执行（2026-08-12）**：case 文件 git mv 至共享目录，go 测试改运行时读取，五语言 harness
  与 verify 脚本统一从该目录取数。

### 7.4 fc-manifest 扩展字段（`consema.fc-manifest@1` 内追加，不动既有字段）

| 字段 | 内容 |
|---|---|
| `digests.conformance_suite.evidence` | 追加"五 runner 共钉"注记（值 cfd6e296… 不变） |
| 新顶层 `languages` | 每语言一节：toolchain pin（node 26.x / python 3.12.x / kotlin 2.2.0+JVM 17）、里程碑状态（blind_writing / l0_open / l0_closed / … / l5_closed）、每里程碑证据与 owner（照 rust_compiler_msrv 记录体例，fc-manifest-0.13.0.json:58-63）、CI 上线批次 decision record |
| `corpus_test_suite_revisions.value` | 追加差分 case 集记录（byte-parity 68 / normalized 108 / protocol-exchange 83，含迁移后共享路径） |
| `capability_set` 相关门禁 | 每语言 capability parity 记录（L4 起，"无 Rust only mandatory"，multi-language-implementation-plan.md:115） |

### 7.5 实施批次总表

| 批次 | 触发 | 内容 |
|---|---|---|
| B1 | 各语言 L0 关闭 | ci-L.yml 三个文件 + 各语言 runner/差分测试 + package-lock.json / gradle wrapper + scripts/L-verify-{byte-parity,shared-conformance}.ps1 + fc-manifest languages 节 L0 记录 |
| B2 | 各语言 L1 关闭 | scripts/L-verify-normalized-differential.ps1 入 L-differential job + conformance/differential/ 迁移（git mv + go 侧同批更新） |
| B3 | 各语言 L4 关闭 | scripts/L-verify-protocol-exchange.ps1 入 job + capability parity 断言 |
| B4 | 各语言 L5 关闭 | 零 skip 断言 + L-package job + fuzz/bench 冒烟 + 三平台处置记录 |
| B5 | 1.0.0 收口 | 每语言 API 稳定性门禁 + 五语言全 job 全绿入 §22 审计 |

---

## 8. 设计决策汇总

1. **CI 形状**：每语言一个 workflow 文件（ci-typescript.yml / ci-python.yml / ci-kotlin.yml），
   ci.yml 一字不动（Rust 10 job + go-1-26 原位）；拒绝单矩阵（§5.2 四条理由）。
2. **digest 共享**：SHA-256 聚合（算法 fc-manifest-0.13.0.json:40）只覆盖语言无关向量文件 → 五
   runner 各算各的必得同一值；钉值两处：fc-manifest `digests.conformance_suite`（运行期校验）+
   每语言 runner 测试内硬钉常量（变更即红）；向量变更五处同批更新（§4）。
3. **差分扩展**：Rust 四个例子零改动；每语言 4 个 `L-verify-*.ps1` 脚本镜像 go 双胞胎；字节
   parity 与 protocol exchange 全方向、normalized 双向 × 4 不弱化；case 集迁移到共享
   `conformance/differential/`（68/108/83 五处共钉精确计数）。
4. **rollout**：语言 L 的 CI 随其 L0 关闭同批上线（§5.1 START GATE 绑定），三语言并行、各自独立；
   job 内容按 L1/L4/L5 逐步扩展（§5.3 表）。
5. **零依赖政策 CI 强制**：每语言 gates job 末步断言（npm ls --omit=dev 空 / dependencies=[] +
   pip check / runtimeClasspath 空），等价于 deny job 角色（§1.3）。

---

## 9. 相关文件

- 体例：`docs/go-implementation-plan.md`（§4/§6/§7 平移）、`docs/multi-language-implementation-plan.md`
- 现状 CI：`.github/workflows/ci.yml`（10+2 job：10 Rust + go-1-26 + go-differential；**六仓拆分 2d7494f 后此句为拆分前快照——10 Rust 门禁归 consema-rs 仓、go-1-26 / go-differential 归 consema-go 仓，母仓 ci.yml 重建为 oracles / shared-conformance-digest / check 三 job**）
- 差分现状：`scripts/go-verify-*.ps1` 四个脚本、`go/README.md:766-850`
- 向量权威：`conformance/README.md`、`conformance/vectors/`（18 套 / 519 cases）
- 记录：`docs/fc-manifest-0.13.0.json`（digest 第 35-41 行、C-1 第 786-802 行）
- 验证证据：`docs/five-element-review-1.0.0.md:35`（108/108、83/83、68/68 实测）
- 三语言 scaffold：`typescript/package.json`、`python/pyproject.toml`、`kotlin/build.gradle.kts`

---

## 10. 实施状态（2026-08-12 更新：三个新语言 workflow 已上线全绿）

本文档为规划阶段产物，§7 为规划表（保留为历史记录）；本节追加实施实况。
数据来源：GitHub Actions API 核验（head dbba9a4，2026-08-12）+ 本机复核（workflow/
脚本/文件存在性）。

- **三个新语言 workflow 全部 LIVE 且全绿**（每语言 3 job，与 §1.2/§7.1 设计一致）：
  - `.github/workflows/ci-typescript.yml` run#2：ts-gates / ts-conformance /
    ts-differential（differential = byte parity + normalized + protocol exchange
    三个脚本，windows-latest，ci-typescript.yml:102-137）
  - `.github/workflows/ci-python.yml` run#2：python-gates / python-conformance /
    python-differential
  - `.github/workflows/ci-kotlin.yml` run#2：kotlin-gates / kotlin-conformance /
    kotlin-differential（无 gradle wrapper，按 ci-kotlin.yml:1-21 设计直驱
    K2JVMCompiler + kotlin.test shim）
  - `.github/workflows/ci.yml` run#9：Rust 10+1 job（增补前——go-differential
    2026-08-12 增补后为 10+2 job / 12 定义）保持全绿——§5.2 的文件级失败
    隔离在实跑中成立（新语言上线未触碰 Rust 门禁域）
- **首跑缺陷（均在 dbba9a4 修复）**：
  - python 测试夹具硬编码路径 8 处 → 仓库相对路径（本机复核：pytest 收集面
    `test_*.py`/`*_test.py` 与 `python/src/` 已无硬编码路径；`python/tests/yaml/
    _verify_*.py` 为下划线前缀的非门禁 ad-hoc 脚本，pytest 默认不收集，其硬编码
    路径不影响 CI 绿）
  - kotlin jar 供给（2026-08-13 修正：直驱路径的 `kotlin-test.jar` /
    `kotlin-test-junit5.jar` 取自 **kotlinc 2.2.0 发行版 `lib/`**（consema-kt 脚本实测，
    kotlinc 自带，ci-kotlin.yml:223-224/269-270），仅 `junit-jupiter-api-5.10.2.jar`
    自 Maven Central（repo1.maven.org）供给至 `kotlin/build/verify/lib/`
    （kotlin-test-junit5 经 typealias 解析 @Test 编译所需，ci-kotlin.yml:227-239/271）；
    Gradle 路径（kotlin-gates，wrapper 驱动）两者均自 Maven Central 解析）；
    测试 shim `kotlin/verify/TestShim.kt` 入库（单模块编译含 shim，ci-kotlin.yml:96-116）
- **仍属未来批次（§5.3/§7.2/§7.3 原计划项，如实记录）**：
  - `scripts/{ts,python,kotlin}-verify-shared-conformance.ps1` 尚未合入（2026-08-12
    复核不存在）；workflow 头注释明示其随 runner-CLI 批次作为第四个 differential
    step 落地（ci-typescript.yml:13-15）——**runner-CLI slot 仍为未来项**
  - 零 documented skip 断言**三语言已全部上线（2026-08-12）**：Kotlin
    （kotlin/src/test/kotlin/consema/conformance/ConformanceRunnerTest.kt:58-59
    显式断言 519 passed / 0 skipped）、Python（每 suite 适用面 (passed,0,0) 共钉，
    python/tests/conformance/test_runner.py:32-51,89——任何 documented skip 即红）、
    TS（typescript/src/conformance/runner.test.ts:23 起断言 passed===519 &&
    skipped===0，任何 documented skip 即红）
  - `L-package` job 与 3-OS 矩阵处置原属 §5.3 L5 批次——**已上线/已处置
    （2026-08-12，见下段记录）**；kotlin `gradlew`/wrapper 已入库（c60d31a，
    gradle 8.14，kotlin-gates 走 wrapper 驱动，ci-kotlin.yml:105-114）
- **L5 批次落地（2026-08-12）**：
  - **`L-package` job × 3 上线**（§1.1 package 行 / §7.1 规划行 L5 项）：`ts-package`
    = npm pack --dry-run（tarball 必须含 files: src，ci-typescript.yml）、
    `python-package` = pip wheel --no-deps .（hatchling 后端，wheel 必须含
    consema/ 包，ci-python.yml）、`kotlin-package` = bash gradlew jar（gradle 8.14
    wrapper，jar 必须产出至 kotlin/build/libs/，ci-kotlin.yml）；三 job 均
    ubuntu-latest、均入各仓 `check (all gates green)` needs、permissions:
    contents: read、无 secrets、不依赖 conformance 数据（打包与数据无关）；
    本机实测通过（ts 261 文件含 src/、py consema-0.14.0-py3-none-any.whl 含
    consema/__init__.py、kt consema-kotlin-1.0.0-rc.1.jar 含 consema/ 类）
  - **3-OS 矩阵处置 = 文档化完成路径（§5.3 L5 行"二选一"决策）**：ts/py/kt
    保持单 OS 主跑面 + windows/ubuntu 双 OS 差分面——ts/py 的 gates/conformance
    在 ubuntu-latest、differential 在 windows-latest（ci-typescript.yml /
    ci-python.yml），kt 语言 job 全在 windows-latest（ci-kotlin.yml）。理由：
    三语言实现为纯库 + 协议面（零第三方运行时依赖、无平台专属 API，§0.2
    不变量 5），三 OS 差异主要影响 I/O/CLI 面，该面已由 Rust/Go 的 3-OS 矩阵
    覆盖（ci.yml lint/test/oracles/package 3 OS，rc-1.0.0-candidate.md §1 C-1）。
    完成路径 = 未来若出现平台专属需求，按 Go 先例（go/README.md:814-850）
    追加显式 3-OS 矩阵 job，文档化即完成、不建常设 job。
- **共享 case 集迁移已执行（2026-08-12）**：三份 case 文件已 git mv 至
  `conformance/differential/`（`cases.json` / `normalized/cases.json` /
  `protocol-exchange/cases.json`，单一权威，§3.5/§7.3 原计划项关闭）；go 侧三个差分测试由
  `//go:embed` 改为运行时读取（`CONSEMA_DIFFERENTIAL_CASES_DIR` 环境变量，或从测试包目录向上
  探测 `conformance/differential`——单仓与 consema/consema-go 并排布局均可解析；未设置且探测
  失败时 documented skip）；五个语言 harness（go/typescript/python/kotlin）与 12 个 verify 脚本
  统一从 `conformance/differential/` 取数；crates/ 下四个 Rust 例子的 doc 注释仍引用旧路径
  （其 case 文件路径经 CLI 参数传入，功能不受影响），留待拆分批次随 Rust 文档更新
- **ci.yml 新增 go-differential job（2026-08-12）**：Go 差分 gate 进 CI——
  `go-differential`（拆分前母仓 ci.yml:344-375；六仓拆分 2d7494f 后归
  consema-go 仓 ci-go.yml:172-246，windows-latest）串行执行
  scripts/go-verify-byte-parity.ps1 / go-verify-normalized-differential.ps1 /
  go-verify-protocol-exchange.ps1（脚本失败即 job 失败，无 continue-on-error）；
  §0.1 的「go-verify 未接入 CI」表述自此过时（Go 差分由本地执行 + 文档化完成
  路径变为 CI 常设 gate）；ci.yml 由 10+1 job 增至 10+2 job（12 定义：10 Rust +
  go-1-26 + go-differential）；§5.2 的「ci.yml 一字不动」设计决策由此部分让渡——
  与 go-1-26 同例（Go 门禁 job 由 gatekeeper 落盘，.github 域纪律不变；§7.1 规划表
  的 ci.yml「不改」行保留为历史规划，以本节记录为准）
- **证据链影响**：三语言 job 全绿把 C-1"GitHub 干净 checkout 全绿"证据由 Rust/Go
  扩展到 TS/Python/Kotlin（rc-1.0.0-candidate.md §4.1 已增补，2026-08-12）；§0.1 的
  "无测试目录 / 无 package-lock.json"缺口已被首批运行吸收（package-lock.json 已入库、
  npm ci 实跑，ci-typescript.yml:42-44）
- **版本政策（2026-08-13 决策）**：五语言包版本在 1.0.0-rc.1 窗口统一（ts/py 自
  0.14.0 推进）；§10 上文 L-package 实测记录的 0.14.0（wheel/jar 观测值）为
  2026-08-12 L-package 时点观察，历史标注。
