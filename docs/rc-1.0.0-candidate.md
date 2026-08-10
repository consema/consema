# `1.0.0-rc.1` 候选清单（0.19.0 G5.7，路线图 §16.6 第 1555 行）

- 日期：2026-08-10（本地实测）
- 依据：路线图 §22（`1.0.0` 最终发布门槛，第 1867-1942 行）、§23（真实项目验证）；
  fc-manifest-0.13.0.json（open_items C-1/C-2/C-3）；go-implementation-plan §6 门禁总表
- 本文档 = G5.7 交付物 4/5：阻塞项清单（C-1/C-2/C-3 状态）、§22 门禁核对表、
  RC soak 计划、已知 P2 发布判断清单；并含 release/upgrade/rollback 演练记录
  （G5.7 交付物 3）。

## 1. 阻塞项状态（C-1/C-2/C-3，fc-manifest open_items）

| 阻塞项 | 状态 | 证据 | 完成路径 |
|---|---|---|---|
| C-1：CI 10 job 在 GitHub 干净 checkout 全矩阵全绿 | **partial** | .github/workflows/ci.yml（lint/test/coverage/msrv/conformance/deny/audit/semver/oracles/package）；本地等效全流程已实测（0.13.0-gate-plan §4 M1），GitHub 真跑未发生 | 推入 GitHub 后对 main 全矩阵真跑；oracle pin 与 hosted runner 不符时保持文档化 skip=成功；结果回填 manifest |
| C-2：每格式 72 CPU-hours release-candidate fuzz | **partial** | docs/fuzz-evidence-0.13.0.md §7-§8 快照：26.309 CPU-hours（2026-08-07 会话结束）；runs.csv 4,063 行（本次复核一致，零新 crash） | clang 主机 cargo-fuzz 为主、本机协议续跑为备选；追加式账本，新 crash 清零该 target 计时；72/格式全闭 |
| C-3：真实发布密钥与 0.13.0 发布执行 | **partial** | 演练密钥 82301612…（隔离 keyring）验证过全流程；**默认 keyring 尚无真实发布密钥**；docs/release 只有 0.8.0 演练产物 | 按 release-process-0.13.0.md §7 十项检查单顺序执行；版本推进 0.8.0→0.13.0；真实密钥+备份+吊销证书；**manifest 必须从干净发布 commit 重新生成**（见 §4 D-1） |

## 2. §22 门禁核对表（逐行状态，2026-08-10）

### 22.1 标准与格式 — 达成（双语言）

- 八个格式家族 GA：Rust 全（0.13.0 Feature-Complete）+ Go 全（0.18.0 G4.1，hcl 收口）。✓
- mandatory Profile 规范冻结、mandatory capability 已注册：registry v7（41 contract / 187 codes）。✓
- PortableValue/PVCE、PortableGraph/PGCE 稳定：跨语言字节相等（0.14.0 硬门禁持续）。✓
- protocol schema 稳定：RFC 0015 v7；无 provisional public abstraction（G5.5 审查）。✓
- 格式差异经 native model/Profile/policy 表达（oracle exclusion inventory 冻结）。✓

### 22.2 双语言实现 — 达成（除 Go CLI beta 交接面）

- capability set 一致：G4.4 capability parity 硬门禁（无 "Rust only" mandatory）。✓
- shared conformance 100%：18 套 / 508 cases 双 runner 全过。✓
- PVCE/PGCE byte-exact：G0.1-G0.2 硬门禁 + differential harness。✓
- protocol cross-encode/decode 100%：G5.3（Rust CLI ↔ Go protocol codec）。✓
- normalized parse/query/projection/materialization/edit 结果一致：G5.2 bidirectional differential。✓
- 独立实现（无 FFI/私有中间结果）：cgo 禁令 + 依赖面审查。✓
- Rust/Go public API 稳定性审查：G5.5 完成（§21.2 六项政策核对）。✓
- **边界**：cross-language protocol exchange 的 CLI 侧（Go CLI beta，G5.6）并行实现中，
  未参与本清单核对；Go CLI 合入后需补一次 exchange 复跑。

### 22.3 正确性 — 达成（本 pilot 佐证）

