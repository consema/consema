# `1.0.0-rc.1` 候选清单（0.19.0 G5.7，路线图 §16.6）

- 日期：2026-08-10（本地实测）
- 依据：路线图 §22（`1.0.0` 最终发布门槛——行号可能漂移，以 §22 标题为锚）、§23（真实项目验证）；
  fc-manifest-0.13.0.json（open_items C-1/C-2/C-3）；go-implementation-plan §6 门禁总表
- 本文档 = G5.7 交付物 4/5：阻塞项清单（C-1/C-2/C-3 状态）、§22 门禁核对表、
  RC soak 计划、已知 P2 发布判断清单；并含 release/upgrade/rollback 演练记录
  （G5.7 交付物 3）。

## 1. 阻塞项状态（C-1/C-2/C-3，fc-manifest open_items）

| 阻塞项 | 状态 | 证据 | 完成路径 |
|---|---|---|---|
| C-1：CI 10 job 在 GitHub 干净 checkout 全矩阵全绿 | **closed** | GitHub Actions run #5（2026-08-11，head 437fd35，main push）：132/132 steps 全绿（增补前 10+1 job：lint/test/coverage/msrv/conformance/deny/audit/semver/oracles/package/go-1-26，11 定义/17 次执行）在 windows/ubuntu/macos 全矩阵通过；2026-08-12 增补 go-differential 后为 10+2 job（12 定义；六仓拆分后各 job 归仓：10 个 Rust 门禁属 consema-rs/.github/workflows/ci.yml、go-matrix 与 go-differential 属 consema-go/.github/workflows/ci-go.yml（以 job 名为锚，行号可能漂移）、oracles 属母仓 ci.yml——母仓 ci.yml 为 oracles/shared-conformance-digest/check 三 job）；run 历史：run#1 workflow-parse fail（job id go-1.26 含点号）→ run#2 5 根因（symlink_dir 移除、oracles ParserError、coverage Get-CimInstance guard、package 工具链顺序、tags 未推）→ run#3 4 根因（macOS /var→/private/var 临时路径 symlink、oracles 缺 exit 0、semver 嵌套 baseline 歧义、coverage 数组 guard $null）→ run#4 fmt import 顺序 → run#5 全绿；结果已回填 manifest（C-1 → closed） | 已闭环（2026-08-11，run #5 全绿） |
| C-2：每格式 72 CPU-hours release-candidate fuzz | **partial** | docs/fuzz-evidence-0.13.0.md §3.2.1/§8 快照：258.327 CPU-hours（session 297 时点复算，2026-08-11）；runs.csv 41,939 行（零新 crash；每格式 72h 门槛仍开放，最接近 properties ≈66.8%，完成路径不变）；**2026-08-13 复算快照（runs.csv 权威）**：122,477 数据行 / 780.529 CPU-hours，零新 crash（非零退出 = 40 行：10 行 session-9 外部终止 + 16 行 session-448-wave-3 超时 + 14 行 session-454 拆分停机，均非 fuzz finding）；**properties 145.4h（201.9%）、yaml 128.8h（178.9%）、ini 124.8h（173.3%）、hcl 95.5h（132.7%）、json 95.3h（132.3%）五单位已过 72h 门槛**；toml 57.7h（80.2%）、protocol-decode 50.7h（70.4%）、plist 47.4h（65.8%）、xml 35.0h（48.6%）低于门槛；**驱动已暂停（2026-08-13 11:19 session 916 无记录终止后未重启），账本冻结于 122,478 文件行 / 780.529 CPU-hours——四单位未过门槛如实记录为遗留（fuzz-evidence §3.1 驱动暂停状态）**；完成路径不变（快照口径：runs.csv 为唯一权威账本） | clang 主机 cargo-fuzz 为主、本机协议续跑为备选；追加式账本，新 crash 清零该 target 计时；72/格式全闭 |
| C-3：真实发布密钥与 1.0.0-rc.1 发布执行 | **partial** | 演练密钥 82301612…（隔离 keyring）验证过全流程；**默认 keyring 尚无真实发布密钥**；docs/release 现含 0.8.0 演练产物与 1.0.0-rc.1 PREVIEW 预检产物（2026-08-11 入库——git 实测 d14e8b7 2026-08-11 09:56 引入、ebfca68 2026-08-11 15:59 最后触碰：sbom-1.0.0-rc.1.json、cargo-package-1.0.0-rc.1.log、verify-package-archives-1.0.0-rc.1.result.txt、PREVIEW-1.0.0-rc.1.md） | 按 release-process-0.13.0.md §7 十项检查单顺序执行；1.0.0-rc.1 发布执行（版本已推进 0.8.0→0.13.0→1.0.0-rc.1，2209582）；真实密钥+备份+吊销证书；**manifest 必须从干净发布 commit 重新生成**（见 §4 D-1） |

