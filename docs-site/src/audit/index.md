# 审计与证据

审计、门禁证据与发布候选记录。为保持审计链完整性，本目录**不复制**这些文档——统一以链接指向规范仓原文（权威载体）：

## 终审与候选

- [五要素终审（§28 收口记录，`1.0.0` 前哨）](https://github.com/consema/consema/blob/main/docs/five-element-review-1.0.0.md)：`docs/five-element-review-1.0.0.md`（2026-08-10，0.13.0–0.19.0 全周期累计审计证据的最终状态核验）
- [`1.0.0-rc.1` 候选清单（0.19.0 G5.7）](https://github.com/consema/consema/blob/main/docs/rc-1.0.0-candidate.md)：`docs/rc-1.0.0-candidate.md`（阻塞项清单 C-1/C-2/C-3、§22 门禁核对表、RC soak 计划、P2 发布判停清单）

## 门禁与证据

- [fc-manifest-0.13.0.json](https://github.com/consema/consema/blob/main/docs/fc-manifest-0.13.0.json)：0.13.0 Feature-Complete Gate 记录（含 conformance 聚合 digest 与各门禁条目证据）
- [fuzz-evidence-0.13.0.md](https://github.com/consema/consema/blob/main/docs/fuzz-evidence-0.13.0.md) 与 `docs/fuzz-evidence-0.13.0-logs/`：fuzz 证据（含原始日志；runs.csv 为追加式账本（只 append 从不改写）——账本目录副本为拆分时点快照 + 2026-08-13 追加变更（8f1ffa2，CONSEMA_GIT_EXE override，+13 行），非冻结原版；驱动已暂停（2026-08-13 11:19 后未重启））
- [0.13.0-gate-plan.md](https://github.com/consema/consema/blob/main/docs/0.13.0-gate-plan.md)、[API-REVIEW-0.13.0.md](https://github.com/consema/consema/blob/main/docs/API-REVIEW-0.13.0.md)、[COVERAGE-0.13.0.md](https://github.com/consema/consema/blob/main/docs/COVERAGE-0.13.0.md)
- 基准：BENCHMARKS-0.6.0 … 0.13.0（[docs/ 目录](https://github.com/consema/consema/tree/main/docs)）
- RC soak 五本：rc-soak-stage1-benchmarks / corpus / differential / disk-drill / go-fuzz（[docs/ 目录](https://github.com/consema/consema/tree/main/docs)）
- 发布记录与 SBOM：`docs/release/`（[目录](https://github.com/consema/consema/tree/main/docs/release)）
- 上游格式 gate 与差分 oracle 脚本：[scripts/](https://github.com/consema/consema/tree/main/scripts)

## Conformance 仲裁层

conformance 数据（vectors / fixtures / corpora / oracles / differential）是五仓共享的单一语言无关权威，维护在规范仓 `conformance/`：[目录](https://github.com/consema/consema/tree/main/conformance)。18 套 suite / 519 cases，聚合 digest `cfd6e296…`（详见 README "Conformance 权威声明"）。

> **发布视图**：本目录不复制审计文档，全部链接指向规范仓原文。