- accepted complete inputs byte-exact unmodified round-trip：pilot 12/12。✓
- recovery corpus completion state 稳定：负向向量双 runner 一致。✓
- duplicate/order/identity/graph sharing/mixed content 不丢失：pilot W2/W3/W4。✓
- projection/materialization 静默损失为零：pilot metric 3（0）。✓
- provenance 可追踪全部转换结果：两阶段 report + provenance map。✓
- query 定义错误不晚于首个 Match：query_validate 门禁。✓
- edit/patch wrong-snapshot 与 stale-content 必须拒绝：pilot W8 skipped-stale。✓
- transaction 失败原子：W7 六组原子拒绝。✓
- untouched bytes exact：pilot metric 2 + 迁移 1/2/3 证明。✓
- resource limit/cancellation 不产生伪成功：limits 矩阵 + exit 分类。✓

### 22.4 安全与质量 — 部分（C-1/C-2 阻塞）

- Rust+Go 全测试矩阵：本地全绿；GitHub 真跑 = C-1。⏳
- release-candidate fuzz clean-run：Rust 26.309/72 CPU-hours = C-2；Go fuzz targets
  （G5.4 矩阵）需 release-candidate clean-run 记录。⏳
- 无未解决 P0/P1：当前 0。✓
- 无未接受 critical/high dependency vulnerability：deny/audit 门禁。✓
- XML/YAML/HCL/binary plist 专项 threat tests：Rust security matrix + Go
  security_matrix_test。✓
- Windows/Linux/macOS 全部正式 target：本地 Windows 实测；Linux/macOS = C-1。⏳
- race/overflow/deep recursion/OOM amplification/path handling：双语言矩阵。✓
- security audit findings 全部关闭或公开接受：SEC-1..SEC-9（除 SEC-9 随 C-1）。✓/⏳

### 22.5 性能 — 达成（Rust）+ Go 侧随 RC soak 复核

- 冻结时间/内存预算：BENCHMARKS-0.13.0.md；F-2 修复后线性度本 pilot 复核（§5 迁移
  表格：1k→5k keys 130→257 ms，倍增 1.0-1.6×）。✓
- 无未解释 >10% release baseline 回退：BENCHMARKS §12 复验机制。✓
- adversarial complexity 有界：limits 矩阵（max_input_nodes/depth/amplification）。✓
- CLI 批量计划/应用在真实规模：Rust CLI 100 文件（本 pilot 重跑）；Go CLI 待合入。✓/⏳
- benchmark 报告可重现：BENCHMARKS 复现记录体例。✓

### 22.6 产品 — 部分（C-3 阻塞）

- Rust SDK、Go SDK、Rust CLI 正式发布：= C-3（0.13.0 发布）。⏳
- CLI 默认 dry-run、写操作有 precondition：Rust CLI（plan/apply、base-digest 前置）；
  Go CLI 并行实现中。✓/⏳
- machine-readable output schema 稳定：RFC 0015 v7 + cli-v1 向量。✓
- batch manifest、冲突、中断和恢复完成：pilot W8 + Rust CLI 中断 seam。✓
- 文档/API reference/cookbook/迁移指南/故障排查：cookbook.md、migration-guide.md 等
  齐备；Go SDK 文档注释门禁（G5.5）。✓
- 每格式 inspect/query/project/edit 示例：Go examples（G4.4）+ cookbook。✓
- 每可转换组合有 loss policy 示例：cookbook §12。✓
- 发布物/SBOM/签名/checksum/build provenance：流程已落地（release-process）；
  0.13.0 真跑 = C-3。⏳

### 22.7 真实有效性 — 达成（除两项演练）

- 每格式 family 有公开或可审计真实 corpus：conformance/fixtures 全家族。✓
- 三类真实批量迁移：本 pilot 迁移 1（版本/镜像）、2（结构插入删除）、3（跨格式）。✓
- 迁移未授权损失为零：迁移 1-3 断言（0 未授权字节）。✓
- 未选择文件和 byte ranges 不变：迁移 3 源树断言 + untouched proofs。✓
- stale file、部分权限失败、进程中断、磁盘失败演练：stale + 中断已演练（0.13.0
  pilot 与本 pilot）；**部分权限失败与磁盘失败未记录**——RC soak 必做项（§5）。⏳