## 2. §22 门禁核对表（逐行状态，2026-08-10）

### 22.1 标准与格式 — 达成（截至 2026-08-10 双语言范围；五语言扩展见 §4.1 与五语言 CI 记录）

- 八个格式家族 GA：Rust 全（0.13.0 Feature-Complete）+ Go 全（0.18.0 G4.1，hcl 收口）。✓
- mandatory Profile 规范冻结、mandatory capability 已注册：registry v7（41 contract / 187 codes）。✓
- PortableValue/PVCE、PortableGraph/PGCE 稳定：跨语言字节相等（0.14.0 硬门禁持续）。✓
- protocol schema 稳定：RFC 0015 v7；无 provisional public abstraction（G5.5 审查）。✓
- 格式差异经 native model/Profile/policy 表达（oracle exclusion inventory 冻结）。✓

### 22.2 双语言实现 — 达成（截至 2026-08-10 双语言范围；五语言扩展见 §4.1 与五语言 CI 记录；Go CLI 交接面已闭环 2026-08-10，见下）

- capability set 一致：G4.4 capability parity 硬门禁（无 "Rust only" mandatory）。✓
- shared conformance 100%：18 套 / 519 cases 五 runner 全过（增补后 519；
  聚合 digest `cfd6e296da5b…` 五 runner 共钉，fc-manifest-0.13.0.json
  digests.conformance_suite 为权威——2026-08-12 P2-B 向量补强 508→519，
  以字段名为锚，行号可能漂移）。✓
- PVCE/PGCE byte-exact：G0.1-G0.2 硬门禁 + differential harness。✓
- protocol cross-encode/decode 100%：G5.3（Rust CLI ↔ Go protocol codec）。✓
- normalized parse/query/projection/materialization/edit 结果一致：G5.2 bidirectional differential。✓
- 独立实现（无 FFI/私有中间结果）：cgo 禁令 + 依赖面审查。✓
- Rust/Go public API 稳定性审查：G5.5 完成（§21.2 六项政策核对）。✓
- **边界（已闭环 2026-08-10）**：cross-language protocol exchange 的 CLI 侧（Go CLI，G5.6）
  当时并行实现中、未参与本清单核对；G5.6 已合入，exchange 复跑已闭环（P2-7，见 §5：
  协议交换 83/83、双向差分 108/108、字节 parity 68/68）。

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

### 22.4 安全与质量 — 部分（C-2 阻塞；C-1 已闭环 2026-08-11）

