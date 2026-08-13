# RC soak 阶段 1 — 磁盘失败演练执行手册（演练 5 完成路径）

- 依据：`docs/rc-1.0.0-candidate.md` §3.5 演练 5（环境阻塞记录）与 §4 阶段 1
  （"磁盘失败演练：批量 apply 目标卷写满（临时小卷）→ 失败分类与恢复路径记录"）；
  §22.7 门禁行（"stale file、部分权限失败、进程中断、磁盘失败演练"）。
- 完成路径：C-1 已闭环（2026-08-11，run #5 132/132 全绿）→ Linux runner 临时小卷路径可用
  （rc-1.0.0-candidate.md §3.5 演练 5 末段：tmpfs/loop 临时小卷 → 真实填盘 → apply
  预期 exit 4 + `cli.write.io@1` per-file failed → 释放空间后同一 plan 重跑恢复）。
- 可执行载体：`scripts/rc-soak-disk-full.ps1`（Linux runner，tmpfs，一键执行）；
  Windows 变体 `scripts/rc-soak-disk-full-windows.ps1`（**需授权环境**：admin +
  Hyper-V 模块的 New-VHD/Mount-VHD 路径）。
- 本手册 = 演练前置条件、命令、预期断言、结果记录模板、诚实记录体例；
  **执行演练本身不在本准备批次内**（C-2 关账后一键执行）。

## 1. 目标与判定标准

- 目标：真实磁盘满（ENOSPC）条件下 `consema apply` 的**失败分类**与**恢复语义**证据。
  - 失败分类：exit 4（precondition 类，RFC 0015 §5.1 表：permission/disk failures
    列于 precondition；`cli.write.io@1` → 4，`consema-protocol/src/exit_class.rs:254,267`）；
    逐文件 failed 条目携带 `failure_code: cli.write.io@1`（诊断注册表 §13.1；
    `cli_plan_apply.rs` 注入 seam 实测同码，`consema-rs/consema/tests/cli_plan_apply.rs:616-624`）。
  - 恢复语义：释放空间后**同一 plan manifest** 重跑 apply → exit 0，全部 completed；
    证明批处理可恢复性 = manifest 状态机可重跑（RFC 0015 §10），与演练 4
    （部分权限失败）的结论并列：拒绝/失败是逐文件原子的、批处理无整体原子性，
    恢复靠 manifest 状态机。
- 通过 = 脚本全部断言成立（exit 4、≥1 条 `cli.write.io@1` failed、failed 文件
  零字节写入、无 `*.consema-*.tmp` 残留、恢复 apply exit 0 全 completed 且
  target digest 正确）+ 结果记录按 §4 模板入库。

## 2. 前置条件（执行前逐项核对）

| 项 | 要求 | 核对方式 |
|---|---|---|
| 运行环境 | Linux runner（GitHub Actions ubuntu 或等权自托管），root 或免密 sudo | `id -u` 或 `sudo -n true` |
| 工具链 | bash、coreutils（dd/df）、mount/umount、pwsh | `command -v bash dd df mount` |
| consema-rs 检出 | 六仓并排布局中的 `consema-rs` 检出（Cargo.toml 在根） | 脚本 `-RustWorkspace` 默认：优先并排检测（母仓同级 `consema-rs`，Cargo.toml 存在即用），否则回退嵌套假设 `<仓根>\consema-rs` 并在不存在时明确报错——并排布局下不传参也能解析 |
| 规范仓检出 | 母仓 conformance/（fixtures 单一权威） | 脚本 `-FixturesDir` 默认 `<仓根>\conformance\fixtures` |
| consema CLI | `consema-rs/target/release/consema`（Linux）；缺失时脚本自动 `cargo build --release --locked -p consema` | `-SkipBuild` 可禁止自动构建 |
| 夹具钉版 | `conformance/fixtures/ini/desktop-settings.ini` = 177 B，sha256 `b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8`（BENCHMARKS-0.13.0.md §3 钉版；脚本断言，不符即红） | 脚本内置 |
| 环境空闲 | fuzz 驱动关账后（本机 24/7 连续 wrapper 占用 CPU；演练与基准复测同需空闲环境，见 rc-soak-stage1-benchmarks.md） | 与 C-2 关账节奏对齐 |
| 临时空间 | 演练卷 ≤64 MiB（tmpfs 内存盘，无磁盘占用）+ plan/result manifest 在卷外 | 脚本处理 |

## 3. 命令清单（Linux runner）

```text
# 一键执行（默认：tmpfs 64 MiB 小卷、20 份 desktop-settings.ini 夹具、
# window:width→1600 编辑请求（cookbook.md §6）、填至 ≤48 KiB free）：
# 注：-RustWorkspace 默认已做并排布局检测（六仓并排检出即自动解析）；
# 非并排布局仍须显式传参。
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rc-soak-disk-full.ps1

# 常用参数：
#   -RustWorkspace <consema-rs 检出路径>    （默认 <仓根>\consema-rs）
#   -FixturesDir   <母仓 conformance\fixtures>（默认 <仓根>\conformance\fixtures）
#   -SizeMb 64 -Copies 20 -LeaveFreeKiB 48  （小卷尺寸/批次大小/剩余自由空间阈值）
#   -Keep                                      （保留工作目录与卷现场供检查）
#   -SkipBuild                                 （不自动构建 CLI）
```

脚本流程（每步带断言，输出即报告）：

