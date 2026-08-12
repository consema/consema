# Consema 规范站

Consema 是配置格式统一处理库：对 JSON/JSONC/JSON5、TOML、YAML、INI、Java Properties、XML、Property List 与 HCL 八个格式家族提供无损文档、格式原生语义、公共值、查询、显式投影、来源映射和原子编辑，默认拒绝未经授权的转换、截断或信息损失。规范与设计语言无关，由五个独立实现（Rust、Go、TypeScript、Python、Kotlin）共同证明（2026-08-11 决策：五语言同等地位）。

本网站是规范仓（[consema/consema](https://github.com/consema/consema)）文档的**发布视图**：把 `docs/` 与根目录的规范、RFC、路线图、指南与审计证据变成可浏览、可引用的静态站点。

> **权威声明**：本站是发布视图。所有文档的**权威版本始终在规范仓**（`docs/` 与根目录，见各页"权威文件"链接）。本站副本与仓库可能有时间差；引用时以 GitHub 上的规范仓为准。站点源码在 `docs-site/`。

## 六仓结构

2026-08-12 起 Consema 拆分为六个仓库：规范仓是规范 / conformance 仲裁层，五个语言实现各自成仓。

| 仓库 | 角色 |
| --- | --- |
| [consema](https://github.com/consema/consema)（规范仓） | 规范 / RFC / 路线图 / 审计证据 / conformance 仲裁层（语言无关权威） |
| [consema-rs](https://github.com/consema/consema-rs) | Rust 参考实现 |
| [consema-go](https://github.com/consema/consema-go) | Go 实现 |
| [consema-ts](https://github.com/consema/consema-ts) | TypeScript 实现 |
| [consema-py](https://github.com/consema/consema-py) | Python 实现 |
| [consema-kt](https://github.com/consema/consema-kt) | Kotlin 实现 |

拆分决策与执行记录见本站[设计记录](design/index.md)。

## 本站内容导航

- **[规范](spec/index.md)**：RFC 0001–0016 全清单 + RFC 0020 兼容政策。RFC 是语言无关规范的权威载体；重点：[RFC 0015](spec/rfcs/0015-cli-machine-protocol-and-batch-apply-v1.md)（CLI 机器协议与 batch apply）、[RFC 0020](spec/rfcs/0020-compatibility-and-support-policy-v1.md)（1.0 兼容与支持政策）。
- **[概念](concepts/index.md)**：[配置内容统一处理标准](concepts/content-standard.md)（语义基线）与 [1.0.0 产品路线图](concepts/roadmap-1.0.0.md)。
- **[指南](guides/index.md)**：CLI Cookbook（可复制配方集）、平台接入指南、迁移指南。
- **[设计记录](design/index.md)**：六仓拆分、多语言实现计划、五语言 CI 设计。
- **[发布](release/RELEASING.md)**：Consema 组织级发布纪律（六仓发布总纲）。
- **[审计与证据](audit/index.md)**：五要素终审、RC 候选清单、fuzz 证据等（链接到规范仓，不在本站复制）。

## 格式家族

JSON family（`json.strict@1`、`jsonc.bounded@1`、`json5.standard@1`）、TOML（`toml.1.0@1`）、YAML family（`yaml.1.2-core@1`、`yaml.1.1-compat@1`）、INI family（`ini.portable@1`、`ini.windows@1`、`ini.python-configparser@1`）、Java Properties（`java-properties.reader@1`、`java-properties.latin1@1`）、XML（`xml.1.0-safe@1`）、Property List（`plist.xml@1`、`plist.binary@1`）、HCL family（`hcl.native@1`、`hcl.tfvars@1`）。

## 规范仓其他入口

- 仓库 README（完整版）：[github.com/consema/consema](https://github.com/consema/consema)
- [CHANGELOG](https://github.com/consema/consema/blob/main/CHANGELOG.md) / [CONTRIBUTING](https://github.com/consema/consema/blob/main/CONTRIBUTING.md) / [SECURITY](https://github.com/consema/consema/blob/main/SECURITY.md) / [LICENSE](https://github.com/consema/consema/blob/main/LICENSE)

## 本地构建

```powershell
mdbook build docs-site   # 或 cd docs-site; mdbook build
mdbook serve docs-site   # 本地预览 http://localhost:3000
```

构建产物在 `docs-site/book/`（已 gitignore）；GitHub Actions（`.github/workflows/docs-site.yml`）在每次 `docs-site/` 变更时自动构建并部署到 GitHub Pages。