- Rust+Go 全测试矩阵：本地全绿；GitHub 真跑 = C-1——**已闭环（2026-08-11，run #5，head 437fd35，132/132 steps 全绿，10+1 job（增补前，11 定义/17 次执行）windows/ubuntu/macos；go-differential 2026-08-12 增补后为 10+2 job/12 定义（六仓拆分后各 job 归仓：10 个 Rust 门禁属 consema-rs、go-matrix 与 go-differential 属 consema-go ci-go.yml（以 job 名为锚，行号可能漂移）、oracles 属母仓 ci.yml——母仓为 oracles/shared-conformance-digest/check 三 job）**。✓
- release-candidate fuzz clean-run：Rust 188.336/72 CPU-hours（历史快照——session 234 时点
  复算，2026-08-11，runs.csv 33,337 行，零新 crash）；**最新快照 122,477 数据行 / 780.529 CPU-hours
  （2026-08-13 复算，runs.csv 权威，零新 crash；properties 145.4h（201.9%）、yaml 128.8h
  （178.9%）、ini 124.8h（173.3%）、hcl 95.5h（132.7%）、json 95.3h（132.3%）五单位已过 72h
  门槛；toml 57.7h、protocol-decode 50.7h、plist 47.4h、xml 35.0h 低于门槛；122,478 文件行含表头；驱动已暂停（2026-08-13 11:19 后未重启），累计冻结）**
  = C-2（其余单位 72h 门槛仍开放，驱动暂停后累计冻结——见 §1 C-2 行）；Go fuzz targets clean-run 记录已有
  （2026-08-10，consema-go/go/README.md targets 各 30s，零 panic/hang/limit bypass）。⏳
- 无未解决 P0/P1：当前 0。✓
- 无未接受 critical/high dependency vulnerability：deny/audit 门禁。✓
- XML/YAML/HCL/binary plist 专项 threat tests：Rust security matrix + Go
  security_matrix_test。✓
- Windows/Linux/macOS 全部正式 target：本地 Windows 实测；Linux/macOS = C-1——已闭环（2026-08-11，run #5 三 OS 全矩阵全绿）。✓
- race/overflow/deep recursion/OOM amplification/path handling：双语言矩阵。✓
- security audit findings 全部关闭或公开接受：SEC-1..SEC-9（SEC-9 已随 C-1 闭环——run #5 三 OS cli 测试矩阵全绿，2026-08-11）。✓

### 22.5 性能 — 达成（Rust）+ Go 侧随 RC soak 复核

- 冻结时间/内存预算：BENCHMARKS-0.13.0.md；F-2 修复后线性度本 pilot 复核（§5 迁移
  表格：1k→5k keys 130→257 ms，倍增 1.0-1.6×）。✓
- 无未解释 >10% release baseline 回退：BENCHMARKS §12 复验机制。✓
- adversarial complexity 有界：limits 矩阵（max_input_nodes/depth/amplification）。✓
- CLI 批量计划/应用在真实规模：Rust CLI 100 文件（本 pilot 重跑）；Go CLI 待合入。✓/⏳
- benchmark 报告可重现：BENCHMARKS 复现记录体例。✓

### 22.6 产品 — 部分（C-3 阻塞）

- Rust SDK、Go SDK、Rust CLI 正式发布：= C-3（1.0.0-rc.1 发布）。⏳
- CLI 默认 dry-run、写操作有 precondition：Rust CLI（plan/apply、base-digest 前置）；
  Go CLI 并行实现中。✓/⏳
- machine-readable output schema 稳定：RFC 0015 v7 + cli-v1 向量。✓
- batch manifest、冲突、中断和恢复完成：pilot W8 + Rust CLI 中断 seam。✓
- 文档/API reference/cookbook/迁移指南/故障排查：cookbook.md、migration-guide.md 等
  齐备；Go SDK 文档注释门禁（G5.5）。✓
- 每格式 inspect/query/project/edit 示例：Go examples（G4.4）+ cookbook。✓
- 每可转换组合有 loss policy 示例：cookbook §12。✓
- 发布物/SBOM/签名/checksum/build provenance：流程已落地（release-process）；
  1.0.0-rc.1 真跑 = C-3。⏳

### 22.7 真实有效性 — 达成（除两项演练）