- Rust 与 Go 分别至少一个端到端 SDK pilot：pilot-0.13.0.md（Rust）+ 本 pilot
  （Go）。✓
- pilot 缺陷入回归：F-2 已修复并入 BENCHMARKS 回归网；本 pilot 零缺陷（契约行为
  三项已文档化，§6）。✓

## 3. release/upgrade/rollback 演练记录（2026-08-10，真实执行）

演练体例照 release-process-0.13.0.md §6；对象：**升级 = 上一个发布态（0.12.0 CLI、
workspace 0.8.0，commit 7e9de38）→ 当前（0.13.0）**；回滚 = 恢复旧构建。

### 3.1 演练 1：旧版本构建与归档（升级源完整性）

- `git archive` 提取 v0.8.0 tag 与 9c1ede20/7e9de38 三棵树；v0.8.0 tag 树
  `cargo package --workspace --locked --no-verify` 产出 12 个 .crate（该 tag 早于
  hcl/plist/xml crates），9c1ede20/7e9de38 产出 14 个。
- **发现 D-1**：对 v0.8.0、9c1ede20、7e9de38 三个 commit 的干净重建均无法复现
  `docs/release/SHA256SUMS-0.8.0.txt` 的 14 个 digest（0/14 匹配）。根因：
  manifest 记录于 2026-08-07 的**脏工作树**状态（fc-manifest tree_state_note 明示
  "本 manifest 记录时仓库曾为工作树状态"），归档含 `.cargo_vcs_info.json` 但脏树
  packaging 的字节与任何干净 commit 均不同。**处置：0.13.0 发布时必须在干净发布
  commit 上重新生成 checksum manifest（release-process §7 items 3+5 顺序执行），
  不沿用演练产物**。
- `gpg --decrypt SHA256SUMS-0.8.0.txt.asc` 明文与 manifest 逐字节一致；签名由演练
  密钥 823016129EBDEAF7DF15ACA7C9804B1CC0EA4776 生成（release-process §4.4 记录），
  无公钥可完整复验（演练 keyring 为临时目录）——**发现 D-2**：发布密钥必须持久
  备份（C-3），否则旧签名不可复验。

### 3.2 演练 2：升级（0.12.0 CLI 态 → 0.13.0）

- 从 7e9de38 worktree 重建旧 CLI（`cargo build --release --locked -p consema`，
  `--version` → 0.8.0/0.12.0 CLI），当前树 CLI 为 0.13.0。
- 同一语料同一请求形状逐字节比较：

| 操作 | 旧 CLI（0.8.0） | 新 CLI（0.13.0） | 比较 |
|---|---|---|---|
| convert package.json → TOML | exit 0，369 B | exit 0，369 B | **逐字节相等** |
| convert package.json → YAML | exit 0，647 B | exit 0，647 B | **逐字节相等** |
| plan 10 INI 文件 | exit 0 | exit 0 | manifest 仅 `product_version` 字段 0.8.0→0.13.0，其余（路径/digest/操作/source_patch）逐字节相等 |
| apply | exit 0 | exit 0 | 同上，逐字节相等 |

- 结论：升级路径上机器协议字节兼容（RFC 0015 稳定面），唯一变化是版本字段——
  版本升级对既有自动化无破坏。

### 3.3 演练 3：回滚

- 恢复旧 CLI 二进制（7e9de38 重建物）后重跑同一批 apply，结果 manifest 与
  升级前快照（version 归一化后）逐字节相等：**回滚无数据差异**。
- 归档回滚路径：旧 .crate 归档的权威源 = 发布 commit 的干净重建（D-1 处置后），
  与 release-process §6.3 的 tag 恢复体例（fsck → update-ref → 签名可验证）衔接。

### 3.4 演练边界（诚实记录）

- 未演练：磁盘满（需真实填盘条件，RC soak 计划内）、部分权限失败（RC soak 计划内）、
  远程篡改（不在 §19.4 范围）。
- 演练二进制与 worktree 均为临时目录，不进入任何发布记录；0.13.0 发布按
  release-process §7 用真实密钥执行。

