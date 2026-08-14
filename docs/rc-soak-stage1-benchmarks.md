# RC soak 阶段 1 — 性能复测流程

- 依据：`docs/BENCHMARKS-0.13.0.md`（性能与内存预算冻结：§8 回归政策、
  §9 批准记录模板、§10 可复现命令、§11 -Check 模式、§12 诚实覆盖声明）；
  `docs/rc-1.0.0-candidate.md` §4 阶段 1（"性能基线复测（BENCHMARKS 复验，
  无 >10% 回退）"）与 §4.1（Go 侧 2026-08-10 已执行、Rust 侧 -Check 建议
  **fuzz 关账后空闲环境执行**，避免 ~40% CPU 负载假阳性 fail）。
- 范围：Rust 侧 -Check 复验（预算门禁）+ Go 侧基准趋势记录（无冻结预算，
  仅趋势）。
- **本手册只含执行步骤与记录模板；复测本身不在本准备批次内（fuzz 关账后执行）。**

## 1. 环境要求（必须先满足）

| 项 | 要求 | 说明 |
|---|---|---|
| 空闲环境 | **fuzz 驱动关账后**执行（本机 24/7 连续 wrapper 占用 CPU，~40% 负载会造成假阳性 fail；rc-candidate §4.1 明示） | C-2 关账（每格式 72 CPU-hours 全闭）后驱动停止即可复测；若只停驱动不停其他负载，记录负载状态 |
| 机器与工具链 | 钉版环境：Windows 11 Pro 10.0.26200，i9-13900HX（32 逻辑核），Rust stable 1.97.1，`--release` profile（BENCHMARKS-0.13.0.md §1） | **比较只在钉版环境算数**（§8 item 3b）；异机/异工具链结果单独报告、不并入比较 |
| 工作区 | `consema-rs` 检出（六仓拆分后 workspace 移至仓根；BENCHMARKS §10 命令在 consema-rs 执行） | 与 §3 中 verify 脚本的 `-RustWorkspace` 同一检出 |
| 语料 | 母仓/consema-rs `conformance/fixtures/` + §10.3 场景语料生成命令（确定性，digest 钉版） | 语料被篡改/缺失时闭包断言先行失败（§2） |

## 2. Rust 侧 -Check 复验（BENCHMARKS-0.13.0.md §11）

### 2.1 SDK 行（§10.1，15 samples/行，迭代数 20000/5000）

在 `consema-rs` 检出执行：

```text
cargo build --release --locked -p consema-conformance --examples
cargo run --locked --offline --release -p consema-conformance --example json_family_baseline -- 20000
cargo run --locked --offline --release -p consema-conformance --example line_formats_baseline -- 20000
cargo run --locked --offline --release -p consema-conformance --example yaml_baseline -- 20000
cargo run --locked --offline --release -p consema-conformance --example xml_baseline -- 5000
cargo run --locked --offline --release -p consema-conformance --example plist_baseline -- 5000
cargo run --locked --offline --release -p consema-conformance --example hcl_baseline -- 5000
```

- harness 以闭包断言结尾（字节精确 render、`MaterializationFidelity::Exact`），
  语料损坏在取数前即失败。
- 对照 §4 冻结表（p50/p95 ns/op、peak MiB）。

### 2.2 CLI 行（§10.2 逐调用 harness，N=200；plan N=50、apply N=20）

- 构建：`cargo build --release --locked -p consema`（consema-rs）。
- 逐调用墙钟 harness 代码照 §10.2（ProcessStartInfo + 5ms peak working set 轮询，
  每次调用校验 exit 0）；请求记录文件（`cli.request@1` / `cli.edit-request@1` /
  `cli.convert-request@1`）形状与钉版 digest 照 §10.2 末段；批量语料 = 100 份
  `ini/desktop-settings.ini` 字节相同副本（每次 apply 前重新生成）。
- 命令清单照 §10.2 的 28 行（inspect ×13、query ×3、materialize ×4、conformance、
  plan、apply、convert C1-C5 ×5；S1-S4 场景行为 SDK 行，不在 CLI 清单内）；
  场景行迭代数：S3 N=30、S4 N=1、C1-C5 N=30（§11/§12）。
- 预计全量 -Check ~25-30 分钟（§11）。

### 2.3 通过/失败判定（§11 + §8 item 3）

- **Pass（每行）**：measured p50 ≤ frozen p50 AND measured p95 ≤ frozen p95
  AND measured peak ≤ frozen peak，且全部 ≤ 1.10 × 上一冻结基线
  （0.14.0 起"上一基线"= BENCHMARKS-0.13.0.md 本身）。