- 每格式 family 有公开或可审计真实 corpus：conformance/fixtures 全家族。✓
- 三类真实批量迁移：本 pilot 迁移 1（版本/镜像）、2（结构插入删除）、3（跨格式）。✓
- 迁移未授权损失为零：迁移 1-3 断言（0 未授权字节）。✓
- 未选择文件和 byte ranges 不变：迁移 3 源树断言 + untouched proofs。✓
- stale file、部分权限失败、进程中断、磁盘失败演练：stale + 中断已演练（0.13.0
  pilot 与本 pilot），部分权限已闭环（§3.5 演练 4，2026-08-10）；**仅磁盘失败未记录**
  （§3.5 演练 5 环境阻塞；完成路径已随 C-1 闭环（2026-08-11）可用——Linux runner 临时小卷）——RC soak 待办项（§5 P2-6）。⏳
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
  hcl/plist/xml crates），9c1ede20/7e9de38 产出 15 个（两树各含 15 个 crate 目录，
  含 consema-conformance——repository-only crate 不写入 SHA256SUMS 清单，故
  SHA256SUMS 条目为 14；本句的 15 为 cargo package 输出数、14 为清单条目数，
  口径差异如实注明）。
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

- 未演练：磁盘满（需真实填盘条件，环境阻塞——§3.5 演练 5；完成路径已随 C-1 闭环（2026-08-11）可用）、
  远程篡改（不在 §19.4 范围）。
- 演练二进制与 worktree 均为临时目录，不进入任何发布记录；1.0.0-rc.1 发布按
  release-process §7 用真实密钥执行。

### 3.5 RC soak 阶段 1 演练记录（2026-08-10，真实执行）

**演练 4：部分权限失败（只读目录 apply）— 已闭环**

- 环境：`target/release/consema.exe` v0.13.0；临时目录 `%TEMP%\consema-rc-drill1-perm-*`
  （已清理）；素材 = conformance/fixtures/ini/desktop-settings.ini 真实夹具副本 ×5
  （base sha256 `b01f173b…`）；edit 请求 = cookbook §6 规范示例
  （`ini.edit.replace-semantic-value@1`，window:width→1600）。
- 步骤与结果：

| 步骤 | 操作 | 结果 |
|---|---|---|
| 1 | `plan` 5 文件 | exit 0，5/5 planned（base `b01f173b…` / target `98b89205…`，与 pilot W8 相同 digest） |
| 2 | `icacls targets /deny franck:(WD,AD,WEA)` | exit 0（目录级 DENY ACE 生效） |
| 3 | `apply plan.json` | **exit 4**，5/5 `failed cli.write.permission@1`；stderr 原文：`permission denied writing '<path>': 拒绝访问。 (os error 5) (code cli.write.permission@1)` |
| 4 | `apply --json` 机器信封 | exit 4，`exit_class: "precondition"`，payload 5 条 failed（per-file 失败作为 manifest 内容，envelope diagnostics: []，符合 RFC 0015） |
| 5 | 字节核验 | 5/5 目标仍为 base digest（零字节写入）；无 `*.tmp` 残留 |
| 6 | 恢复：`icacls /remove:d` → 同一 plan 重跑 | exit 0，5/5 completed（target `98b89205…`） |

- **原子性判定（混合场景）**：同批 4 文件跨 2 目录（2 可写 + 2 icacls 只读）→ apply
  exit 4，可写侧 2/2 completed、只读侧 2/2 failed；只读侧字节未动、可写侧已写。
  **结论：拒绝是逐文件原子的，批处理无整体原子性**——与 RFC 0015 §10「单文件原子
  替换、批原子性 = manifest 状态机可恢复性」一致。
- **失败分类**：exit 4 = precondition 类（RFC 0015 §5.1 表：permission/disk failures
  明确列于 precondition）；诊断码 `cli.write.permission@1`（§13.1 注册表）→ §5.2
  规则 `cli.write.* → 4`。补充实测：Windows 只读文件属性（非 ACL）路径为独立码
  `cli.write.read-only@1`（`target '…' is read-only`），同 exit 4——两个检测路径
  映射两个注册码，同属 precondition 类。
- 结论：P2-6 的"部分权限失败演练未记录"缺口已闭（§22.7 四类演练中 stale/中断/
  部分权限已闭环）。

**演练 5：磁盘失败 — 环境阻塞记录（如实）**

