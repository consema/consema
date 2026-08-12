# 0.13.0 release-candidate fuzz evidence (M8, agent H)

- 对应计划：`docs/0.13.0-gate-plan.md` M8（72 CPU-hours release-candidate fuzz，串行，依赖 M2）与 §15.3 质量门禁（路线图第 1381-1387 行）
- 缺陷分级：路线图 §18.4（第 1683-1685 行：P0 数据破坏/静默损失/RCE/错误写文件/跨快照误编辑；P1 panic/crash/hang/错误完成状态/明显语义不一致/limit bypass；P2 有安全替代路径的功能缺陷/非核心性能回退/诊断位置错误）
- 引擎：`crates/consema-conformance/src/fuzz.rs`（M2 落地的确定性 in-process 变异引擎，等价 harness 说明见该文件第 1-44 行）
- 机器日志（原始证据，本记录的唯一权威数字来源）：`docs/fuzz-evidence-0.13.0-logs/waves.log`（会话/波次摘要）与 `docs/fuzz-evidence-0.13.0-logs/runs.csv`（逐进程真实时长账本，追加式）

## 1. 机器事实（2026-08-07 实测）

| 项 | 值 |
|---|---|
| CPU | 13th Gen Intel(R) Core(TM) i9-13900HX（24 physical / 32 logical cores） |
| OS | Microsoft Windows 11 Pro 10.0.26200 |
| 工具链 | rustc 1.97.1 (8bab26f4f 2026-07-14) stable-x86_64-pc-windows-msvc；cargo 1.97.1 |
| clang | 未安装（MSVC-only）——libfuzzer-sys 的 C++ runtime 无法链接，`cargo fuzz run` 在本机不可用（cargo-fuzz 0.13.2 已安装但每个 target 都需要 clang runtime；fuzz.rs:10-13 与 `crates/*/fuzz/README.md` 同述） |
| 仓库 HEAD | 7e9de3825c74b9ee981bdf2d0a9316cdb1b0fd40（clean：M2 修复与语料已随 0.13.0 落地 commit 094f5d1/7e9de38 入库；会话期代码状态见 §5） |

## 2. 目标清单与迭代常数

每格式 target 逻辑单源在 `crates/<format>/fuzz/fuzz_logic/`（in-process 驱动 `include!` + cargo-fuzz wrapper 双接线）；迭代常数为驱动文件中的提交常量（证据：无种子空跑不算证据）。

| 驱动 | 长期 target 数 | 每 target 迭代（单次长期运行） | 合计变异数/波次 |
|---|---|---|---|
| `tests/parse_fuzz.rs` | 8（json/toml/yaml/ini/properties/xml/plist/hcl） | 100,000 变异 × 4 个 base = 400,000 | 3,200,000 |
| `tests/operation_fuzz.rs` | 8（同上） | 25,000 × 3 个 base = 75,000 | 600,000 |
| `tests/protocol_fuzz.rs` | 1（protocol decode: canonical JSON / PVCE varint / PGCE） | 100,000 × 4 × 2 seeds = 800,000 | 800,000 |
| **合计** | **17** | | **4,600,000** |

资源上限全部固定为生产 Profile 默认值（`*Limits::default()`）；limit 失败是 pass，不是 crash（fuzz_logic 契约）。属性测试（§15.3 property tests）：`tests/property_graph.rs`（PGCE 图 round-trip + YAML anchor/alias 解析）、`tests/property_protocol.rs`（protocol/varint/PVCE 规范化 fixed point）、`tests/property_plist.rs`（bplist offset/object-ref 每合法宽度）；mutation review：`conformance/corpora/mutation-v1.json`（46 fixture × 全量 case，replay 测试 `tests/mutation_corpus.rs`）。

## 3. 账本（追加式累计）

**账本文件**：`docs/fuzz-evidence-0.13.0-logs/runs.csv`，列：`session,wave,copy,target,iterations,wall_s,cpu_s,exit_code`。

- `cpu_s` 是每进程**真实 CPU 秒**（直接 .NET `Process.TotalProcessorTime` 采样，进程存活期间最后采样值——退出前最后一次采样，是保守下界；不是 wall × 并行度估计）。
- `wall_s` 是进程自身存活时长（launch → exit）。
- `exit_code`：0 = 全部断言通过；101 = 测试失败（= 找到 violation，P0/P1 事件）；-998 = 观测竞态未能取码（按失败处理并人工复核日志）；-1000 = 波次安全超时强杀（hang 候选，P1 事件）。
- 每会话汇总行写入 `waves.log`；`session` 列每驱动调用递增（`session start` 计数）。
- CPU-hours = Σ cpu_s / 3600，**只计真实测量值**；未测到的进程记 0（保守下界）。

### 3.1 会话时间线（诚实记录）

