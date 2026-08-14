# Contributing to Consema（规范仓）

欢迎为 Consema 贡献。Consema 是配置格式统一处理库：对 JSON/JSONC/JSON5、
TOML、YAML、INI、Java Properties、XML、Property List 与 HCL 八个格式家族
提供无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑，
默认拒绝未经授权的转换、截断或信息损失。规范与设计语言无关，由五个独立实现
（Rust、Go、TypeScript、Python、Kotlin）共同证明。

本仓是**规范 / RFC / 路线图 / 审计证据 / conformance 仲裁层**：语言无关权威
（`conformance/vectors`、`fixtures`、`oracles`、`differential`）在此维护，
五仓共享。

## 六仓导航

| 仓库 | 角色 |
| --- | --- |
| [consema](https://github.com/consema/consema)（本仓） | 规范 / RFC / 路线图 / 审计证据 / conformance 仲裁层 |
| [consema-rs](https://github.com/consema/consema-rs) | Rust 参考实现 |
| [consema-go](https://github.com/consema/consema-go) | Go 实现 |
| [consema-ts](https://github.com/consema/consema-ts) | TypeScript 实现 |
| [consema-py](https://github.com/consema/consema-py) | Python 实现 |
| [consema-kt](https://github.com/consema/consema-kt) | Kotlin 实现 |

本仓主要接收规范文档、RFC、conformance 数据与审计证据的变更；语言实现
（代码 / 测试 / 差分脚本）的贡献请到对应语言仓。

## 如何报 Bug

提交前请完成预检（`.github/ISSUE_TEMPLATE/bug_report.yml` 会逐项确认）：

- [ ] 搜索过现有 issue 与 PR，确认没有重复；
- [ ] 已阅读相关文档（README、RFC、SECURITY.md、对应语言仓文档）；
- [ ] 确认这是 Consema 自身的问题，而非上游格式工具或环境问题；
- [ ] 已尝试构造最小复现。

报告要求：

- **最小复现**：最小输入 + 明确调用方式（API 或 CLI）；规范层问题请注明
  涉及的 capability contract（如 `core.source-snapshot@1`）。
- **环境信息**：`conformance/vectors/` 聚合 digest（见
  `docs/fc-manifest-0.13.0.json`）、本仓版本 / git rev / tag、OS 与平台。
- **安全漏洞不要公开提交 issue**：走 `SECURITY.md` 的披露渠道（GitHub
  Security Advisory 与维护者邮箱；见该文件），发现 panic、无界分配或规范
  绕过时同样走该渠道。

## 如何提 Feature

- 新能力 / 行为变更建议：用 feature 模板开 issue
  （`.github/ISSUE_TEMPLATE/feature_request.yml`），描述问题、动机、方案与备选。
- **契约变更必须走 RFC**：涉及 contract / Profile / 语义 / 兼容性 / 已冻结
  registry（v1-v6）的行为变更，按 `docs/rfcs/` 流程起草 RFC（编号接续现行
  0020），并遵守 [RFC 0020 兼容与支持政策](docs/rfcs/0020-compatibility-and-support-policy-v1.md)；
  未走 RFC 的契约变更不会直接以 PR 形式进入规范文档。
- 纯实现 / 工具 / 文档改进不需要 RFC，直接走 PR。

## 开发工作流

1. **Fork** 本仓（或使用组织内分支），从 `main` 切出特性分支
   （`feature/…`、`fix/…`、`docs/…`）。
2. **提交规范**：
   - 首行 `模块: 摘要`，≤50 字符（如 `docs: 补充 RFC 0021 正文`）；
   - 关联 issue 写 `Fixes: #123`；
   - 原子提交：一个逻辑变更一个提交，不混入无关改动。
3. **本地验证**：本仓 CI 只跑本仓拥有的门禁（oracles + shared-conformance-
   digest + check 聚合门禁）；改动脚本 / conformance 数据后至少本地跑相关
   脚本（见 README「验证」节：`scripts/` 下 toml-test、yaml-test-suite、
   runtime oracle、差分 oracle——注意 toml-test/yaml-test-suite 脚本只存在
   于母仓 scripts/ 且母仓根无 Cargo.toml 原位不可执行，保留为记录载体，可
   执行入口的迁移/重建待总指挥决策，2026-08-14 波 2 处置）。**`conformance/vectors/`
   变更是五仓同步事件**：必须同步五个语言仓并更新聚合 digest 与 18/519
   计数（聚合 digest
   `cfd6e296da5b22b62d37b076d35bf6bbf58b0678ceddb37eea51a8b47200ab6a`，见
   README「Conformance 权威声明」），否则仅 consema-go 仓（live HEAD 跟随）
   conformance 门禁与 digest 断言失败（consema-ts/consema-kt/consema-py 钉定
   commit ad667021、consema-rs 为 vendored 快照，均不自动跟随）。
4. **PR**：标题遵循提交规范；确保 CI 全绿（含 pr-labels.yml 的 kind 标签
   门禁）。
5. **评审**：至少一位维护者 approve；契约变更需在 PR 中记录 RFC 关联。

## 评审规范

- 契约 / 语义变更无 RFC 关联，打回补充；
- `conformance/vectors/` 变更未同步五仓、未更新聚合 digest 与计数，打回（跟随型失败面为 go 仓 live HEAD；ts/kt/py 钉定 commit 与 consema-rs vendored 快照需显式同步）；
- 不允许用截断、降级测试或错误完成状态"修复"问题——资源上限与完成状态
  语义是安全边界（SECURITY.md），不因评审压力放松；
- 版本一致性：改版本必须同步改 README 版本行（各语言仓有
  `check-version-consistency` 门禁）；
- 供应链 / 发布相关变更遵守 RELEASING.md 与 `docs/release-process-0.13.0.md`。

## 标签体系

PR 必须携带至少一个 `kind:` 标签（`.github/workflows/pr-labels.yml` 强制）。
五个 kind 标签见 [.github/LABELS.md](.github/LABELS.md)：

| 标签 | 含义 |
| --- | --- |
| `kind: bug` | 缺陷修复 |
| `kind: feature` | 新能力或行为变更 |
| `kind: docs` | 纯文档变更 |
| `kind: chore` | 工具链 / CI / 依赖 / 无行为变化的重构 |
| `kind: release` | 发布准备 / 版本 bump |

## 发布纪律

发布是六仓同步事件：版本 / tag / CHANGELOG / 供应链要素（签名、SBOM、
checksum、干净重建演练）统一遵守 [RELEASING.md](RELEASING.md)（六仓发布总纲）
与本仓 `docs/release-process-0.13.0.md`。发布由各仓 release workflow 自动
执行，不要手动执行发布命令。

## 行为准则

所有参与 Consema 社区（本仓与五个语言仓）的成员、贡献者与维护者须遵守
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)（Contributor Covenant 2.1）。
