# Consema

![CI](https://img.shields.io/github/actions/workflow/status/consema/consema/ci.yml?branch=main)
![Version](https://img.shields.io/github/v/tag/consema/consema)
![License](https://img.shields.io/github/license/consema/consema)

Consema 是配置格式统一处理库：对 JSON/JSONC/JSON5、TOML、YAML、INI、Java Properties、XML、Property List 与 HCL 八个格式家族提供无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑，默认拒绝未经授权的转换、截断或信息损失。规范与设计语言无关，由五个独立实现（Rust、Go、TypeScript、Python、Kotlin）共同证明（2026-08-11 决策：五语言同等地位，见 `docs/multi-language-implementation-plan.md` 与 `docs/five-language-ci-design.md`）。

## 六仓结构

2026-08-12 起 Consema 拆分为六个仓库：本仓是规范 / conformance 仲裁层，五个语言实现各自成仓。

| 仓库 | 角色 |
| --- | --- |
| [consema](https://github.com/consema/consema)（本仓） | 规范 / RFC / 路线图 / 审计证据 / conformance 仲裁层（语言无关权威） |
| [consema-rs](https://github.com/consema/consema-rs) | Rust 参考实现 |
| [consema-go](https://github.com/consema/consema-go) | Go 实现 |
| [consema-ts](https://github.com/consema/consema-ts) | TypeScript 实现 |
| [consema-py](https://github.com/consema/consema-py) | Python 实现 |
| [consema-kt](https://github.com/consema/consema-kt) | Kotlin 实现 |

拆分决策与执行记录（对齐修复 → 差分集迁移 → subtree split → 五仓组装 → 母仓瘦身 → CI 修复链 → semver 门禁真空修正 → 驱动迁移）：[six-repo-split-2026-08-12.md](docs/six-repo-split-2026-08-12.md)。

## 本仓内容

**规范文档**（根目录，权威载体）：

- [配置内容统一处理标准与 Rust 参考实现.md](配置内容统一处理标准与%20Rust%20参考实现.md)：语义基线
- [Consema 1.0.0 产品路线图与双语言落地设计.md](Consema%201.0.0%20产品路线图与双语言落地设计.md)：1.0.0 路线图（语言无关门禁清单与落地设计）

**RFC**（`docs/rfcs/`）：语言无关规范的权威载体，RFC 0001-0016 全清单 + [RFC 0020 兼容与支持政策](docs/rfcs/0020-compatibility-and-support-policy-v1.md)。要点：[RFC 0015](docs/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md)（CLI 机器协议与 batch apply）。

**审计与门禁证据**（`docs/`）：

- [fc-manifest-0.13.0.json](docs/fc-manifest-0.13.0.json)：0.13.0 Feature-Complete Gate 记录（含 conformance 聚合 digest `35bebc8d…` 与各门禁条目证据）
- [five-element-review-1.0.0.md](docs/five-element-review-1.0.0.md)：五要素审计
- [fuzz-evidence-0.13.0.md](docs/fuzz-evidence-0.13.0.md) 与 `docs/fuzz-evidence-0.13.0-logs/`：fuzz 证据（含原始日志）
- [0.13.0-gate-plan.md](docs/0.13.0-gate-plan.md)、[API-REVIEW-0.13.0.md](docs/API-REVIEW-0.13.0.md)、[COVERAGE-0.13.0.md](docs/COVERAGE-0.13.0.md)、[CHANGELOG.md](docs/CHANGELOG.md)、`docs/release/`（SBOM / 校验和 / 发布记录）
- 决策与设计记录：`docs/multi-language-implementation-plan.md`、`docs/five-language-ci-design.md`、`docs/go-implementation-plan.md`

**Conformance 仲裁层**（`conformance/`，语言无关权威）：

- `vectors/`：18 套语言无关 suite 共 508/508 cases（聚合 digest `35bebc8d384d71740f7c1a886bc50f4e095ff52fe05d2a407f04b842ee6922fa`）
- `fixtures/`：真实配置夹具；`corpora/`：mutation 语料
- `oracles/`：固定 runtime oracle（`hcl-go-v1`、`plist-macos-v1` 等，manifest 记录 runtime 固定事实与 documented skip_path）
- `differential/`：跨语言差分 case 集（byte parity / normalized / protocol-exchange，五语言共用单一权威）

**脚本**（`scripts/`）：

- 差分 oracle 驱动：`run-hcl-go-oracle.ps1`、`run-plist-macos-oracle.ps1`（exit 3 = documented skip）
- 固定 runtime oracle 源码与固定工具链：`scripts/oracles/`
- 上游格式 gate：`run-toml-test.ps1`（官方 toml-test v2.2.0）、`run-yaml-test-suite.ps1`（官方 yaml-test-suite data-2022-01-17）、`run-properties-jdk-oracle.ps1` / `run-python-configparser-oracle.ps1` / `run-dotnet-ini-oracle.ps1` / `run-windows-ini-oracle.ps1` / `run-qt-ini-oracle.ps1`（5 套固定 runtime oracle，36/36 差分案例）

**其他**：SECURITY.md（安全政策）、LICENSE、CHANGELOG.md（版本变更记录）、`.github/workflows/ci.yml`（本仓 CI：差分 oracle + 聚合 digest 断言）。

## Conformance 权威声明

- 各语言仓（consema-rs / consema-go / consema-ts / consema-py / consema-kt）CI 通过多仓 checkout 从本仓 `conformance/` 取数：vectors、fixtures、oracles 与 differential case 集是本仓维护、五仓共享的**单一语言无关权威**。
- 本仓 CI 的 `shared-conformance-digest` job 复算 `conformance/vectors/` 聚合 digest 并断言等于 `35bebc8d384d71740f7c1a886bc50f4e095ff52fe05d2a407f04b842ee6922fa`（算法：文件名字节序排序、逐文件 sha256、`{basename}:{digest}` 以 `\n` 连接、再 sha256；以规范 checkout 的 LF 字节为准，见 `docs/fc-manifest-0.13.0.json` conformance_suite note）。
- **向量变更是五仓同步事件**：任何一仓修改 `conformance/vectors/` 都必须同步全部五个语言仓（实现与测试）并同步更新聚合 digest 与 18/508 计数；未同步的向量变更会让各仓 conformance gate 与 digest 断言失败。

## 格式家族

JSON family（`json.strict@1`、`jsonc.bounded@1`、`json5.standard@1`）、TOML（`toml.1.0@1`）、YAML family（`yaml.1.2-core@1`、`yaml.1.1-compat@1`）、INI family（`ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1`）、Java Properties（`java-properties.reader@1`、`java-properties.latin1@1`）、XML（`xml.1.0-safe@1`）、Property List（`plist.xml@1`、`plist.binary@1`）、HCL family（`hcl.native@1`、`hcl.tfvars@1`）。

各格式的查询、投影、materialization、版本化编辑操作、CLI 等具体能力与示例见各语言仓 README（Rust 见 consema-rs，Go 见 consema-go，TypeScript 见 consema-ts，Python 见 consema-py，Kotlin 见 consema-kt）。

## 验证（本仓侧）

```powershell
./scripts/run-toml-test.ps1                          # 官方 toml-test v2.2.0 gate（205 valid + 474 invalid）
./scripts/run-yaml-test-suite.ps1                    # 官方 yaml-test-suite data-2022-01-17 gate（402 case）
./scripts/run-properties-jdk-oracle.ps1              # 固定 runtime oracle（5 套 / 36/36 差分案例）
./scripts/run-python-configparser-oracle.ps1
./scripts/run-dotnet-ini-oracle.ps1
./scripts/run-windows-ini-oracle.ps1
./scripts/run-qt-ini-oracle.ps1
./scripts/run-hcl-go-oracle.ps1                      # HCL Go 差分 oracle（三 OS CI，exit 3 = documented skip）
./scripts/run-plist-macos-oracle.ps1                 # plist macOS 差分 oracle
```

各语言实现自身的测试与门禁在其各自仓 CI（consema-rs / consema-go / consema-ts / consema-py / consema-kt）。