- 约束实测：非 admin（IsInRole(Administrator)=False）；`New-VHD`/`Mount-VHD` →
  CommandNotFoundException（Hyper-V 模块未安装）；`diskpart /?` → The requested
  operation requires elevation；卷清单：C: NTFS 952.8 GB（27.6% free，禁止填盘）、
  无名 NTFS 0.9 GB 无盘符（系统恢复类，不可寻址）、D: Ventoy exFAT 57.7 GB
  （59% free）、E: VTOYEFI（Ventoy 保留）。**无可行小卷路径**。
- 完成路径：C-1 已闭环（2026-08-11，run #5 全绿），Linux runner 路径现可用——在该 runner 上用临时小卷（tmpfs/loop）执行（真实填盘 →
  apply 预期 exit 4 + `cli.write.io@1` per-file failed → 释放空间后同一 plan 重跑
  恢复）；或授权（admin）环境 New-VHD + Mount-VHD + Format-Volume 后同流程。
- **诚实佐证（非真实填盘）**：RFC 0015 §5.4 注入 seam `CONSEMA_APPLY_WRITE_FAILURE=io`
  （临时目录实测）：首个目标写失败 `cli.write.io@1`（§10「disk full →
  cli.write.io@1」同一注册码）→ exit 4，批内其余文件照常 completed，清除 env 后
  同一 plan 重跑全 completed（exit 0）。证明 io 类失败分类与恢复语义完整；真实填盘
  演练本身仍记录为环境阻塞。
- 结论：演练 5 在 §3.4 演练边界体例下记录为"未演练（环境阻塞：非 admin + 无
  Hyper-V + 无可寻址小卷），完成路径已定——C-1 已闭环（2026-08-11）后 Linux runner 路径可用，或授权环境执行"。

## 4. RC soak 计划

目标：§22 全部门禁除 RC soak 本身全部通过（§16.6 硬门禁）。

```text
阶段 0（RC 构建前，阻塞）：
  C-1 推入 GitHub 真跑 10 job 全矩阵全绿，回填 manifest → **已完成（2026-08-11，run #5 132/132 全绿，head 437fd35，已回填 manifest）**
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
  RC 期间发现 P0/P1/ambiguity → 新 RC + 相应 clean-run 重做（§22.7）
```

### 4.1 阶段 1 当前进展（2026-08-10）

- 磁盘失败演练 → 环境阻塞（见 §3.5 演练 5）；完成路径已随 C-1 闭环（2026-08-11）可用（Linux runner 临时小卷），演练本身待执行
- 部分权限失败演练 → **已完成**（§3.5 演练 4，2026-08-10 实测闭环）
- 双语言 differential corpus 追加运行 → 四 harness 已复跑（P2-7，
  83/83+108/108+68/68；追加 corpus 待 C-2 关账后随收口执行）
- Go 侧 release-candidate fuzz clean-run 记录 → 已有（2026-08-10，
  consema-go/go/README.md targets 30s）
- 每格式真实 corpus 抽检巡检 → **已完成**（2026-08-10：钉版 12 文件 digest 12/12
  一致；508 核对一致（增补前——2026-08-12 P2-B 向量补强至 519 后该计数为
  519，fc-manifest-0.13.0.json digests.conformance_suite，以字段名为锚）；
  regressions 空数组符合预期；9 家族来源与覆盖足够；4 条观察见下）
- 性能基线复测 → **Go 侧已执行**（2026-08-10：8×2 benchmarks；9/16 项比值
  >1.10，全部标注"疑似回退（fuzz 负载下测得，需空闲复测确认）"，无代码回退
  结论——同会话 7 项更快、无代码改动、GC 争抢特征）；Go 侧无冻结预算
  （consema-go/go/README.md 的「Benchmark baseline (0.19.0 G5.4)」节），仅趋势记录；Rust 侧 -Check 复验（BENCHMARKS §11）
  建议 fuzz 关账后空闲环境执行（避免 ~40% CPU 负载假阳性 fail）
