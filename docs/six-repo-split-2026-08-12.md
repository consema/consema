# Consema 六仓拆分（2026-08-12 决策与执行记录）

- 决策：2026-08-12（用户指示：不再等 1.0.0 收口，立即拆分六仓；原「先收口后拆分」计划取消，六仓布局确认）
- 日期：2026-08-12（记录时点；CI 状态表为该时点实况，各条标注证据 commit 或实测记录）
- 体例：照 `docs/five-language-ci-design.md` / `docs/go-implementation-plan.md`（证据文化：每条声称标注 commit / file:line / 实测记录；无法复核的项标注来源与日期）
- 范围声明：本文只读记录六仓拆分的决策依据、执行链、CI 修复链、semver 门禁真实性修正、conformance 仲裁层新架构与 fuzz 驱动迁移；不修改规范 / conformance / scripts / fuzz 账本
- 权威输入：用户 2026-08-12 决策；六仓 git 历史（母仓 + 五语言仓，split 分支长度由 `git rev-list --count` 实测）；`.github/workflows/ci.yml`（母仓与 consema-rs）；consema-rs `run_waves.ps1` 头部说明；`docs/fuzz-evidence-0.13.0-logs/runs.csv`（只读抽查 session 455）

---

## 1. 决策与依据

- **用户指示（2026-08-12）**：不再等 1.0.0 收口，立即拆分六仓；按五要素对齐（版本陈旧 3P1+24P2、路径引用 33P2 全部修复）后再拆；六仓布局确认 = consema（规范 / conformance 仲裁 / 证据权威）+ 五语言实现各成仓。原「先收口后拆分」计划（GitHub 组织三仓计划中的路径）取消，质量红线优先于组织结构动作的原则不变。
- **前提事实**：GitHub 侧六仓已于 2026-08-11 由用户创建（五语言仓原为空）；本机六仓并排检出（`C:\Users\franck\Documents\consema` + `consema-rs/go/ts/py/kt`）。
- **语言中立同等地位原则不变**：规范与设计语言无关，Rust 仅第一权威；拆分不改变五语言同等地位（2026-08-11 决策，见 `docs/multi-language-implementation-plan.md` 与 `docs/five-language-ci-design.md`）。

## 2. 六仓结构与 GitHub URL

| 仓库 | 角色 | GitHub URL（origin 实测） |
| --- | --- | --- |
| consema（母仓） | 规范 / RFC / 路线图 / 审计证据 / conformance 仲裁层（语言无关权威） | https://github.com/consema/consema.git |
| consema-rs | Rust 参考实现 | https://github.com/consema/consema-rs.git |
| consema-go | Go 实现 | https://github.com/consema/consema-go.git |
| consema-ts | TypeScript 实现 | https://github.com/consema/consema-ts.git |
| consema-py | Python 实现 | https://github.com/consema/consema-py.git |
| consema-kt | Kotlin 实现 | https://github.com/consema/consema-kt.git |

六仓均以 `main` 为默认分支，五语言仓由 `git subtree split` 的历史 + 组装 commit 构成（无合并历史）。

## 3. 拆分执行链

| 步骤 | 关键 commit（母仓） | 要点 |
| --- | --- | --- |
| 1. 全仓库对齐 | `aca77f6`（13 files，110+/94-） | 版本陈旧 3P1+24P2、路径引用 33P2 全部修复；Go 里程碑 0.14.0-0.19.0 交付、C-2 当时快照（3/9 units past 72h、62,432 行——aca77f6 提交时点值，后续复算见 fuzz-evidence §3.2.1/§8）、fc-manifest A-4/A-9/SEC-9 backfill、路线图五语言扩展注记、session-448 wave-3 超时事件记录、40+ 引用漂移修复（CHANGELOG / rc-candidate / ci.yml 行引用）。该 commit 在 go / py 的 split 历史中各有同名投影（go `7a03a15`、py `c1dfb4d`，同一变更在各 split 分支中保留）；rs / ts / kt 分支未带（对齐未触及其特有文件） |
| 2. cases.json 差分集迁移 | `00c850d`（34 files，273+/84-） | 共享差分 case 集迁至 `conformance/differential/` 单一权威（five-language-ci-design §3.5 落地）：go embed → 运行时加载（`CONSEMA_DIFFERENTIAL_CASES_DIR` + upward probe），12 个 verify 脚本 + TS/Python/Kotlin harness 路径更新 |
| 3. git subtree split 五分支 | （无新 commit，历史保留） | 五语言分支 commit 数实测：rs 179 / go 26 / ts 5 / py 7 / kt 7（`git rev-list --count <assembly>^`），历史完整保留 |
| 4. 五仓组装 | rs `6bcb068`（201 files，193,987+/187-）、go `cb0aedc`（371 files）、ts `1faa03f`、py `00d9054`（260 files）+ py `1a15969`（de-nest 修正：assembly move 与 leftover worktree dirs 冲突）、kt `613ae2f` | Cargo.toml members 重写（15 crates 至仓库根，无 crates/ 目录）；include 路径 172 处 `../../../` → `../../`；conformance vendor 快照入仓（consema-rs 以此快照 + 计数钉为 CI 机制，见 §6；go/ts/py/kt 四仓 CI 经 `repository:` 多仓 checkout 从母仓 provision） |
| 5. 母仓瘦身 | `2d7494f`（1448 files，96+/748,455-） | 删除全部语言目录；README 六仓导航；CI 重建为 oracles + shared-conformance-digest + check 三 job（见 §6） |
| 6. 五仓推送 | （push，无 commit） | 五语言仓 `git push origin main`（origin 实测 = consema org 各仓） |
| 7. 驱动迁移 | （见 §7） | `run_waves.ps1` 副本到 consema-rs，`-LedgerDir` 指向母仓账本，C-2 从 session 455 恢复累计 |