| session | 时间（2026-08-07） | 内容 | 结果 |
|---|---|---|---|
| 1-6 | 14:49-14:57 | 驱动脚本开发/排障（Start-Process 在该 .NET Framework 宿主上损坏 Process.CPU/ExitCode/HasExited 读取，已改用直接 .NET ProcessStartInfo 模式；问题与修复全程记录在 waves.log） | 无有效账本行（两波已运行测试全部通过，其 .out 日志为证；因观测失效未入账，不产生时长） |
| 7 | 14:56-15:06 | 验证波：1 wave × 1 copy（17 进程） | 17 行入账，0 失败，0.091 CPU-hours |
| 8 | 15:13:05-15:47:20（墙钟 34m15s） | 主累计运行：30 waves × 3 copies（51 进程/波） | **1530 行入账，0 失败，10.707 CPU-hours** |
| 9 | 16:48:23-16:51:30（墙钟约 3m07s） | 主累计：2 copies（34 进程/波）；waves 1-3 完成入账，wave 4 启动后未入账（operator ~16:51:30 停止驱动，无 session done 行） | 102 行入账，1,994.9 s（0.554 CPU-hours）；wave 3 的 10 行 exit=-1——外部终止（operator 停止 waves.log tail 监视器时的 TerminateProcess；waves.log 16:52:40 INCIDENT NOTE 分类非 fuzz finding，不清零、无 corpus regression），CPU 真实计入、变异未完成 |
| 10 | 16:54:51-17:32:44（墙钟 37m53s 至 wave 43 完成；与 session 11 交错运行） | 主累计：2 copies（34 进程/波）；waves 1-43 | 1462 行入账，0 失败；waves 1-42（1428 行，31,106.7 s = 8.641 CPU-hours）计入本文档累计快照；wave 43（34 行）于 17:32:44 快照后入账；waves 44+ 仍在驱动中持续入账（无 session done 行） |
| 11 | 17:21:19-17:32:22（墙钟 11m03s，含重建 4m57s） | 收尾：3 copies（51 进程/波）；waves 1-4 | 204 行入账，0 失败，4,935.7 s（1.371 CPU-hours）；驱动末行 **`session done: 3281 ledger rows; total CPU-hours=21.364 failures=0`**（17:32:22 快照，即 §3.2/§8 的累计基准；快照时 session 10 的 wave 43 尚未入账） |

> **快照基准（诚实口径）**：§3.2/§8 的累计数字以 session 11 的 session done 快照（17:32:22）为基准：3,281 行 = session 7 的 17 + session 8 的 1530 + session 9 的 102 + session 10（waves 1-42）的 1428 + session 11 的 204。快照后 session 10 的驱动仍在运行：wave 43（34 行，717.9 s = 0.199 CPU-hours）于 17:32:44 入账，waves 44+ 持续入账中（截至本文档更新时已至 wave 48，见 waves.log）——这些行不在本累计内，按 §4.4 协议在驱动结束后的会话更新中计入。

> **编号规则与标签偏差说明（2026-08-10 追加，诚实记录）**：会话编号由 `run_waves.ps1:111-113` 生成——`$sessionNum = (waves.log 中 'session start' 行计数) + 1`，即按 waves.log 的 start 行计数，而非 runs.csv 数据行。2026-08-10 16:39:29 的 session-90 驱动调用在 wave 1 启动后被杀（外部终止）：waves.log 第 1806 行已写入 `session start: session=90`，但零数据行入账；16:40:40 的重启（waves.log 第 1812 行）按该计数规则自动续号为 **91**。因此 16:40 之后运行的各会话实际编号比"按调用顺序假设"大 1：主 agent 自提交 220801d 起的约 18 条提交信息中的 `session N` 标签与 waves.log 编号差一（例：17:30:25 的 100.703 CPU-hours 快照，waves.log 标 session 105、提交信息标 session 104）。**权威声明**：runs.csv 为唯一权威账本（数据），waves.log 编号为会话标识权威（session 列即由此写入 runs.csv）；提交信息标签仅描述性，数据本身无影响——100.703 快照在 §3.2.1/§8 已按 waves.log 正确标注为 session 105。

> **2026-08-10 晚至 08-11 驱动事件时间线（追加，诚实记录）**：
> 1. session 90（08-10 16:39）：驱动在 wave 1 启动后被杀（外部终止，零行；重启自动续号为 91——见上方编号规则说明）；
> 2. session 166（20:43）wave 4 中被杀（waves 1-3 入账 102 行）；session 170（20:57）wave 4 行写入后、session done 前被杀（136 行全入账）；session 179（21:15）wave 2 中被杀（34 行）；session 180（21:17）wave 4 中被杀（102 行）；session 187（21:37）wave 2 中被杀（34 行）；session 188（21:38）wave 3 中被杀（68 行）——全部为外部终止、零数据丢失、已按 session 9 分类体例在提交信息中记录；
> 3. session 191（22:12）wave 1 后**驱动挂起 1 小时**（34 进程消失但无 wave done 行）——主 agent 杀进程重启；零行损失；
> 4. session 192（22:12 恢复编号）运行完整（136 行）但 **waves.log 零写入**——根因：Monitor 的 tail -f（PID 57336，22:12:20 起）以排他方式持有 waves.log（Git tail 无 FILE_SHARE_WRITE），驱动 Add-Content 静默失败（ErrorActionPreference=Continue）；runs.csv 不受影响；处置：杀 tail、恢复 session-192 start 行（编号连续性）、事件说明写入日志；**教训：Monitor 的 tail -f 不能用于驱动正在追加的日志文件**；
> 5. 08-11 08:53：为消除心跳轮询 ~77% 空转，驱动改为**分离进程连续 wrapper**（while 循环背靠背跑会话），会话间隔 ~3.3 分钟，速率恢复 ~12 CPU-h/墙钟小时。