## 4. RC soak 计划

目标：§22 全部门禁除 RC soak 本身全部通过（§16.6 第 1557 行硬门禁）。

```text
阶段 0（RC 构建前，阻塞）：
  C-1 推入 GitHub 真跑 10 job 全矩阵全绿，回填 manifest
  C-2 完成每格式 72 CPU-hours fuzz 账本，零未解释问题
  C-3 真实密钥 + 备份 + 吊销证书；按 release-process §7 顺序执行发布，
     checksum manifest 从干净发布 commit 生成（D-1 处置）
  Go CLI beta（G5.6）合入并复跑 cross-language protocol exchange

阶段 1（RC soak，1.0.0-rc.1 构建后 7-14 天）：
  磁盘失败演练：批量 apply 目标卷写满（临时小卷）→ 失败分类与恢复路径记录
  部分权限失败演练：只读目录 apply → precondition 失败分类记录
  双语言 differential corpus 追加运行（§17.4）
  Go 侧 release-candidate fuzz clean-run 记录（§22.4）
  每格式真实 corpus 抽检巡检（§22.7）
  性能基线复测（BENCHMARKS 复验，无 >10% 回退）
  每 48h 检查 fuzz 账本追加（新 crash 清零对应 target 计时）

阶段 2（soak 通过后）：
  无 P0/P1 与 contract ambiguity → 发布 1.0.0-rc.1
  RC 期间发现 P0/P1/ambiguity → 新 RC + 相应 clean-run 重做（第 1942 行）
```

soak 退出标准：本清单 §2 全部 ⏳ 转 ✓（或显式 judgment 记录）；§5 P2 清单逐项
disposition。

## 5. 已知 P2 发布判断清单（可带 judgment 随 RC 发布）

| # | 项 | 出处 | judgment 建议 |
|---|---|---|---|
| P2-1 | XML ReplaceText 词表不含 CDATA（RoleXmlText only） | 本 pilot F-1 | 双语言一致契约行为，文档化边界；随 rc.1 发布并在 cookbook 注明 |
| P2-2 | YAML family 无 dry-run 面（PlanEdit 显式拒绝） | 本 pilot F-2；G2.1 gap | **judgment 定案（2026-08-10）**：按 rc 纪律（§12.1 只收 blockers/security/docs errors）转 API 政策记录——补面是功能而非 blocker，移至 1.0.0 后窗口（RFC 0020 兼容承诺面记录）；拒绝行为已文档化 pin（`core.edit.operation-unsupported@1`） |
| P2-3 | JSONC/JSON5 插入元素为 canonical 片段拼写（`[80, 100,120]`） | 本 pilot F-3 | 契约行为（语义插入非格式化）；发布判断：接受 |
| P2-4 | 0.8.0 checksum manifest 不可从 git 历史复现（脏树记录） | 本 drill D-1 | **发布流程修正项**（发布时从干净 commit 生成），不阻塞 rc.1 本身 |
| P2-5 | 演练签名密钥无持久公钥可复验 | 本 drill D-2 | 随 C-3 真实密钥解决 |
| P2-6 | 部分权限失败与磁盘失败演练未记录 | §22.7 | RC soak 阶段 1 必做（§4） |
| P2-7 | Go CLI beta 合入前的 exchange 复跑 | §22.2 | **已闭环（2026-08-10）**：G5.6 合入后四 harness 复跑——协议交换 83/83（40 accept + 43 reject）、双向差分 108/108、字节 parity 68/68；shared-conformance 步骤 1 在本机 CRLF 工作树按 F-B 文档化行为报 digest 差异（规范 checkout 绿，CI 不受影响） |

## 6. 相关文件

- 本 pilot：`docs/pilot-go-0.19.0.md`（W1-W8 全流程、12 指标、三场迁移、Rust 复核）
- 可复现：`go/pilot/pilot_test.go`（14 测试；`CONSEMA_PILOT_RUST_CLI` 时含跨语言对照）
- 先例：`docs/pilot-0.13.0.md`、`docs/release-process-0.13.0.md`、`docs/fc-manifest-0.13.0.json`