## 4. CI 修复链与两个根因

**现象**：五仓组装推送后（2026-08-12 03:33-03:39 区间，紧邻母仓瘦身 `2d7494f` 03:37:52 推送）CI 首跑全红；逐轮修复后绿（除 consema-rs 遗留项，见 §8/§9）。

| 轮次 | go | rs | ts / py / kt |
| --- | --- | --- | --- |
| run#1（组装 commit） | ✗（gofmt + go-verify-byte-parity：差分 cases 无 provision） | ✗（semver job，旧 baseline-rev 配置） | ✗（provision 缺 workspace Cargo.toml） |
| run#2 | ✗（provision 后仍缺 Cargo.toml） | ✗（fmt ×3 OS + semver 3 crate） | ✗（同左） |
| run#3 / run#2（fixture 后） | ✓ `2feffab` | ✗（见 §8，记录时点已结束） | ✓（ts `7fffb0d` / py `502ae74` / kt `8452f57`） |

**根因 1：时序竞态**。五仓 run#1 起步时 consema 主仓 main 处于拆分过渡态（go run#1 于 03:33:53 启动，早于瘦身 `2d7494f` 03:37:52 推送；GitHub 侧 checkout 到旧布局），五仓 workflow 依赖的 conformance/ 数据与多仓 checkout 路径尚未就绪。处置：rerun + 逐仓补 provision。

**根因 2：Cargo.toml fixture 缺失**。provision 阶段（go `86d1269`、ts `7001515`、py `1aeaaa2`、kt `b6909b5`）尝试从 consema checkout 取 workspace Cargo.toml 供给 `toml.corpus.cargo-manifest`——但瘦身后母仓已无任何 Cargo.toml（monorepo 的 `crates/Cargo.toml` 随语言目录删除）。处置：**fixture 归位**——母仓 `943c014` 将 workspace 清单固定为 `conformance/fixtures/toml/Cargo.toml`（内容与 consema-rs 根清单逐字节一致；fixture README 记载维护协议：consema-rs 组装改动须同步更新该文件）；五语言 runner + 测试全部改读 fixture：rs `1cd1552`、go `2feffab`、ts `7fffb0d`、py `502ae74`、kt `8452f57`。此后不再有任何 provision 步骤向 workspace 根复制 Cargo.toml。

## 5. semver 门禁结构性真空发现（门禁真实性修正）

**vacuity 机制**：workspace 版本 `0.8.0` → `1.0.0-rc.1` 被 cargo-semver-checks 推导为 major change，而 major change 满足每个 lint 的 required update，于是全部 254 个 lint 被过滤、门禁运行 0 checks（本地实测输出 "0 checks, 254 unnecessary"）——**永不失败的结构性空转**。拆分前 monorepo 升版后同样空转（该真空在 monorepo 时代即已存在）。此前「semver 全绿」声称是 vacuous 的——本记录写入后，fc-manifest 等引用处不得再将其视为 trivial。

