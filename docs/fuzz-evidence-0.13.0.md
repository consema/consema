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
| 仓库 HEAD | 9c1ede20fab56829cfaeca6924ee115ff01cd5d2（脏树：M2 文件未提交 + 修复 agent 并发落地中，见 §5） |

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

### 3.2 每 target 累计账本（数据源 runs.csv，1547 行 = session 7 的 17 行 + session 8 的 1530 行；全部 exit_code=0）

每 target 91 次运行（session 7 1 次 + session 8 30 波 × 3 copy）。累计变异数 = 91 × 每 target 单次迭代常数（parse 400,000 / ops 75,000 / protocol 800,000）；全部 target 合计 **418,600,000 次变异**。时钟状态：全部 running（clean）——本会话无任何新 crash/panic/hang/limit bypass，无 target 清零。

| target | 运行数 | 累计真实 CPU 秒 | CPU-hours | 累计变异数 | findings | 时钟 |
|---|---|---|---|---|---|---|
| json-parse | 91 | 3,452.4 | 0.959 | 36,400,000 | 0 | running (clean) |
| json-ops | 91 | 1,338.4 | 0.372 | 6,825,000 | 0（M2-F1 已知，见 §6） | running (clean) |
| toml-parse | 91 | 2,182.7 | 0.606 | 36,400,000 | 0 | running (clean) |
| toml-ops | 91 | 658.7 | 0.183 | 6,825,000 | 0 | running (clean) |
| yaml-parse | 91 | 4,463.5 | 1.240 | 36,400,000 | 0 | running (clean) |
| yaml-ops | 91 | 1,729.5 | 0.480 | 6,825,000 | 0（M2-F2 已知，见 §6） | running (clean) |
| ini-parse | 91 | 4,424.2 | 1.229 | 36,400,000 | 0 | running (clean) |
| ini-ops | 91 | 1,830.1 | 0.508 | 6,825,000 | 0 | running (clean) |
| properties-parse | 91 | 4,730.6 | 1.314 | 36,400,000 | 0 | running (clean) |
| properties-ops | 91 | 2,594.0 | 0.721 | 6,825,000 | 0 | running (clean) |
| xml-parse | 91 | 1,328.5 | 0.369 | 36,400,000 | 0 | running (clean) |
| xml-ops | 91 | 406.9 | 0.113 | 6,825,000 | 0 | running (clean) |
| plist-parse | 91 | 1,896.2 | 0.527 | 36,400,000 | 0 | running (clean) |
| plist-ops | 91 | 481.8 | 0.134 | 6,825,000 | 0 | running (clean) |
| hcl-parse | 91 | 3,618.8 | 1.005 | 36,400,000 | 0 | running (clean) |
| hcl-ops | 91 | 1,193.7 | 0.332 | 6,825,000 | 0 | running (clean) |
| protocol-decode | 91 | 2,542.2 | 0.706 | 72,800,000 | 0 | running (clean) |
| **合计** | **1547** | **38,872.2** | **10.798** | **418,600,000** | **0 新** | — |

按格式家族（parse+ops 汇总）：json 1.331 / toml 0.789 / yaml 1.720 / ini 1.737 / properties 2.035 / xml 0.482 / plist 0.661 / hcl 1.337 CPU-hours；protocol（单 target）0.706。

### 3.3 波次执行方式与诚实口径

- 每波 = 17 个长期 target 的 `Copies` 份并发进程，每进程一个核心（`--test-threads=1`），整波并行跨满机器核心；波与波之间做 tree-hash 检查（`git status --porcelain -- crates Cargo.toml Cargo.lock conformance` + HEAD），代码变化（修复 agent 落地）→ 先重建测试二进制再跑下一波，保证每波都是**当前 release-candidate 代码状态**的真实运行。
- **确定性说明（必须公开）**：引擎是确定性变异（提交种子 + 提交 corpus），同一代码状态下的重复运行覆盖完全相同的变异计划；**新增探索只发生在代码变化后的运行**（本会话中修复 agent 多次落地，见 §5）或 clang 主机的 cargo-fuzz（corpus 进化，见 §7）。账本如实记录"跑了什么"，不把重复运行冒充新探索；72 CPU-hours 的完成路径以 §7 为准。

## 4. 累计协议（后来的运行如何追加）

