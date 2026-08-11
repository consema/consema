# 1.0.0-rc.1 发布路径预检产物（PREVIEW）

- 归档日期：2026-08-11（文件本体生成于 2026-08-10 晚，发布路径预检 agent 工作产物）
- 来源：`%TEMP%`（`C:\Users\franck\AppData\Local\Temp\`）——发布路径预检 agent 于 2026-08-10 在 `release-preview-wt` 工作树（位于 %TEMP% 下）生成后遗留
- 性质：**发布路径预检证据**（非正式发布产物）——用于验证 1.0.0-rc.1 的 packaging / SBOM / 归档校验发布路径可行
- 与 C-3 正式发布产物的关系：正式发布（C-3）时须从**干净发布 commit 重新生成**（rc-1.0.0-candidate.md §4 D-1：manifest 必须从干净发布 commit 重新生成；release-process-0.13.0.md §7 十项检查单顺序执行）；本目录 PREVIEW 文件保留为预检证据，不进入正式发布产物清单

## 文件清单与生成命令

| 文件 | 内容 | 生成命令（预检 agent 记录） |
|---|---|---|
| sbom-1.0.0-rc.1.json | SPDX-2.3 SBOM（cargo-sbom v0.10.0；name=release-preview-wt；documentNamespace 含 `release-preview-wt-131bca3d-bca3-47c6-8818-78b1be2f6dd4`；49,385 字节） | cargo-sbom 生成于 `release-preview-wt` 工作树（creationInfo.created 2026-08-10T11:14:52Z） |
| cargo-package-1.0.0-rc.1.log | `cargo package --workspace --locked --no-verify` 完整输出：14 个 crate 全部 Packaging 成功（consema 854.0KiB / consema-conformance 1.4MiB 等）；仅"manifest has no documentation, homepage or repository"warning | PowerShell 调 `cargo package --workspace --locked --no-verify 2>&1 \| Tee-Object` |
| verify-package-archives-1.0.0-rc.1.result.txt | 14 个 `.crate` 归档 SHA-256 逐文件清单 + "verified 14 publishable package archives" + MSRV build leg（rustc 1.85.0 对全部 14 crate 构建通过）+ repository-only 包说明（consema-conformance） | 归档校验脚本（对 14 个 publishable package archives 校验 + MSRV 构建） |

## 预检结果摘要

- 14 个 publishable package archives 全部验证通过（逐文件 SHA-256 见 result.txt）
- MSRV build leg：rustc 1.85.0 构建全部 14 个 crate 通过
- cargo package：14 个 crate Packaging 成功（consema-conformance 为 repository-only，不发布）
- SBOM：SPDX-2.3 合法 JSON（json.load 验证通过），cargo-sbom v0.10.0 生成

## 正式发布（C-3）时

- 从干净发布 commit 重新生成 SBOM、cargo package 输出与归档校验（release-process-0.13.0.md §7；rc-1.0.0-candidate.md §4 D-1：manifest 必须从干净发布 commit 重新生成）
- 本目录 PREVIEW 文件仅作发布路径预检证据，不作为正式发布产物