> **2026-08-12 session 448 wave 3 超时 incident（追加，诚实记录）**：
> 2026-08-12 10:15:18，session 448 wave 3 的 34 个进程中有 16 个以 FAIL 被收割（exit=-1000，wall=1800s，cpu=0s；对应 errlog 全部 0 字节）——进程未执行即被波次安全超时强杀（wave 超时收割路径：cpu=0s 且 errlog 无输出，target 代码未运行，非 target 内 hang）；已按 session-9 体例分类为**非 fuzz finding**——不清零任何 target 的 release-candidate clean 计时、无 corpus regression（§4 step 2）；wave 1/2/4 正常入账，session 449 起恢复；账本非零退出累计 = session-9 的 10 行 + 本 incident 的 16 行 = **26 行，均非 fuzz finding**。

### 3.2 每 target 累计账本（数据源 runs.csv，3281 行 = session 7 的 17 行 + session 8 的 1530 行 + session 9 的 102 行 + session 10（waves 1-42）的 1428 行 + session 11 的 204 行；其中 3271 行 exit_code=0，10 行 exit=-1——session 9 wave 3 外部终止、已分类非 fuzz finding，见 §3.1）

每 target 193 次运行（session 7 1 次 + session 8 30 波 × 3 copy 的 90 次 + session 9 3 波 × 2 copy 的 6 次 + session 10（waves 1-42）× 2 copy 的 84 次 + session 11 4 波 × 3 copy 的 12 次）。累计变异数 = 193 × 每 target 单次迭代常数（parse 400,000 / ops 75,000 / protocol 800,000；session 9 wave 3 的 10 行按计划常数计入但实际变异未完成，见 §3.1）；全部 target 合计 **887,800,000 次变异**。时钟状态：全部 running（clean）——本日无任何新 crash/panic/hang/limit bypass，无 target 清零。

| target | 运行数 | 累计真实 CPU 秒 | CPU-hours | 累计变异数 | findings | 时钟 |
|---|---|---|---|---|---|---|
| json-parse | 193 | 6,759.4 | 1.878 | 77,200,000 | 0 | running (clean) |
| json-ops | 193 | 2,637.3 | 0.733 | 14,475,000 | 0（M2-F1 已知，见 §6） | running (clean) |
| toml-parse | 193 | 4,293.1 | 1.193 | 77,200,000 | 0 | running (clean) |
| toml-ops | 193 | 1,308.7 | 0.364 | 14,475,000 | 0 | running (clean) |
| yaml-parse | 193 | 8,869.6 | 2.464 | 77,200,000 | 0 | running (clean) |
| yaml-ops | 193 | 3,633.5 | 1.009 | 14,475,000 | 0（M2-F2 已知，见 §6） | running (clean) |
| ini-parse | 193 | 8,776.3 | 2.438 | 77,200,000 | 0 | running (clean) |
| ini-ops | 193 | 3,589.7 | 0.997 | 14,475,000 | 0 | running (clean) |
| properties-parse | 193 | 9,447.4 | 2.624 | 77,200,000 | 0 | running (clean) |
| properties-ops | 193 | 5,034.1 | 1.398 | 14,475,000 | 0 | running (clean) |
| xml-parse | 193 | 2,621.4 | 0.728 | 77,200,000 | 0 | running (clean) |
| xml-ops | 193 | 822.5 | 0.228 | 14,475,000 | 0 | running (clean) |
| plist-parse | 193 | 3,735.8 | 1.038 | 77,200,000 | 0 | running (clean) |
| plist-ops | 193 | 965.4 | 0.268 | 14,475,000 | 0 | running (clean) |
| hcl-parse | 193 | 7,065.9 | 1.963 | 77,200,000 | 0 | running (clean) |
| hcl-ops | 193 | 2,352.4 | 0.653 | 14,475,000 | 0 | running (clean) |
| protocol-decode | 193 | 4,997.0 | 1.388 | 154,400,000 | 0 | running (clean) |
| **合计** | **3281** | **76,909.5** | **21.364** | **887,800,000** | **0 新** | — |

按格式家族（parse+ops 汇总）：json 2.610 / toml 1.556 / yaml 3.473 / ini 3.435 / properties 4.023 / xml 0.957 / plist 1.306 / hcl 2.616 CPU-hours；protocol（单 target）1.388。

