# Consema 支持政策（Support Policy）

- 版本：0.1（草案，0.13.0 门禁 M6 交付；`1.0.0` 发布前必须公开，路线图
  §21.4 第 1851 行）
- 适用范围：Rust SDK（`consema` facade 及全部 backend crates）、Rust CLI、
  `0.14.0` 起的 Go SDK / Go CLI（§21.2）
- 权威来源：路线图 §12（版本治理）、§21.3（稳定承诺）、§21.4（支持周期）、
  §19.4（发布供应链）、§18.4（缺陷等级）；RFC 0015 §5.3（exit code 冻结）；
  `SECURITY.md`（资源与安全行为）
- 本政策回答 §21.4 的七个必公开项 + 工具链冻结时机（§21.4 末段），并落实
  §12.2 的"旧契约停止支持必须遵循公开生命周期政策"。

## 1. Rust MSRV 窗口

现状与门禁事实：

- workspace `rust-version = "1.85"`（`Cargo.toml:33`），edition 2024；
  `unsafe_code = "forbid"`（`Cargo.toml:37`）。
- CI 常设 `msrv` job 在 1.85.0 上运行与 stable 相同的全部测试矩阵
  （`docs/0.13.0-gate-plan.md` M1；.github/workflows/ci.yml）；发布门禁同时
  在 current stable 与 MSRV 上通过 `--all-targets --all-features` 构建
  （CHANGELOG.md:33：Rust 1.97.1 与 MSRV 1.85.0 双腿）。

政策：

- **MSRV 声明**：每个发布在 manifest 声明精确 `rust-version`；"1.85"是当前
  声明值，不是多年承诺（§21.4 末段：具体工具链版本在 Rust Feature-Complete
  与 Go RC 时按当时稳定生态冻结）。
- **支持窗口**：从 MSRV 到当前 stable 的所有 Rust 版本。MSRV 提升只在
  minor 版本发生（§12.1 破坏性变更规则），**永不进入 patch release**
  （§21.1 第 1820 行）；提升必须走 manifest 变更记录（§12 版本治理），并
  在 CHANGELOG 注明用户可停留的最低版本。
- **验证**：CI msrv job 是唯一权威（本地 `cargo +1.85.0` 只作复验）；任何
  使用高于 MSRV 语法的代码（如 let-chains）在合入前必须被 msrv job 拦截
  （gate-plan §4 M1 验证记录已实测拦截行为）。
- **示例**：当前发布基线 = MSRV 1.85（0.8.0 起声明）+ 验证工具链
  Rust 1.97.1（CHANGELOG.md:30）。

## 2. Go version window

Go 实现从 `0.14.0` 开始（§14.12 第 1345 行）。`go.mod` 声明的最低版本
`go 1.26` 已于 0.14.0 冻结（RFC 0016 §9 / go-implementation-plan §1.3；
RFC 0020 §9.2 的调和表述：声明最低版本在 0.14.0 冻结，最低版本+验证工具链的
正式冻结在 Go RC 时按当时 Go 稳定生态完成，见 RFC 0020）；不在本政策预先
写死未来的版本号。占位承诺（§21.2）：

- 每个 Go minor 发布同时支持当时最新的两个 Go minor 版本；
- `go.mod` 声明最低版本并在 CI 验证（§21.2）；
- 最低版本提升遵循 §12.1 的 minor-only 规则与 §1 的 MSRV 同纪律
  （破坏性变更在 minor，不重解释已发布 contract）。

## 3. 支持环境（OS / 架构）

正式支持矩阵（CI 常设验证，`docs/0.13.0-gate-plan.md` M1 与 §8
`supported_targets`）：

| 目标 | 架构 | 验证 |
|---|---|---|
| Windows（Windows 11 Pro 10.0.26200 实测基线） | x86-64 | CI windows-latest 全测试矩阵 |
| Linux | x86-64 | CI ubuntu-latest 全测试矩阵 |
| macOS | x86-64 / arm64 | CI macos-latest 全测试矩阵 |

- 其余平台/架构为 best-effort：不阻断发布，但任何已接受的关键修复都会
  在声明支持的三平台上验证。
- 发布物验证基线记录在 `scripts/verify-package-archives.ps1`（路径安全、
  校验和、解包内容、MSRV 腿）。
- CLI 平台相关行为（Windows read-only/ACL、POSIX 权限、symlink policy、
  临时文件权限）在正式目标上逐平台验证（RFC 0015 §9.6 与 CHANGELOG.md:34
  的跨平台边界；0.13.0 收口 Linux/macOS 全量验证）。

## 4. 安全修复政策

缺陷等级沿用路线图 §18.4：

```text
P0  数据破坏、静默损失、RCE/外部访问、错误写文件、跨快照误编辑
P1  panic/crash/hang、错误完成状态、明显语义不一致、limit bypass
P2  有安全替代路径的功能缺陷、非核心性能回退、诊断位置错误
P3  文档、易用性、非稳定 message 或低风险边角问题
```

- **P0/P1**：阻塞当前里程碑（`1.0.0` 不允许未解决 P0/P1，§18.4）；修复
  以最快路径进入 patch（0.x.y 或稳定后 patch），并永久加入 regression
  corpus（§15.3 fuzz 回归体例；发现即入 `conformance/corpora/`）。
- **P2**：逐项公开评审与发布判断记录（不笼统归入 known issues，§18.4）；
  修复进下一个 minor，高危 P2 可经评审进入 patch。
- **无未接受 critical/high 依赖漏洞**：RustSec `cargo audit`（本地 1,189
  advisory / 0 漏洞，2026-08-07）与 `cargo deny check` 四段为常设门禁
  （SECURITY.md:38）；上游公告跟踪属于 §19.3 依赖政策。