| 步骤 | 操作 | 预期断言 |
|---|---|---|
| 1 | `mount -t tmpfs -o size=64M tmpfs <vol>`（root 或 sudo -n） | mount 成功 |
| 2 | 复制 `ini/desktop-settings.ini` ×20 进卷 | 夹具 sha256 == `b01f173b…` |
| 3 | `consema plan <20 文件> --profile ini.portable --request-file edit-request.json --output plan.json` | exit 0，20/20 planned；plan.json 在卷外 |
| 4 | `dd if=/dev/zero of=<vol>/fill.bin …` 直至 `df avail ≤ 48 KiB` | 真实 ENOSPC 条件成立（tmpfs 精确） |
| 5 | `consema apply plan.json --output result-fail.json` | **exit 4**；≥1 条 failed 且 `failure_code=cli.write.io@1`；failed 文件字节仍为 base digest；completed 文件为 target digest；无 `*.consema-*.tmp` 残留 |
| 6 | `rm <vol>/fill.bin` | 卷恢复可写 |
| 7 | `consema apply plan.json --output result-recover.json`（同一 plan） | **exit 0**；20/20 completed；全部 target sha256 == `98b89205…` |
| 8 | `umount <vol>`；清理工作目录（-Keep 时保留） | 清理无异常 |

预期 digest（cookbook.md §6 / 演练 4 实测，2026-08-10）：

- base：`b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8`
- target（window:width 1440→1600，preserve-compatible）：
  `98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a`

### 3.1 卷选择说明（诚实口径）

- 首选 tmpfs（`mount -t tmpfs -o size=64M`）：内存盘，尺寸精确、随时可弃、
  不影响 runner 磁盘；`df`/`dd` 均为真实文件系统语义（ENOSPC 来自真实写失败）。
- 备选 loop 文件（tmpfs 不可用时）：`truncate -s 64M disk.img && mkfs.ext4 disk.img
  && mount -o loop disk.img <vol>`——container 无 loop 设备时不可用，如实记录。
- **禁止**在 runner 主卷上填盘（演练 5 原阻塞即此：952.8 GB 主卷禁止填盘）；
  演练卷必须是可整体丢弃的临时小卷。

### 3.2 Windows 变体（需授权环境）

`scripts/rc-soak-disk-full-windows.ps1`：admin + Hyper-V 模块
（New-VHD/Mount-VHD/Format-Volume/Add-PartitionAccessPath/Dismount-VHD）。
前置条件不满足时**如实记录环境阻塞并 exit 3**（仓库 documented-skip 退出码惯例，
oracle 脚本先例），绝不伪造演练结果——照演练 5 原环境阻塞记录体例
（非 admin + 无 Hyper-V + 无可寻址小卷，2026-08-10）。流程与 Linux 版同构：
256 MiB 动态 VHD → 文件夹挂载点 → 同 plan/填盘/apply/恢复断言。

## 4. 结果记录模板（执行后回填 rc-1.0.0-candidate.md §3.5 演练 5 / §4.1）

```markdown
**演练 5：磁盘失败 — 已闭环（RC soak 阶段 1，YYYY-MM-DD）**

- 环境：Linux runner（<runner 名/规格>）；`consema-rs` HEAD <commit>；
  CLI `target/release/consema`（<版本>）；小卷 tmpfs 64 MiB。
- 素材：conformance/fixtures/ini/desktop-settings.ini ×20（base `b01f173b…`）；
  edit 请求 = cookbook §6 规范示例（ini.edit.replace-semantic-value@1，window:width→1600）。
- 步骤与结果：

| 步骤 | 操作 | 结果 |
|---|---|---|
| 1 | plan 20 文件 | exit 0，20/20 planned |
| 2 | 填卷至 avail ≤ <N> KiB | 真实 ENOSPC 条件 |
| 3 | apply plan.json | **exit 4**，<C>/<F> completed/failed，failed 全部 `cli.write.io@1`；stderr 原文：<…> |
| 4 | 字节核验 | failed 文件零字节写入（base digest）；completed 文件 target digest；无 *.tmp 残留 |
| 5 | 释放空间后同一 plan 重跑 | exit 0，20/20 completed（target `98b89205…`） |

- **失败分类**：exit 4 = precondition 类（RFC 0015 §5.1；`cli.write.io@1` → 4，
  exit_class.rs 实测）；per-file failed 作为 manifest 内容（envelope diagnostics: []）。
- **恢复语义**：同 plan 重跑即恢复（manifest 状态机可恢复性，RFC 0015 §10）；
  与演练 4 并列：逐文件原子、批处理无整体原子性。
- 结论：P2-6 的"磁盘失败演练未记录"缺口已闭（§22.7 四类演练全部闭环）。
```

诚实记录体例（照 release-process-0.13.0.md §6 与 rc-candidate §3.4/§3.5）：

1. 只写实际发生的输出与退出码；预期断言与实际不符时，记录实际值 + 偏差分析，
   不粉饰（例如 completed/failed 拆分因 tmpfs 页取整而随机器变化——如实记录实测拆分）。
2. 演练卷/工作目录为临时物，不入库；结果记录入库于 rc-candidate §3.5。
3. 任何异常（如 apply 未 exit 4）先按 RFC 0015 §5.2 复核分类，再判断是否为新发现。

## 5. 相关文件

- `scripts/rc-soak-disk-full.ps1`（Linux runner 可执行演练脚本）
- `scripts/rc-soak-disk-full-windows.ps1`（Windows 变体，需授权环境）
- `docs/rc-1.0.0-candidate.md` §3.5 演练 4/5、§4 阶段 1、§22.7
- `docs/release-process-0.13.0.md` §6（演练诚实记录体例）
- `docs/BENCHMARKS-0.13.0.md` §3（夹具钉版）、`docs/cookbook.md` §6（编辑请求示例）
- `consema-rs/consema/tests/cli_plan_apply.rs`（注入 seam 对照：`CONSEMA_APPLY_WRITE_FAILURE=io`
  同码 `cli.write.io@1` → exit 4，RFC 0015 §5.4）