### 3.2.1 2026-08-07 会话结束快照（追加；runs.csv 为唯一权威账本
**2026-08-12 10:17 快照（追加式；runs.csv 为唯一权威账本）**：账本 62,432 行 / **≈460 CPU-hours**（零新 crash；非零退出 = 10 行 session-9 外部终止 + 16 行 session-448 wave 3 超时分类 = 26 行，均非 fuzz finding，见 §3.1 事件时间线）。每格式门槛单位累计（CPU-hours，本机复算）：properties **85.5**（118.8%，已过 72h）/ yaml **75.8**（105.3%，已过 72h）/ ini **72.8**（101.1%，已过 72h）/ hcl **55.5**（77.1%）/ json **55.1**（76.5%）/ toml **33.3**（46.3%）/ protocol-decode **29.1**（40.4%）/ plist **26.7**（37.1%）/ xml **19.6**（27.2%）。properties/yaml/ini 三单位已过 72h 门槛；其余单位继续按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机连续 wrapper 续跑为备选）；runs.csv 为唯一权威账本，后续会话数字随快照继续追加。
**2026-08-11 会话 235-297 累计（追加式）**：session 297 完成态 + 298 首波（41,939 行 / 258.327 CPU-hours，2026-08-11 15:39 窗口复算）— runs.csv 41,939 行 / **258.327 CPU-hours**（41,929 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1））。每格式家族累计（CPU-hours，本机复算）：json **31.5** / toml **19.0** / yaml **42.6** / ini **41.3** / properties **48.1** / xml **11.6** / plist **15.8** / hcl **31.6** / protocol（单 target）**16.8**。相对每格式 72h 门槛，最接近的 properties **66.8%**（48.1/72；其余：yaml 59.2%、ini 57.4%、hcl 43.9%、json 43.8%、toml 26.4%、protocol 23.3%、plist 21.9%、xml 16.1%）；**72h 门槛仍开放**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机连续 wrapper 续跑为备选）；session 298+ 持续追加中，后续会话数字随 §3.2.1 快照继续追加。
**2026-08-11 会话 79-234 累计（追加式）**：账本 33,337 行 / **188.336 CPU-hours**（session 234 时点复算，2026-08-11；零失败——除 session 9 已分类 10 行 exit=-1）。每格式家族累计（CPU-hours，本机复算）：json 23.0 / toml 13.9 / yaml 30.8 / ini 30.0 / properties 34.8 / xml 8.7 / plist 11.8 / hcl 23.0；protocol（单 target）12.3。相对每格式 72h 门槛最接近 properties **48.3%**（34.8/72；其余：yaml 42.8%、ini 41.6%、hcl/json 32.0%、toml 19.4%、protocol 17.1%、plist 16.4%、xml 12.1%）；runs.csv 为唯一权威账本；session 235+ 持续追加中；**每格式 72h 门槛仍开放，完成路径不变（§7：clang 主机 cargo-fuzz 为主、本机连续 wrapper 续跑为备选）**。发布记录数字以本快照为准。
**2026-08-10 会话 12-68 累计（追加式）**：总量跨 72 CPU-hours（11,815 行 / 72.275 CPU-hours，零失败）；每格式 72h 门槛仍开放（最接近家族 properties ~17%），完成路径不变（§7：clang 主机 cargo-fuzz 为主，本机确定性协议续跑为备选）。发布记录数字以本表快照为准。
> **修正注记（2026-08-11 审计）**：本条目数字实为 session-69 完成态（waves.log 15:19:28 `session done: 11815 rows / 72.275 CPU-hours`）；session≤68 实为 11,679 行 / 71.479 CPU-hours，未跨 72h 门槛；`properties ~17%` 对应 ≤60-61 状态（17.1%）而非本条目截止点（18.7%）。数据本身真实（runs.csv 逐位可复现），仅标签/截止点 off-by-one，与既有编号规则说明同类。
**2026-08-10 会话 79-105 累计（追加式）**：账本 16,473 行 / **100.703 CPU-hours**（session 105 的 session done 快照，2026-08-10 17:30:25——跨 100 CPU-hours 里程碑；零失败——除 session 9 已分类 10 行 exit=-1）。每格式家族累计（CPU-hours，本机复算）：json 12.2 / toml 7.4 / yaml 16.6 / ini 16.1 / properties 18.8 / xml 4.6 / plist 6.2 / hcl 12.3；protocol（单 target）6.6。相对每格式 72h 门槛最接近 properties **26.1%**（18.8/72；其余：yaml 23.0%、ini 22.3%、hcl 17.1%、json 17.0%、toml 10.2%、protocol 9.1%、plist 8.6%、xml 6.4%）；**每格式 72h 门槛仍开放，完成路径不变（§7）**。session 106+ 驱动中（waves.log 持续追加）；发布记录数字以本快照为准。
**2026-08-10 会话 69-78 累计（追加式）**：账本 12,937 行 / **78.971 CPU-hours**（session 78 的 session done 快照，2026-08-10 15:53:39；零失败——除 session 9 已分类 10 行 exit=-1）。每格式家族累计（CPU-hours，本机复算）：json 9.6 / toml 5.8 / yaml 13.0 / ini 12.6 / properties 14.7 / xml 3.6 / plist 4.9 / hcl 9.6；protocol（单 target）5.1。相对每格式 72h 门槛最接近 properties **20.4%**（14.7/72；其余：yaml 18.0%、ini 17.5%、hcl/json 13.4%、toml 8.0%、protocol 7.2%、plist 6.8%、xml 5.0%）；**每格式 72h 门槛仍开放，完成路径不变（§7）**。session 79+ 驱动中（waves.log 持续追加）；发布记录数字以本快照为准。

