# Consema 组织级发布纪律（六仓发布总纲）

本文件是 Consema 六仓（`consema` / `consema-rs` / `consema-go` /
`consema-ts` / `consema-py` / `consema-kt`）的发布总纲。每个语言仓根目录
各有 `RELEASING.md` 描述本仓发布细节；本文件规定跨仓同步纪律与检查单。

## 1. 版本与 tag 规范

- **tag 规范**：`vX.Y.Z`（语义化版本；预发布用 `v1.0.0-rc.N`、canary 等
  后缀）。所有仓共用同一 tag 前缀与同一次发布。
- **五语言版本同步发布**（2026-08-13 决策，five-language-ci-design.md
  §10 版本政策）：当前五个语言仓全部为 `1.0.0-rc.1`（ts/py 自 `0.14.0`
  推进统一）；各仓 CI `check-version-consistency` 门禁各自守护（manifest
  与 README `Version:` 行一致）；**1.0.0 首发时**按同版本五仓齐发执行。
- **版本 bump 纪律**：改版本必须同步改本仓 README 的版本行，否则
  `check-version-consistency` 门禁失败——这是有意的护栏。

## 2. CHANGELOG 策展

- 跨语言/规范变更记录在根 `CHANGELOG.md`（策展式：按里程碑组织，
  记录用户可见行为与契约变化，不收录内部重构流水账）。
  （`docs/CHANGELOG.md` 仅为勘误页，主记录以根 `CHANGELOG.md` 为权威。）
- 各语言仓的 CHANGELOG（如有）记录该语言实现细节；发布时两者都更新。

## 3. 发布检查单（每次发布执行）

1. [ ] 六仓 main 分支 CI `check (all gates green)` 全绿（含各仓
       conformance + differential 门禁；fuzz 驱动账本在 consema 仓，
       发布前确认无未处置回归）。
2. [ ] 版本 bump 完成且各仓 `check-version-consistency` 通过。
3. [ ] 根 `CHANGELOG.md` 策展完成。
4. [ ] 供应链要素就绪：签名/SBOM/checksum/干净重建演练
       （`docs/release-process-0.13.0.md`——Rust 侧 14 个 `.crate` 归档
       的 checksum + 签名 + SBOM；发布记录按该文件执行）。
5. [ ] 凭证就绪（见 §4 用户侧清单；Maven Central 凭证专人）。
6. [ ] 依次推送各仓 `vX.Y.Z` tag（发布由各仓 release workflow 自动执行；
       **不要手动执行发布命令**，处置失败除外）。
7. [ ] 发布后核对：crates.io（14 crate）/ npm / PyPI / Maven Central /
       Go proxy 各版本可见；GitHub Releases 存在。
8. [ ] 版本同步决策记录：本次是否五仓齐发，写入 CHANGELOG 与决策记录。

## 4. 各仓发布机制与用户侧凭证清单

| 仓 | 通道 | 触发 | 机制 | 用户侧凭证动作 |
|---|---|---|---|---|
| consema-rs | crates.io（14 crate） | tag v* | trusted publishing (OIDC, 2025-07 GA) 主路径 + `CARGO_REGISTRY_TOKEN` fallback；14 crate 按依赖序逐个 `cargo publish --locked` | 首次发布手动一次；之后每个 crate 在 crates.io 配置 Trusted Publishers（repo `consema/consema-rs`，workflow `release.yml`） |
| consema-ts | npm（`@consema/consema`） | tag v* | `npm publish --provenance`（id-token: write）+ `NPM_TOKEN` | npm 生成 publish token → GitHub secret `NPM_TOKEN`；canary（zod 模式）P2 |
| consema-py | PyPI（`consema`） | tag v* | trusted publishing (OIDC) 标准做法，无密码 | PyPI 项目设置 → Publishing → 添加 GitHub publisher（consema/consema-py，workflow `release.yml`） |
| consema-kt | Maven Central（`dev.consema:consema-kotlin`） | tag v* | `gradle publish`（Central Portal deploy 端点）+ PGP 签名 | Sonatype Portal 认领 `dev.consema` namespace + deploy token → secrets `OSSRH_USERNAME`/`OSSRH_PASSWORD`；PGP 密钥 → secrets `SIGNING_KEY`/`SIGNING_PASSWORD`；凭证专人 |
| consema-go | Go proxy（`consema.dev/consema`）+ GitHub Release | tag v* | tag 即发布；workflow 重跑门禁 + `action-gh-release` 建 Release | 无凭证；注意 tag 不可变（proxy 收录后不可删改）；goreleaser P2 |
| consema（规范仓） | 无 registry 发布 | — | 发布纪律载体 | — |

## 5. 参考

- 本仓：`docs/release-process-0.13.0.md`（发布供应链：签名/SBOM/checksum/
  干净重建演练）；`docs/multi-language-implementation-plan.md`（语言实现
  规划）；各语言仓根 `RELEASING.md`（本仓发布细节）。