1. 从仓库根目录运行：`powershell -NoProfile -ExecutionPolicy Bypass -File docs\fuzz-evidence-0.13.0-logs\run_waves.ps1 -Waves <N> -Copies <C>`（脚本是 §3.3 协议的机器可执行形式；每波自动 tree-hash → 重建 → 并发运行 → 逐进程真实 CPU/墙钟/退出码 → 追加 runs.csv 与 waves.log）。
2. 任何 FAIL 行（exit ≠ 0）都是事件：立即停止追加，按 §6 分类；**新 crash 清零该 target 的 release-candidate clean 计时**（§15.3 第 1387 行），并把最小输入按 `conformance/corpora/README.md` 的 regressions 工作流永久加入 `conformance/corpora/mutation-v1.json` 的 `regressions` 数组（replay 测试从此永久覆盖）。
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
| 本次会话（session 7-8） | 全部 17 target | 无新 crash/panic/hang/limit bypass（1547 次运行全部 exit 0） | — | 全部 running（clean） | 账本见 §3.2 |

新发现协议：P0/P1 = 立即报告 + 最小输入入 corpus + 清零该 target 时钟；P2 = 记录并给发布判断。`1.0.0` 不允许未解决 P0/P1（§18.4 第 1689 行）。

## 7. 完成路径（72 CPU-hours 剩余部分）

本机（MSVC，无 clang）只能用 in-process harness 累计（§1）；**文档化的完成路径**：

1. **首选（clang 主机，corpus 进化）**：在 Linux + nightly + clang 主机上，对 9 个 crate 的 17 个 cargo-fuzz target 运行 `cargo +nightly fuzz run <target>`（`crates/<format>/fuzz/` 下：8 × `parse` + 8 × `operations` + protocol `decode`；wrapper 直接复用同一 `fuzz_logic` 单源）。corpus 种子已提交（`fuzz/corpus/<target>/`），首次构建生成的 `fuzz/Cargo.lock` 应一并提交（M8 证据规则：无种子运行不算证据）。每格式按 §3 协议把运行时长追加进本账本。
2. **备选（本机继续）**：重复 §4 协议继续 in-process 波次；注意确定性口径（§3.3）——只有代码变化后的波次提供新探索。
3. **每格式 72 CPU-hours 门槛**：按格式家族汇总其 parse+ops（protocol 单独）target 的累计 CPU-hours，达到 72 且零未解释问题（§15.3）才算关闭该格式；本会话累计见 §8。

## 8. 本会话累计与剩余（诚实陈述）

**本会话（2026-08-07，session 7-8）真实累计：10.798 CPU-hours**（38,872.2 真实 CPU 秒，1547 次进程运行全部 exit 0，4.186 亿次变异；waves.log/runs.csv 为原始记录）。

- 每格式累计（CPU-hours）：json **1.331** / toml **0.789** / yaml **1.720** / ini **1.737** / properties **2.035** / xml **0.482** / plist **0.661** / hcl **1.337** / protocol（单 target）**0.706**。
- 相对每格式 72 CPU-hours 门槛（§15.3，按格式家族），本会话最接近的 properties 也仅 2.8%；**72h 门槛未完成**，剩余部分按 §7 完成路径累计（clang 主机 cargo-fuzz 为主，本机协议续跑为备选）。
- **确定性口径（重复声明）**：本机 in-process 波次在相同代码状态下覆盖相同的确定性变异计划（§3.3）；本会话期间修复 agent 多次落地（§5），因此波次覆盖了多个代码快照；会话内所有运行的真实时长均已入账，未测到/观测失败的运行记 0 或未入账（§3.1 时间线如实记录）。
- **corpus regressions**：本会话无新发现，`conformance/corpora/mutation-v1.json` 的 `regressions` 数组未新增条目（保持空）。
- **workspace 门禁**：`cargo test --workspace --locked` 于会话末尾对当前工作树运行，**1617 passed / 0 failed，exit 0 全绿**（完整日志 `docs/fuzz-evidence-0.13.0-logs/workspace-gate-2026-08-07.log`；修复 agent 的 M2-F1/M2-F2 严格断言随其工作树状态通过）。
- **corpus 全绿**：`cargo test -p consema-conformance --test mutation_corpus --locked -- --ignored` 全量 175k case replay 通过（63.10s，2026-08-07 15:49）。
- 剩余工作：每格式累计至 72 CPU-hours 且零未解释问题；M2-F1/M2-F2 修复提交（工作树状态）后复核 trip-wire/严格断言继续全绿。

## 9. 开放事项

- `crates/consema-conformance/examples/gen_mutation_corpus.rs:623` 硬编码 `"regressions": []`——M2 后续需改为保留 regressions 数组，否则 `--check` 与手工 regressions 条目冲突（本文档 §4 工作流不受影响，replay 测试已覆盖 regressions）。
- M2-F1/M2-F2 修复的工作树状态→提交、以及修复 agent 收口后的复核（§8 记录本会话末尾的 workspace 门禁结果）。
- session 7 的 wall_s 是"launch→波次结束"（该会话脚本尚未记录进程自身退出时刻；cpu_s 均为真实测量），session 8 起 wall_s 为进程自身存活时长——两段口径已在 runs.csv 中如实区分（§3.1 时间线）。