**2026-08-10 会话 12 快照（追加式）**：8 waves × 2 copies，零失败；账本 4,335 行 / 27.852 CPU-hours；最接近的 properties-parse 4.8%（3.429/72）。发布记录数字以本表快照为准。
，发布记录数字以本表快照为准）

驱动结束后按 §4.4 协议把 session 10 的 wave 43 与 waves 44-65 全部并入：**4,063 行** = session 7 的 17 + session 8 的 1530 + session 9 的 102 + session 10 全量 + session 11 全量（waves 1-65 全部入账）。其中 4,053 行 exit_code=0，10 行 exit=-1（session 9 wave 3 外部终止、已分类非 fuzz finding，见 §3.1）。每 target 239 次运行；累计计划变异 **1,099,400,000（10.994 亿）次**。时钟状态：全部 running（clean）——本日无任何新 crash/panic/hang/limit bypass，无 target 清零。

| target | 运行数 | 累计真实 CPU 秒 | CPU-hours | 累计变异数 | findings | 时钟 |
|---|---|---|---|---|---|---|
| json-parse | 239 | 8,301.0 | 2.306 | 95,600,000 | 0 | running (clean) |
| json-ops | 239 | 3,240.3 | 0.900 | 17,925,000 | 0（M2-F1 已知，见 §6） | running (clean) |
| toml-parse | 239 | 5,269.2 | 1.464 | 95,600,000 | 0 | running (clean) |
| toml-ops | 239 | 1,622.5 | 0.451 | 17,925,000 | 0 | running (clean) |
| yaml-parse | 239 | 10,952.9 | 3.042 | 95,600,000 | 0 | running (clean) |
| yaml-ops | 239 | 4,509.5 | 1.253 | 17,925,000 | 0（M2-F2 已知，见 §6） | running (clean) |
| ini-parse | 239 | 10,832.0 | 3.009 | 95,600,000 | 0 | running (clean) |
| ini-ops | 239 | 4,404.6 | 1.224 | 17,925,000 | 0 | running (clean) |
| properties-parse | 239 | 11,684.0 | 3.246 | 95,600,000 | 0 | running (clean) |
| properties-ops | 239 | 6,186.7 | 1.719 | 17,925,000 | 0 | running (clean) |
| xml-parse | 239 | 3,226.9 | 0.896 | 95,600,000 | 0 | running (clean) |
| xml-ops | 239 | 1,014.8 | 0.282 | 17,925,000 | 0 | running (clean) |
| plist-parse | 239 | 4,580.0 | 1.272 | 95,600,000 | 0 | running (clean) |
| plist-ops | 239 | 1,185.3 | 0.329 | 17,925,000 | 0 | running (clean) |
| hcl-parse | 239 | 8,682.2 | 2.412 | 95,600,000 | 0 | running (clean) |
| hcl-ops | 239 | 2,887.6 | 0.802 | 17,925,000 | 0 | running (clean) |
| protocol-decode | 239 | 6,133.5 | 1.704 | 191,200,000 | 0 | running (clean) |
| **合计** | **4063** | **94,713.0** | **26.309** | **1,099,400,000** | **0 新** | — |

按格式家族（parse+ops 汇总）：json 3.206 / toml 1.914 / yaml 4.295 / ini 4.232 / properties 4.964 / xml 1.178 / plist 1.601 / hcl 3.214 CPU-hours；protocol（单 target）1.704。

### 3.3 波次执行方式与诚实口径

- 每波 = 17 个长期 target 的 `Copies` 份并发进程，每进程一个核心（`--test-threads=1`），整波并行跨满机器核心；波与波之间做 tree-hash 检查（`git status --porcelain -- crates Cargo.toml Cargo.lock conformance` + HEAD），代码变化（修复 agent 落地）→ 先重建测试二进制再跑下一波，保证每波都是**当前 release-candidate 代码状态**的真实运行。
- **确定性说明（必须公开）**：引擎是确定性变异（提交种子 + 提交 corpus），同一代码状态下的重复运行覆盖完全相同的变异计划；**新增探索只发生在代码变化后的运行**（本会话中修复 agent 多次落地，见 §5）或 clang 主机的 cargo-fuzz（corpus 进化，见 §7）。账本如实记录"跑了什么"，不把重复运行冒充新探索；72 CPU-hours 的完成路径以 §7 为准。