**修复（rs `1cd1552` 落地）**：
- `release-type: patch` 强制 minor/major-requiring（breaking-change）lints 运行，门禁恢复真实。
- 同 commit 修 baseline 机制：`baseline-rev` 弃用（v0.8.0 crates 声明 `consema-core = { path, version = 0.8.0 }` 对 1.0.0-rc.1 workspace 导致 cargo update exit 101）；改 `baseline-root`——把 split 历史 commit `fbe98b5c` 的树（与 monorepo v0.8.0 `crates/` 树逐字节一致，v0.8.0 tag 在 split 历史中不存在）用 `git archive` 提取到 `$RUNNER_TEMP/semver-baseline`，补写 11-member workspace 根清单（v0.8.0 `workspace.package` / `workspace.dependencies`）并生成 Cargo.lock；nested `baseline/` 会触发 cargo-semver-checks 0.36+ "package X is ambiguous" 拒绝。

**真实运行结果**（cargo-semver-checks 0.50.0，2026-08-12 本地实验）：223 checks/crate，暴露 4 类**有意** enum variant 新增（breaking，但均为有意的 API 演进）：

| crate | enum | 新增 variant | 归属 |
| --- | --- | --- | --- |
| consema-core | `MatchRole` | `XmlErrorRegion` / `HclErrorRegion` | XML/HCL 家族落地（`8c02951`，0.9.0-0.13.0 里程碑） |
| consema-document | `NodeRole` | `XmlErrorRegion` / `HclErrorRegion` | 同上 |
| consema-json | `EditFailure` / `ProjectionFailure` | `RecoveredDocument` | M2-F1 安全修复（`738f178` = monorepo 094f5d1） |

**disposition（rs `5832135`）**：cargo-semver-checks 0.50.0 无 `semver-checks.toml`、无 per-variant allowlist——lint 配置只在各 crate `Cargo.toml` 的 `[package.metadata.cargo-semver-checks.lints]`，且是 lint 级粒度。处置：在 3 个受影响 crate 的 Cargo.toml `enum_variant_added = "allow"`，各带 reason 注释；**注意点已注释：lint 级 allow 覆盖面大于单 variant，今后同 crate 新增 variant 同样被豁免，须在 1.0.0 API 审查中留意**。本地验证：3 crate 全过（222 checks / 32 skip / exit 0，baseline-root fbe98b5c 树 + release-type patch）。

**记录时点状态**：consema-rs run#3 的 semver job 在 CI 中仍红（`enum_variant_added` 仍触发 1 major failure，exit 100；consema-core 已通过 allow，其余失败 crate 与 allow 在 action 上下文中的生效范围待 consema-rs 侧定位）——开放项，见 §8。

## 6. conformance 仲裁层新架构

- **`conformance/` 为单一语言无关权威**（本仓维护、五仓共享）：`vectors/` 18 套 suite 519 cases（聚合 digest `cfd6e296…`；P2-B 补强 2026-08-12 取代） + `fixtures/`（真实夹具；**`fixtures/toml/Cargo.toml` 于 `943c014` 归位**为 `toml.corpus.cargo-manifest` 的单一权威）+ `oracles/`（分类口径 2026-08-15 统一：hcl-go-v1、plist-macos-v1 为**差分 oracle**（带 documented skip_path）；java-properties/python-configparser/dotnet-ini/windows-ini/qt-ini 五套为 **runtime oracle**——见 fc-manifest digests 与 conformance/README「oracles 分类」行）+ `corpora/`（mutation 语料）+ `differential/`（跨语言差分 case 集单一权威：`cases.json` byte-parity 68 / `normalized/cases.json` 108 / `protocol-exchange/cases.json` 83，由 `00c850d` 迁入）。
- **五仓 CI provision 机制（如实）**：consema-rs 以 conformance vendor 快照 + 计数钉为机制（vendored `conformance/` 快照入仓，CI 与本地同源；权威仍在母仓，ci.yml 头注释明示）；go/ts/py/kt 四仓经 `repository: consema/consema` 多仓 checkout 从母仓 `conformance/` 取数（vectors / fixtures / oracles / differential case 集）；差分方向需要时另 checkout `consema/consema-rs`（各仓 ci-*.yml 实测）。
- **母仓 CI 只跑自有门禁**（`.github/workflows/ci.yml`，`2d7494f` 重建）：三 job——`oracles`（3 OS 矩阵，exit 3 = documented skip = success）+ `shared-conformance-digest`（复算 `conformance/vectors/` 聚合 digest 并断言等于冻结记录 `cfd6e296…`，519 冻结的常设执行者）+ `check`（聚合门禁，`if: always()` + toJSON(needs)，分支保护唯一 required check）。
- **向量变更是五仓同步事件**：任何一仓修改 `conformance/vectors/` 必须同步全部五个语言仓并更新聚合 digest 与 18/519 计数（README 声明；未同步变更在钉定移动前不会被语言仓 CI 自动捕获——go/ts/kt/py 四仓 CI 钉定 commit db821cd（2026-08-15 波 5 收口统一 provision 钉；fc-manifest sha256 af27d599）、consema-rs 为 vendored 快照，均不自动跟随）。