- 发布路径预检（C-3 非密钥机械步骤）→ **已实测**（2026-08-10，干净 worktree）：
  `cargo package --workspace --locked --no-verify` 15 归档 exit 0；
  verify-package-archives.ps1 14 crate 归档门禁 + MSRV 1.85 腿 exit 0（14 行
  sha256 与 SHA256SUMS 体例逐字节同构）；release-sbom.ps1 离线 SPDX-2.3 42
  packages exit 0；剩余阻塞仅真实密钥（§7 项 5-8）。注意事项：裸 `cargo
  package --workspace` 含 publish=false 的 consema-conformance（14 集合同步
  由 verify 脚本/签名步骤保证）；脚本须从原生 PowerShell 运行（GNU tar 会
  误报 Windows 路径）；与 fuzz 共享 cargo 锁时机械步骤约 40 分钟
- coverage -Trend 平台差处置 → 入库基线 86.51/82.82/87.91 为 Windows 本机
  测得（docs/COVERAGE-0.13.0.md），CI coverage job 在 ubuntu 测，
  跨平台差 >1.0pp 时 C-1 首跑可能 -Trend 首红。处置：若红，按脚本政策在
  ubuntu 等效环境刷新入库报告并附处置记录（release 里程碑刷新许可，
  coverage.ps1 的「趋势门禁」政策段，行号可能漂移，以锚为准）；不阻塞 C-1 推入（实测：run #5 coverage job 全绿，未触发
  -Trend 红，2026-08-11）
- CI 就绪审计 → **已完成**（2026-08-10，只读审计 10 job + go-1-26）：8 job
  静态 PASS；3 项首跑风险：msrv clippy（1.85 特有 warning，**已修复**——见
  任务 A）、oracles macOS 腿 pin 不符 throw（**已补文档化 skip** exit 3——
  见任务 B）、coverage -Trend 平台差（处置见上条）。结论：3 项处置后 C-1
  就绪（除 remote/凭据）——**已随 run #5 闭环（2026-08-11，见下条）**
- CI 真跑（C-1）→ **已闭环（2026-08-11，GitHub Actions run #5，head 437fd35）**：
  132/132 steps 全绿（增补前 10+1 job：lint/test/coverage/msrv/conformance/deny/audit/
  semver/oracles/package/go-1-26，11 定义/17 次执行）在 windows/ubuntu/macos 全矩阵通过；
  go-differential 2026-08-12 增补后 ci.yml 为 10+2 job（12 定义）；run 历史
  run#1 workflow-parse fail → run#2 5 根因 → run#3 4 根因 → run#4 fmt import
  顺序 → run#5 全绿（明细见 §1 C-1 行）；结果已回填 fc-manifest（C-1 → closed）
- 五语言 CI（C-1 证据扩展到 TS/Python/Kotlin）→ **已完成（2026-08-12，head
  dbba9a4）**：GitHub Actions 四个 workflow 全绿——ci.yml run#9（Rust 10+1 job
  （增补前）保持全绿——go-differential 2026-08-12 增补后为 10+2/12 定义）、
  ci-typescript.yml run#2（ts-gates/ts-conformance/ts-differential）、
  ci-python.yml run#2（python-gates/python-conformance/python-differential）、
  ci-kotlin.yml run#2（kotlin-gates/kotlin-conformance/kotlin-differential）；
  首跑缺陷已在 dbba9a4 修复：python 测试夹具硬编码路径 8 处 → 仓库相对路径；
  kotlin jar 供给（直驱路径的 kotlin-test.jar / kotlin-test-junit5.jar 取自
  kotlinc 2.2.0 发行版 lib/，仅 junit-jupiter-api-5.10.2.jar 自 Maven Central；
  2026-08-13 修正记录见 five-language-ci-design.md §10）；TestShim.kt 已于
  2026-08-13 删除（死件，git 历史保留）；共享 conformance 脚本随 runner-CLI 批次
  仍为未来项（five-language-ci-design.md §10）
- 每 48h fuzz 账本检查 → 驱动暂停后账本冻结（最新快照 122,477 数据行 / 780.529 CPU-hours，2026-08-13 复算，runs.csv 权威；properties/yaml/ini/hcl/json 五单位已过 72h 门槛；驱动 2026-08-13 11:19 后未重启，详见 §1 C-2 行）