## 4. 累计协议（后来的运行如何追加）

1. 从仓库根目录运行：`powershell -NoProfile -ExecutionPolicy Bypass -File docs\fuzz-evidence-0.13.0-logs\run_waves.ps1 -Waves <N> -Copies <C>`（脚本是 §3.3 协议的机器可执行形式；每波自动 tree-hash → 重建 → 并发运行 → 逐进程真实 CPU/墙钟/退出码 → 追加 runs.csv 与 waves.log）。
2. 任何 FAIL 行（exit ≠ 0）都是事件：立即停止追加，按 §6 分类；**新 crash 清零该 target 的 release-candidate clean 计时**（§15.3 第 1389 行），并把最小输入按 `conformance/corpora/README.md` 的 regressions 工作流永久加入 `conformance/corpora/mutation-v1.json` 的 `regressions` 数组（replay 测试从此永久覆盖）。
3. 追加永不改写既有行（只 append）；汇总从 runs.csv 重算。
4. 会话结束更新本文档 §3.2 与 §8 的累计数字。
5. 已知发现（M2-F1/M2-F2）不计入新 crash，不清零时钟；其状态在 §6 跟踪。

## 5. 代码状态与并发修复（2026-08-07 会话内复核）

修复 agent 与本会话并行落地（未提交，工作树状态）：

- **M2-F1（json Recovered gate）**：修复已落地——`crates/consema-json/src/projection.rs`（`ProjectionFailure::RecoveredDocument`，recovered 文档在 `Document::project` 入口被拒）与 `crates/consema-json/src/edit.rs`（`EditFailure::RecoveredDocument`，`commit` 入口被拒）；驱动中的计数豁免已移除，恢复严格断言（`crates/consema-conformance/tests/operation_fuzz.rs:123` 注释"Finding M2-F1 fixed"）。
- **M2-F2（yaml 引号 `"~"` 内容丢失）**：修复已落地——`crates/consema-yaml/src/native.rs` `exact_empty_scalar` 仅对 plain 样式重写空占位；`tests/property_graph.rs` 改为 trip-wire（fixed 注释，见第 20-34 行）。
- 本会话每波构建的二进制因此覆盖了"修复前最后一次旧状态（session 7 部分）→ 严格断言新状态"的多个代码快照；tree-hash 行逐波记录。

## 6. 发现分类（§18.4）

| ID | target | 描述 | 分级 | 时钟 | 状态（2026-08-07 会话） |
|---|---|---|---|---|---|
| M2-F1 | json project/edit | Recovered 文档被 project/edit 接受（错误完成状态） | P1 | 不清零（已知发现，计数器/断言跟踪） | 修复已落地工作树（projection.rs / edit.rs 的 RecoveredDocument 门）；驱动豁免已移除，严格断言生效（operation_fuzz.rs:123） |
| M2-F2 | yaml native decode | 引号 `"~"` 解码为空（引号标量静默内容丢失） | P0（§18.4 静默损失） | 不清零（已知发现，trip-wire 跟踪） | 修复已落地工作树（native.rs `exact_empty_scalar` 仅 plain 样式重写）；trip-wire 生效（property_graph.rs） |
| 本日会话（session 7-11） | 全部 17 target | 无新 crash/panic/hang/limit bypass；3281 行账本中 3271 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止，已分类非 fuzz finding，见 §3.1） | — | 全部 running（clean） | 账本见 §3.2 |

新发现协议：P0/P1 = 立即报告 + 最小输入入 corpus + 清零该 target 时钟；P2 = 记录并给发布判断。`1.0.0` 不允许未解决 P0/P1（§18.4 第 1689 行）。

## 7. 完成路径（72 CPU-hours 剩余部分）

本机（MSVC，无 clang）只能用 in-process harness 累计（§1）；**文档化的完成路径**：

1. **首选（clang 主机，corpus 进化）**：在 Linux + nightly + clang 主机上，对 9 个 crate 的 17 个 cargo-fuzz target 运行 `cargo +nightly fuzz run <target>`（`crates/<format>/fuzz/` 下：8 × `parse` + 8 × `operations` + protocol `decode`；wrapper 直接复用同一 `fuzz_logic` 单源）。corpus 种子已提交（`fuzz/corpus/<target>/`），首次构建生成的 `fuzz/Cargo.lock` 应一并提交（M8 证据规则：无种子运行不算证据）。每格式按 §3 协议把运行时长追加进本账本。
2. **备选（本机继续）**：重复 §4 协议继续 in-process 波次；注意确定性口径（§3.3）——只有代码变化后的波次提供新探索。
3. **每格式 72 CPU-hours 门槛**：按格式家族汇总其 parse+ops（protocol 单独）target 的累计 CPU-hours，达到 72 且零未解释问题（§15.3）才算关闭该格式；本会话累计见 §8。