## 7. fuzz 驱动迁移

- **驱动位置**：`run_waves.ps1` 现从 consema-rs checkout 根目录运行（2026-08-13 起已入库跟踪——consema-rs commit d97a038，commit message「fuzz driver committed」；记录时点为本地未跟踪副本）；原脚本保留在母仓账本目录 `docs/fuzz-evidence-0.13.0-logs/run_waves.ps1`（`git ls-files` 实测；该副本于 2026-08-13 被母仓 commit 8f1ffa2 追加 CONSEMA_GIT_EXE override（+13 行），非冻结原版——「冻结协议证据」声称撤销，见 fuzz-evidence §3.1 驱动暂停状态）。
- **账本仍在母仓**：`-LedgerDir` 默认指向 `C:\Users\franck\Documents\consema\docs\fuzz-evidence-0.13.0-logs`（runs.csv 与 waves.log 为 fc-manifest 引用的权威账本；per-process `.out.log`/`.err.log` 为驱动诊断日志，fc-manifest 不引用）。
- **C-2 恢复累计**：session 455 起恢复（runs.csv 只读抽查：session 455 行存在，记录时点已推进至 471）。
- **账本为后台驱动的活文件**：记录时点后台驱动仍在写 wave 输出（母仓工作树有未提交的 runs.csv / waves.log 改动）——本记录不触碰、不纳入提交。

## 8. 已知注意项

1. **lint 级 allow 覆盖范围**（`5832135`）：`enum_variant_added = "allow"` 是 lint 级整体豁免，覆盖面大于单 variant——今后同 crate 新增 variant 同样被豁免，须在 1.0.0 API 审查中留意（注释已写入 3 个 crate 的 Cargo.toml）。
2. **consema-rs run#3 开放项**（记录时点已结束 = failure）：(a) fmt ×3 OS 红——`consema-conformance/src/toml_v1.rs` 的 `CARGO_MANIFEST` 常量（`1cd1552` 引入）未格式化；(b) semver job 仍红——CI 中 `enum_variant_added` 仍触发（consema-core 已过，失败 crate 待定位）。修复在 consema-rs 仓，不属于本记录范围。
3. **consema-rs semver baseline** 使用 `fbe98b5c` 等价 commit（split 历史中树与 monorepo v0.8.0 `crates/` 树一致的 commit；v0.8.0 tag 在 split 历史中不存在），baseline 在 CI 中经 `git archive` + 11-member workspace 清单重建。
4. **五仓 CI 每次向量变更需五仓同步**（见 §6；README 已声明）。
5. **fixture 维护协议**：`conformance/fixtures/toml/Cargo.toml` 须与 consema-rs 根 manifest 保持逐字节一致（fixture README 记载；consema-rs 组装类改动须同步更新）。
6. **run_waves.ps1 已入库**：consema-rs 根的驱动已随 d97a038（2026-08-13）入库跟踪（commit message「fuzz driver committed」）；协议权威 = consema-rs 根入库副本；母仓账本内的副本为拆分时点快照 + 8f1ffa2（2026-08-13，CONSEMA_GIT_EXE override）追加，非冻结历史。

## 9. 六仓 CI 状态表（截至记录时点 2026-08-12）

| 仓库 | workflow | 最新 run | head | 状态 |
| --- | --- | --- | --- | --- |
| consema | CI | #14 | `943c014` | ✓ |
| consema-rs | CI | #3 | `5832135` | ✗（fmt ×3 OS + semver job，见 §8；记录撰写开始时 in_progress，成稿时已结束） |
| consema-go | CI Go | #3 | `2feffab` | ✓ |
| consema-ts | TypeScript CI | #2 | `7fffb0d` | ✓ |
| consema-py | Python CI | #2 | `502ae74` | ✓ |
| consema-kt | Kotlin CI | #2 | `8452f57` | ✓ |

run 编号口径 = 各仓各 workflow 自身的计数（GitHub Actions 实测）。母仓 run #13（`2d7494f`）与 #14（`943c014`）均 ✓。