### 4.2 巡检 4 条观察记录（P2 级）

1. pilot-go-0.19.0.md §1 标题"12 个文件"而表含 13 行（logback.xml 为"—"）——与
   consema-go/go/pilot/pilot_test.go（行号可能漂移，以符号名为锚）的 12 文件注册一致，接受；
2. vectors/toml-v1.json 的 toml.corpus.cargo-manifest fixture 路径为裸
   `"Cargo.toml"`（仓库根，非 fixtures 下），Rust runner 用 include_bytes! 解析
   （consema-rs/consema-conformance/src/toml_v1.rs）——Go runner 落地时需继承同一
   解析约定；
3. 仅 json5/ 目录无独立 README（其余 8 家族有；toml/ 的 README 自 943c014 起存在）
   ——来源声明由 conformance/README 与 corpora 元数据承担，体例不一致可接受；
4. fixtures 层负向文件覆盖不均（json5/xml/hcl 的负向在 vectors/corpora/oracle
   层，体系层面满足）——接受，维持文档化替代载体。

soak 退出标准：本清单 §2 全部 ⏳ 转 ✓（或显式 judgment 记录）；§5 P2 清单逐项
disposition。

## 5. 已知 P2 发布判断清单（可带 judgment 随 RC 发布）

| # | 项 | 出处 | judgment 建议 |
|---|---|---|---|
| P2-1 | XML ReplaceText 词表不含 CDATA（RoleXmlText only） | 本 pilot F-1 | 双语言一致契约行为，文档化边界；随 rc.1 发布并在 cookbook 注明 |
| P2-2 | YAML family 无 dry-run 面（PlanEdit 显式拒绝） | 本 pilot F-2；G2.1 gap | **judgment 定案（2026-08-10）**：按 rc 纪律（§12.1 只收 blockers/security/docs errors）转 API 政策记录——补面是功能而非 blocker，移至 1.0.0 后窗口（RFC 0020 §3 兼容承诺面 revision note，2026-08-11）；拒绝行为已文档化 pin（`core.edit.operation-unsupported@1`） |
| P2-3 | JSONC/JSON5 插入元素为 canonical 片段拼写（`[80, 100,120]`） | 本 pilot F-3 | 契约行为（语义插入非格式化）；发布判断：接受 |
| P2-4 | 0.8.0 checksum manifest 不可从 git 历史复现（脏树记录） | 本 drill D-1 | **发布流程修正项**（发布时从干净 commit 生成），不阻塞 rc.1 本身 |
| P2-5 | 演练签名密钥无持久公钥可复验 | 本 drill D-2 | 随 C-3 真实密钥解决 |
| P2-6 | 部分权限失败与磁盘失败演练未记录 | §22.7 | 部分权限 leg 已闭环（2026-08-10，§3.5 演练 4）；仅磁盘失败 leg 待办（环境阻塞——§3.5 演练 5；C-1 已闭环（2026-08-11）后 Linux runner 完成路径现可用，演练本身仍待执行），RC soak 阶段 1 必做（§4） |
| P2-7 | Go CLI beta 合入前的 exchange 复跑 | §22.2 | **已闭环（2026-08-10）**：G5.6 合入后四 harness 复跑——协议交换 83/83（40 accept + 43 reject）、双向差分 108/108、字节 parity 68/68；shared-conformance 步骤 1 在本机 CRLF 工作树按 F-B 文档化行为报 digest 差异（规范 checkout 绿，CI 不受影响） |

## 6. 相关文件

- 本 pilot：`docs/pilot-go-0.19.0.md`（W1-W8 全流程、12 指标、三场迁移、Rust 复核）
- 可复现：`consema-go/go/pilot/pilot_test.go`（14 测试；`CONSEMA_PILOT_RUST_CLI` 时含跨语言对照）
- 先例：`docs/pilot-0.13.0.md`、`docs/release-process-0.13.0.md`、`docs/fc-manifest-0.13.0.json`