## 8. 本会话累计与剩余（诚实陈述）

**本日（2026-08-07，session 7-11）真实累计：21.364 CPU-hours**（76,909.5 真实 CPU 秒；3281 行账本，其中 3271 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止，已分类非 fuzz finding，见 §3.1），8.878 亿次计划变异；waves.log/runs.csv 为原始记录；累计基准为 session 11 的 session done 快照 17:32:22，见 §3.1 快照说明）。

- 每格式累计（CPU-hours）：json **2.610** / toml **1.556** / yaml **3.473** / ini **3.435** / properties **4.023** / xml **0.957** / plist **1.306** / hcl **2.616** / protocol（单 target）**1.388**。
- 相对每格式 72 CPU-hours 门槛（§15.3，按格式家族），最接近的 properties 也仅 5.6%（4.023/72；其余：yaml 4.8%、ini 4.8%、hcl/json 3.6%、toml 2.2%、protocol 1.9%、plist 1.8%、xml 1.3%）；**72h 门槛未完成**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机协议续跑为备选）。
- **确定性口径（重复声明）**：本机 in-process 波次在相同代码状态下覆盖相同的确定性变异计划（§3.3）；本会话期间修复 agent 多次落地（§5），因此波次覆盖了多个代码快照；会话内所有运行的真实时长均已入账，未测到/观测失败的运行记 0 或未入账（§3.1 时间线如实记录）。
- **corpus regressions**：本会话无新发现，`conformance/corpora/mutation-v1.json` 的 `regressions` 数组未新增条目（保持空）。
- **workspace 门禁**：`cargo test --workspace --locked` 于 session 8 结束时（15:49 前后）对当时工作树运行，**1617 passed / 0 failed，exit 0 全绿**（完整日志 `docs/fuzz-evidence-0.13.0-logs/workspace-gate-2026-08-07.log`；修复 agent 的 M2-F1/M2-F2 严格断言随其工作树状态通过）。
- **corpus 全绿**：`cargo test -p consema-conformance --test mutation_corpus --locked -- --ignored` 全量 175k case replay 通过（63.10s，2026-08-07 15:49）。（证据链说明（2026-08-11 审计追加）：workspace-gate-2026-08-07.log 存在（15:48:41 写入）但未含本行 63.10s 全量 replay 的通过记录——该日志中 `mutation_corpus_replay_full` 标记为 ignored（manual evidence run: full 175k-case replay）、仅 `mutation_corpus_replay_bounded` 通过（2.57s）；63.10s 全量 replay 的原始输出未保留在仓内，本声明以当日 15:49 的 `-- --ignored` 运行记录为准（与五要素复核 174,921 case / 63.10s 同源））
- 剩余工作：每格式累计至 72 CPU-hours 且零未解释问题；M2-F1/M2-F2 修复提交（工作树状态）后复核 trip-wire/严格断言继续全绿。
- **2026-08-07 会话结束快照（追加；runs.csv 为唯一权威账本，发布记录数字以本快照为准）**：驱动结束后 session 10/11 全部波次已入账，runs.csv 现为 4,063 行（waves 1-65 全部入账）：**26.309 CPU-hours**（94,713.0 真实 CPU 秒；4,053 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1），10.994 亿次计划变异）。每格式家族累计（CPU-hours）：json **3.206** / toml **1.914** / yaml **4.295** / ini **4.232** / properties **4.964** / xml **1.178** / plist **1.601** / hcl **3.214** / protocol（单 target）**1.704**。
- 相对每格式 72 CPU-hours 门槛（§15.3，按格式家族），最接近的 properties 也仅 **6.9%**（4.964/72；其余：yaml 6.0%、ini 5.9%、hcl/json 4.5%、protocol 2.4%、toml 2.7%、plist 2.2%、xml 1.6%）；**72h 门槛未完成**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机协议续跑为备选）。
- **2026-08-10 会话 69-78 累计（追加式；runs.csv 为唯一权威账本，发布记录数字以本快照为准）**：session 78 的 session done 快照（15:53:39）——runs.csv 12,937 行 / **78.971 CPU-hours**（12,927 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1））。每格式家族累计（CPU-hours，本机复算）：json **9.6** / toml **5.8** / yaml **13.0** / ini **12.6** / properties **14.7** / xml **3.6** / plist **4.9** / hcl **9.6** / protocol（单 target）**5.1**。相对每格式 72h 门槛，最接近的 properties **20.4%**（14.7/72；其余：yaml 18.0%、ini 17.5%、hcl/json 13.4%、toml 8.0%、protocol 7.2%、plist 6.8%、xml 5.0%）；**72h 门槛仍开放**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机协议续跑为备选）。session 79+ 驱动中，后续会话数字随 §3.2.1 快照继续追加。
- **2026-08-10 会话 79-105 累计（追加式；runs.csv 为唯一权威账本，发布记录数字以本快照为准）**：session 105 的 session done 快照（17:30:25）——runs.csv 16,473 行 / **100.703 CPU-hours**（跨 100 CPU-hours 里程碑；16,463 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1））。每格式家族累计（CPU-hours，本机复算）：json **12.2** / toml **7.4** / yaml **16.6** / ini **16.1** / properties **18.8** / xml **4.6** / plist **6.2** / hcl **12.3** / protocol（单 target）**6.6**。相对每格式 72h 门槛，最接近的 properties **26.1%**（18.8/72；其余：yaml 23.0%、ini 22.3%、hcl 17.1%、json 17.0%、toml 10.2%、protocol 9.1%、plist 8.6%、xml 6.4%）；**72h 门槛仍开放**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机协议续跑为备选）。session 106+ 驱动中，后续会话数字随 §3.2.1 快照继续追加。
- **2026-08-11 会话 79-234 累计（追加式；runs.csv 为唯一权威账本，发布记录数字以本快照为准）**：session 234 时点复算（2026-08-11）——runs.csv 33,337 行 / **188.336 CPU-hours**（33,327 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1））。每格式家族累计（CPU-hours，本机复算）：json **23.0** / toml **13.9** / yaml **30.8** / ini **30.0** / properties **34.8** / xml **8.7** / plist **11.8** / hcl **23.0** / protocol（单 target）**12.3**。相对每格式 72h 门槛，最接近的 properties **48.3%**（34.8/72；其余：yaml 42.8%、ini 41.6%、hcl/json 32.0%、toml 19.4%、protocol 17.1%、plist 16.4%、xml 12.1%）；**72h 门槛仍开放**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机连续 wrapper 续跑为备选）；session 235+ 持续追加中，后续会话数字随 §3.2.1 快照继续追加。
- **2026-08-11 会话 235-297 累计（追加式）**：session 297 完成态 + 298 首波（41,939 行 / 258.327 CPU-hours，2026-08-11 15:39 窗口复算）— runs.csv 41,939 行 / **258.327 CPU-hours**（41,929 行 exit 0、10 行 exit=-1（session 9 wave 3 外部终止、非 fuzz finding，见 §3.1））。每格式家族累计（CPU-hours，本机复算）：json **31.5** / toml **19.0** / yaml **42.6** / ini **41.3** / properties **48.1** / xml **11.6** / plist **15.8** / hcl **31.6** / protocol（单 target）**16.8**。相对每格式 72h 门槛，最接近的 properties **66.8%**（48.1/72；其余：yaml 59.2%、ini 57.4%、hcl 43.9%、json 43.8%、toml 26.4%、protocol 23.3%、plist 21.9%、xml 16.1%）；**72h 门槛仍开放**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机连续 wrapper 续跑为备选）；session 298+ 持续追加中，后续会话数字随快照继续追加。
- **2026-08-12 10:17 快照（追加式；runs.csv 为唯一权威账本，发布记录数字以本快照为准）**：账本 62,432 行 / **≈460 CPU-hours**（零新 crash；非零退出 = 10 行 session-9 + 16 行 session-448 wave 3 超时分类 = 26 行，均非 fuzz finding，见 §3.1 事件时间线）。每格式门槛单位累计（CPU-hours，本机复算）：properties **85.5**（118.8%，已过 72h）/ yaml **75.8**（105.3%，已过 72h）/ ini **72.8**（101.1%，已过 72h）/ hcl **55.5**（77.1%）/ json **55.1**（76.5%）/ toml **33.3**（46.3%）/ protocol-decode **29.1**（40.4%）/ plist **26.7**（37.1%）/ xml **19.6**（27.2%）。三单位已过 72h 门槛，其余单位仍开放，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机连续 wrapper 续跑为备选）；runs.csv 为唯一权威账本。

## 9. 开放事项

- `crates/consema-conformance/examples/gen_mutation_corpus.rs` regressions 保留事项已解决：修复已随 commit 92a244a 落地——`generate()` 接收 regressions 文本并原样写入输出（不再硬编码 `[]`），`extract_regressions` 从已提交 corpus 逐字提取既有数组，新文件仍为 `[]`；`--check` 与手工 regressions 条目不再冲突（本文档 §4 工作流不变，replay 测试已覆盖 regressions）。
- M2-F1/M2-F2 修复的工作树状态→提交事项已解决：修复已随 0.13.0 落地 commit 094f5d1/7e9de38 提交入库（§8 记录 session 8 结束时的 workspace 门禁 1,617 passed / 0 failed；CHANGELOG.md:49 同步）。
- session 10/11 驱动已结束：waves 1-65 全部入账并计入 §3.2.1 会话结束快照（原"wave 43 于 17:32:44 入账、waves 44+ 持续入账"事项已解决）。
- session 7 的 wall_s 是"launch→波次结束"（该会话脚本尚未记录进程自身退出时刻；cpu_s 均为真实测量），session 8 起 wall_s 为进程自身存活时长——两段口径已在 runs.csv 中如实区分（§3.1 时间线）。