- **resource limit 与截断**：任何 limit 失败不伪装成功（SECURITY.md:3-14），
  修复不得引入截断假成功。
- **披露流程**：安全缺陷先于公开经私有渠道披露；`1.0.0` 前在仓库
  `SECURITY.md` 冻结披露联系邮箱与 PGP key（§19.4 第 1764 行要求
  "安全披露联系方式和支持周期"，本文件为其落点；0.13.0 M7 收口）。披露
  时间表：确认后 90 天内发布修复（critical/high），或公开说明处置状态。

## 5. 版本与分支支持周期

产品版本规则（§12.1、§21.3）：

- **patch**（0.x.y / 1.0.x）：bug/security fix，不改变公共 API、已定义
  行为或已发布 contract；MSRV 提升永不进入 patch（§21.1 第 1820 行）。
- **minor**（0.x.0 / 1.x.0）：向后兼容的新能力、新 Profile 或新 contract；
  `0.x` 阶段 minor 允许破坏性变更，但必须满足 §12.1 五条（出现在 minor、
  有迁移说明、不重解释 `namespace.contract@N`、更新 conformance、同步列出
  Rust API/protocol/CLI schema 影响）。
- **major**（1.0.0 之后）：不可避免的破坏性公共变更。

分支支持周期（`1.0.0` 起生效；0.x 阶段只维护最新 minor，历史 minor 的
缺陷按 §7 退役规则处理）：

- 最新 minor 分支：完全支持（bug + security + docs）；
- **previous minor 分支：支持期 = 自新 minor 发布起 12 个月**，期间只接受
  security fix 与 P0/P1 修复，之后进入仅安全公告状态（再 6 个月）；
- 超过该窗口的分支：EOL，不再发布修复；CHANGELOG 与 release notes 注明
  各 minor 的 EOL 日期。

## 6. 弃用政策（deprecation）

- **弃用通告期**：任何公共 API、Profile、contract 或 CLI 行为的弃用，先
  在一个 minor 中标记 `deprecated`（CHANGELOG 弃用段 + rustdoc/文档标注），
  **至少一个完整 minor 后**才在下一个 minor/major 移除。
- **弃用不是破坏**：弃用期间行为与机器输出完全不变（诊断可新增
  `deprecation` 提示，但不改变 exit code、code 或 payload 字段）；
- 移除时遵守 §12.1 五条（0.x）或 §21.3 major 规则（稳定后），并给出等价
  替代路径（migration guide 体例，`docs/migration-guide.md`）。

## 7. contract / Profile 退役流程

- **已发布 `namespace.contract@N` 永不重解释**（§21.3 第 1843 行、
  §12.2）：冻结的 registry 数组与 constructor 精确不变
  （IMPLEMENTATION.md 第 12 章：v1-v6 冻结、v7 增量为 additive）。
- **新版本 = 新 identity**：能力演进发布新 contract/version pair
  （如 `core.materialization-request@2`、`json.lossless-syntax-query@2`），
  旧版本保留为冻结 identity；product 版本可以同时支持多个 contract
  version（§12.2 示例）。
- **退役（retirement）**：某 contract/Profile 停止在默认能力面发布时：
  1. 一个 minor 的弃用通告（第 6 节）；
  2. 退役记录写明原因、替代 contract ID、最后支持的产品版本；
  3. 退役不删除注册记录与 typed decoder 的解析路径（历史数据可审计）；
  4. `consema capabilities` 输出按退役状态标注，但格式家族与 Profile 的
     parse 兼容性边界属于 Profile 兼容性（§21.3 第 1847 行），不在退役时
     悄悄改变 acceptance/recovery 行为。
- **error code 永不重定义**：RFC 0015 §5.3 冻结 exit code 分类
  {0..5} 与每 code 含义；任何新增/重定义必须走新 RFC 或新 contract
  version（gate-plan §1.6 与 RFC 0015 §5.3 同文）。
- 本流程由 0.13.0 Feature-Complete Manifest 收口时登记为首个被执行对象
  （尚无退役案例；本文是政策，不是历史）。

## 8. 工具链冻结时机

§21.4 末段（第 1861 行）：具体工具链版本不在多年路线图中预先写死，而是在
**Rust Feature-Complete 与 Go RC** 两个时点按当时稳定生态冻结：

- Rust：Feature-Complete（0.13.0 门禁，§15）冻结 MSRV 与验证工具链；
  冻结记录进 `docs/fc-manifest-0.13.0.json`（`rust_compiler_msrv` 字段，
  gate-plan §8）。
- Go：Go RC 冻结最低版本与验证工具链（§21.2），记录进对应发布 manifest。
- 冻结之间的一切 MSRV/工具链变化按第 1、2 节政策执行。

## 9. 与既有门禁的对应

| 本政策条目 | 门禁/证据 |
|---|---|
| MSRV 1.85 | Cargo.toml:33；CI msrv job；CHANGELOG.md:33 |
| 三平台 | CI 矩阵（gate-plan M1）；BENCHMARKS-0.12.0.md Environment |
| 缺陷等级 P0-P3 | 路线图 §18.4；SECURITY.md:16 硬化套件 |
| audit/deny 常设 | SECURITY.md:38；gate-plan P-3/P-4 |
| contract 冻结 | IMPLEMENTATION.md 第 12 章；README.md:31-32 |
| exit code 冻结 | RFC 0015 §5.3；cookbook 第 11 节 |
| 发布供应链（含披露联系方式） | 路线图 §19.4；gate-plan M7 |

本政策的变更必须走 CHANGELOG；`1.0.0` 发布前由 0.13.0 门禁复核本文件与
实际发布物一致（§21.4 第 1851 行"必须公开"）。