- **Fail**：任一行违例 → 脚本/手工 diff 报告（行、冻结值、测得值、delta %）→
  release gate 保持打开，直至 §9 模板的批准记录存在
  （`docs/APPROVALS-0.13.0.md`，APPR-0001 起；该文件现不存在，首次触发时创建）。
- 批准记录流程（§8 item 4）：(i) 重跑 -Check 确认（原始样本即证据）；
  (ii) gatekeeper 根因分析（"environment drift" / "not yet located, re-check plan"
  为允许结论，须文档化）；(iii) 每条回退一张记录；(iv) 处置 = 批准/拒绝/延后；
  (v) 记录公开（引用进 CHANGELOG）。
- **禁止 benchmark gaming**（§8 item 6）：关闭诊断/无损覆盖/limits 的配置本身即违例。

## 3. Go 侧基准趋势记录（consema-go/go/README.md 的「Benchmark baseline (0.19.0 G5.4)」节）

- 定位：`consema-go/go/README.md` "## Benchmark baseline (0.19.0 G5.4)"。
- 命令（在 `consema-go` 检出）：

```text
cd go
go test -bench=. -benchtime=1s ./json/ ./toml/ ./yaml/ ./ini/ ./properties/ ./xml/ ./plist/ ./hcl/
```

- **无冻结预算**（go/README.md「Benchmark baseline (0.19.0 G5.4)」节"no
  frozen budget; that is a Rust-side discipline"句）——Go 侧只有趋势记录，不触发 §8 门禁；**>10% 回退的判定惯例**
  （2026-08-10 首跑先例）：比值 >1.10 标注"疑似回退（负载状态，需空闲复测确认）"，
  无代码回退结论须附依据（同会话其它项更快/无代码改动/GC 争抢特征）。
- 记录：8 家族 × {BenchmarkParse, BenchmarkRender}（µs/op + MB/s）。

## 4. 结果记录模板

### 4.1 Rust -Check

```markdown
## RC soak 阶段 1 — Rust -Check 复验记录（YYYY-MM-DD）

- 环境：Windows 11 10.0.26200 / i9-13900HX；Rust <ver>；consema-rs HEAD <commit>；
  空闲状态：fuzz 驱动已关账（C-2 关闭时间 <…>），其他后台负载 <…>
- 执行：§2.1 SDK 6 harness（15 samples）+ §2.2 CLI 行（N=200/S3=30/S4=1/C1-C5=30/
  plan=50/apply=20）；总墙钟 <…> 分钟
- 结果：<逐行对照表：行 / 冻结 p50,p95,peak / 测得 p50,p95,peak / delta % / pass>
  （原始样本输出：<路径/行区间>）
- 违例：<无，或逐条：行 + 偏差 + 触发类型（over-budget | 10% regression）+ 批准记录号>
- 结论：<全行 pass；或按 §8 item 4 流程处置后的结论>
```

### 4.2 Go 趋势

```markdown
## RC soak 阶段 1 — Go 基准趋势记录（YYYY-MM-DD）

- 环境：<OS/机器>；go <ver>；consema-go HEAD <commit>；负载状态：<fuzz 驱动/空闲>
- 命令：cd go && go test -bench=. -benchtime=1s ./json/ ./toml/ ./yaml/ ./ini/ ./properties/ ./xml/ ./plist/ ./hcl/
- 结果：<8 家族 × BenchmarkParse/BenchmarkRender 表：本次值 vs 2026-08-10 基线值 + 比值>
- >1.10 项：<逐条标注；无冻结预算，仅趋势；负载状态影响如实标注>
- 结论：<趋势记录；无代码回退判断（或说明依据）>
```

诚实记录体例：所有数字来自本次实际运行；与 2026-08-10 基线/冻结值的比较必须
同环境同方法（§8 item 1：同一语料、操作定义、release profile、迭代数、
百分位方法）；负载状态如实记录，不做"环境漂移"的静默归因。

## 5. 相关文件

- `docs/BENCHMARKS-0.13.0.md`（冻结预算、§8-§12 机制；本手册的唯一数字来源）
- `docs/rc-1.0.0-candidate.md` §4/§4.1（soak 计划、Go 首跑记录、fuzz 关账建议）
- `consema-go/go/README.md`「Benchmark baseline (0.19.0 G5.4)」节（Go 基准命令与 2026-08-10 记录）
- `docs/APPROVALS-0.13.0.md`（触发时创建，§9 模板）
