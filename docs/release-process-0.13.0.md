# Consema 0.13.0 发布流程（发布供应链，路线图 §19.4）

- 目的：把路线图 §19.4 的稳定发布要素（`docs/0.13.0-gate-plan.md` M7、§7 验收表
  "SBOM + 签名标签/artifact + checksum + 干净重建 + 恢复演练记录"）落成可执行流程。
- 权威载体：本文件（流程 + 演练记录）；`scripts/release-sign.ps1`（签名/校验）；
  `scripts/release-sbom.ps1`（SBOM）；`scripts/verify-package-archives.ps1`（打包门禁，
  0.13.0 M1 交付）；`.github/workflows/ci.yml` package job（常设载体，M1 交付）。
- 2026-08-07 首次执行记录：全部脚本与演练在本机（Windows 11，PowerShell 5.1 +
  Git for Windows msys 环境）实测，产出物已入库（`docs/release/`）。
- 不变量：**任何签名产物都必须来自真实 GPG 操作与真实归档**；演练记录只写实际发生
  的输出与退出码；人工改动 checksum 清单以迁就损坏归档视为伪造证据。

## 1. §19.4 要素 → 产物映射

| §19.4 要素 | 载体 | 状态 |
|---|---|---|
| locked dependency graph | Cargo.lock（`git` 内）；SBOM 的 `dependencyReferences` | 已有 |
| Cargo 与 Go dependency audit | CI deny/audit job；cargo-audit 本地门禁 | 已有（go/ 已按 2026-08-07 decision record 启动 0.14.0 G0.1-G0.3，std-only 零第三方依赖，go-implementation-plan §1.3） |
| license inventory | deny.toml + SBOM `licenseConcluded` 字段 | 已有 + §4 |
| source archive | git 仓库 + 14 个 `.crate`（verify-package-archives 打包） | 已有 |
| SBOM | `docs/release/sbom-<version>.json`（`scripts/release-sbom.ps1`） | §4 |
| artifact checksum | `docs/release/SHA256SUMS-<version>.txt`（§2） | §2 |
| signed tag 与 release artifact | `git tag -s` + SHA256SUMS 的 `.asc`/`.sig`（§3） | §3 |
| build provenance | 干净环境重建步骤（§1.1）+ CI package job（§1.2） | 本文件 |
| 干净环境重建步骤 | 本文件 §1.1 | 本文件 |
| 安全披露联系方式和支持周期 | SECURITY.md 新增章节 | §6 引用 |

## 2. Build provenance：干净环境重建

### 2.1 本地干净重建步骤（发布记录必须执行）

```text
1. 干净 checkout（发布记录要求 clean HEAD；脚本的脏树前置条件见下）
2. rustup toolchain install stable 与 1.85.0（MSRV 腿需要，版本由
   Cargo.toml rust-version 声明，当前 1.85）
3. cargo fetch --locked          # 预热 offline cache（CI 同款第一步）
4. powershell -File scripts/verify-package-archives.ps1
   # 或跳过 MSRV 腿的本地快速跑：-SkipMsrv
```

预期输出（真实运行记录，2026-08-07）：

```text
verified 14 publishable package archives
<64 位小写 sha256>  <name>-0.8.0.crate      (共 14 行)
MSRV build leg: rustc 1.85.0 for all 14 crates
```

- 脚本语义（`scripts/verify-package-archives.ps1`）：`cargo package --workspace
  --locked --offline --no-verify` → tar 路径安全（拒绝 `..` 与非 `root/` 前缀条目）→
  提取后校验每个 crate 内嵌 Cargo.lock 与兄弟归档的 sha256 交叉一致 → 每 crate
  offline `check --all-targets --all-features` → MSRV 1.85 腿对全部 14 crate
  `build --all-targets --all-features`。
- 脏树前置条件：不带 `-AllowDirty` 运行时，`git status --porcelain` 非空即失败并
  逐行列出现场脏文件（cargo package 拒绝脏树，门禁不静默绕过）；`-AllowDirty` 只
  是本地逃生口，CI 恒在干净 checkout 运行。
- 14 个可发布 crate 集合由 cargo metadata 计算（workspace member 且 `publish`
  为空）；`consema-conformance` 等 `publish = false` crate 只进仓库，不打进归档。

### 2.2 CI package job（常设载体，`.github/workflows/ci.yml:285-303`）

- `package` job：`ubuntu-latest`、`timeout-minutes: 60`；steps：
  `actions/checkout@v4` → `dtolnay/rust-toolchain@stable` → `dtolnay/rust-toolchain@1.85.0`
  → `swatinem/rust-cache@v2` → `cargo fetch --locked` → 运行
  `scripts/verify-package-archives.ps1`（pwsh）。
- 语义：**每次推入都在干净 checkout 上重建全部 14 个发布归档并跑完整门禁**——这是
  "release artifact 可从干净环境重建"（§15.6）的常设证明，发布记录只需补充本地
  签名/SBOM/checksum 步骤，不需要重复证明可重建性。
- 边界（M1 记录，R-3）：HCL Go oracle 在 hosted runner 只能文档化 skip（exit 3），
  真实差分归自托管；不影响 package job。

## 3. Checksum 清单

- 格式（与 verify-package-archives.ps1 的 sha256 输出逐字节一致）：
  每行 `<64 位小写十六进制>  <文件名>.crate`（双空格分隔，文件名无路径）。
- 生成：`powershell -File scripts/release-sign.ps1 -SignArtifacts [-ArchiveDirectory <dir>]`
  —— 同一 cargo metadata 的 publishable 集合、按 name 排序，重算 `Get-FileHash`
  SHA256；默认写 `docs/release/SHA256SUMS-<workspace version>.txt`（workspace 版本
  取所有成员共享版本，`[workspace.package] version`，根 manifest 是 virtual workspace）。
- 校验：`powershell -File scripts/release-sign.ps1 -VerifyArtifacts -ManifestPath
  docs/release/SHA256SUMS-<version>.txt` —— 逐条重算对比，任何 mismatch 或缺失
  归档都以 exit 1 列明；然后 `gpg --verify` `.asc`/`.sig`。
- 发布时同时入库三个文件：`SHA256SUMS-<version>.txt`（纯文本）、`.asc`（clearsign，
  含文本+签名，适合直接分发）、`.sig`（detached ASCII 签名）。

## 4. 签名流程（`scripts/release-sign.ps1`）

### 4.1 前置条件（脚本逐一检测，缺失即 exit 2 并给出安装命令）

- git 在 PATH 且目标是 git work tree（`-RepoRoot` 可覆盖，默认 workspace root）。
- gpg 2.x 在 PATH（Windows: `winget install GnuPG.GnuPG`；macOS: `brew install
  gnupg`；Debian/Ubuntu: `sudo apt-get install gnupg`）。脚本拒绝 <2.x。
- 有效签名密钥：`gpg --list-secret-keys` 至少一个带 signing 能力（usage 含 `S`）
  的密钥；无密钥时脚本打印 `gpg --full-generate-key`（或 batch quick-generate-key）
  指引并退出。发布密钥必须备份——**丢失密钥使所有既有签名不可验证**（§5.3）。

### 4.2 签名 tag

```text
powershell -File scripts/release-sign.ps1 -SignTag v0.13.0 [-KeyId <fingerprint>]
```

- 执行 `git tag -s -a v0.13.0 -u <fingerprint> -m "Consema 0.13.0"`，随后
  `git tag -v` 自检（Good signature）才 exit 0。
- `-u` 总是钉死脚本检测到的密钥指纹：不带 `-u` 时 git 会从 user.name/user.email
  推导签名密钥，可能静默换键（2026-08-07 实测确认）。建议同时配置
  `git config user.signingkey <fingerprint>` 让非脚本工具用同一把键。
- **已存在的 tag 拒绝重签**（exit 1）：tag 是内容寻址的，重签会铸造新 tag 对象并
  孤立旧签名；只有明确要替换时才 `git tag -d` 后重签（替换会破坏"该版本永远
  指向同一对象"的可审计性，发布后禁止）。

### 4.3 签名 release artifact（checksum 清单）

```text
powershell -File scripts/release-sign.ps1 -SignArtifacts
```

- 写 manifest（§3）→ `gpg --clearsign` → `.asc` → `gpg --detach-sign --armor` →
  `.sig` → 对两者 `gpg --verify`，任一失败 exit 1。
- 隔离密钥环：`-GpgHome <dir>`（演练/CI 用，绝不触碰默认 keyring）；msys gpg 的
  GNUPGHOME 以 cygpath 转 POSIX 路径，并设 `MSYS2_ENV_CONV_EXCL=GNUPGHOME` 阻止
  Git for Windows 在 spawn gpg 时把它转回 Windows 形式（两个转换均 2026-08-07 实测）。

### 4.4 本机首次执行的真实记录（2026-08-07）

- 机器状态：gpg 2.4.9（Git for Windows msys build）已装；**默认 keyring 尚无任何
  密钥**。不带 `-GpgHome` 运行时脚本按设计失败（exit 2），错误信息给出创建密钥
  指引——这是真实失败路径，不是演练剧本：
  `error: no usable secret signing key in the effective keyring.`
- 演练密钥环（`-GpgHome` 隔离，临时目录）：`gpg --batch --passphrase '' --
  quick-gen-key "Consema Release Drill <release-drill@consema.invalid>" rsa2048 sign`
  生成演练密钥 `823016129EBDEAF7DF15ACA7C9804B1CC0EA4776`，随后：
  - `-SignArtifacts` 全流程 exit 0：manifest（14 行）→ clearsign → detach-sign →
    两个 `gpg --verify` ok。
  - `-SignTag v0.13.0-drill`（scratch git 仓库）exit 0，`git tag -v` Good signature。
  - 已存在 tag 重签被拒（exit 1）。
  - `-VerifyArtifacts` 对真实 14 个归档 + 已签名 manifest 全量 exit 0。
- **0.13.0 正式发布前必须在默认 keyring 生成真实发布密钥**（流程同 §4.1），并保留
  私钥备份与吊销证书；演练密钥仅用于流程验证，不进入任何发布记录。

## 5. SBOM 生成（`scripts/release-sbom.ps1`）

### 5.1 选型记录（含 rejected alternative）

- **选中：cargo-sbom 0.10.0**（crates.io，MIT，psastras/sbom-rs）。
- **拒绝：cyclonedx-bom 0.8.1**（crates.io，Apache-2.0，CycloneDX org）。
- 理由（2026-08-07 两台候选均可安装，网络实测可用）：
  1. cargo-sbom 是原生 cargo 子命令（`cargo sbom`），与本仓库既有工具链体例一致
     （cargo-audit / cargo-deny / cargo-llvm-cov / cargo-fuzz / cargo-nextest 均为
     cargo install 子命令），并可用 `$env:CONSEMA_CARGO` 约定覆盖。
  2. cargo-sbom 直接读 Cargo.lock（经 cargo metadata），输出 SPDX 2.3 JSON
     （默认）或 CycloneDX 1.4/1.6 JSON；§19.3 依赖门禁审计的 license inventory
     （deny.toml：MIT/Apache-2.0/Unicode-3.0）以 SPDX license expression 直接背书。
  3. cyclonedx-bom 只有 CycloneDX 输出、依赖树更重，且 cargo-sbom 已能产出
     CycloneDX（`--output-format cyclone_dx_json_1_6`），需要 CycloneDX 消费者时
     无需换工具。
  4. 可复现性：内容（package/dependency/checksum 事实）是 Cargo.lock 与工具版本的
     纯函数；脚本对工具版本做 pin（0.10.0），版本漂移即 exit 2。

### 5.2 生成命令与产物

```text
powershell -File scripts/release-sbom.ps1
# 等价命令：cargo sbom --output-format spdx_json_2_3 --project-directory <root>
```

- 默认产物：`docs/release/sbom-<workspace version>.json`（版本取自 cargo metadata；
  0.13.0 记录时自动为 `sbom-0.13.0.json`）。stdout 输出经过 JSON 合法性校验才落盘。
- 首次真实生成记录（2026-08-07，workspace 版本 0.8.0）：
  `docs/release/sbom-0.8.0.json` —— SPDX-2.3，42 packages / 123 relationships，
  48,558 bytes；`creationInfo.creators = ["Tool: cargo-sbom-v0.10.0"]`；license
  分布 `{Unlicense OR MIT: 1, (MIT OR Apache-2.0) AND Unicode-3.0: 2, MIT OR
  Apache-2.0: 20, MIT: 16, Apache-2.0 OR MIT: 2, (Apache-2.0 OR MIT) AND
  BSD-3-Clause: 1}`，与 deny.toml 政策一致；生成 commit
  `9c1ede20fab56829cfaeca6924ee115ff01cd5d2`。
- 可复现性说明：重新生成时 `creationInfo.created` 时间戳与 `documentNamespace`
  必然变化（SPDX 规范如此），package/dependency/checksum 事实不变；发布记录须
  在同一 commit + 同一 lockfile 上重跑后入库。
- 缺工具的真实失败路径（2026-08-07 实测）：临时移走 `cargo-sbom.exe` 后运行 →
  `error: cargo-sbom is not installed ... cargo install cargo-sbom --version
  0.10.0 --locked`，exit 2。

## 6. 恢复演练（2026-08-07 真实执行记录）

三个演练全部用真实归档/真实 GPG/真实 git 操作执行；以下记录只含实际输出与退出码。

### 6.1 演练 1：checksum 清单被篡改（checksum mismatch）

步骤（发布后发现问题时的复现路径）：

```text
1. 复制 manifest 到临时目录（绝不改原始签名产物）
2. 篡改其中一行校验和（演练：把 consema-yaml 行的 sha256 前 6 位改成 aabbcc）
3. powershell -File scripts/release-sign.ps1 -VerifyArtifacts `
     -ManifestPath <篡改副本> -ArchiveDirectory target/package
```

真实输出（截取关键行）：

```text
FAIL: 1 archive verification failure(s):
  checksum mismatch: consema-yaml-0.8.0.crate
  manifest: aabbccd1ef206ab97679576de48d232b8cedc7d5519eea3684bcb2e98556917f
  actual:   bb05ffd1ef206ab97679576de48d232b8cedc7d5519eea3684bcb2e98556917f
exit 1
```

结论：篡改一行即被检出，且错误信息同时给出 manifest 与实测值。**恢复步骤：** 从
干净重建的归档重算（verify-package-archives 的输出即权威值），重新 `-SignArtifacts`
生成并重签 manifest；发布中绝不手工编辑 manifest。

### 6.2 演练 2：归档损坏（corrupted archive）

步骤：

```text
1. 复制一个真实 .crate 归档到临时目录
2. 用 dd 在偏移 100 处翻转一个字节（模拟传输损坏）
3. manifest 保持真实校验和，指向损坏副本
4. powershell -File scripts/release-sign.ps1 -VerifyArtifacts `
     -ManifestPath <manifest> -ArchiveDirectory <含损坏副本的目录>
```

真实输出（截取关键行）：

```text
FAIL: 1 archive verification failure(s):
  checksum mismatch: consema-yaml-0.8.0-corrupted.crate
  manifest: bb05ffd1ef206ab97679576de48d232b8cedc7d5519eea3684bcb2e98556917f
  actual:   2e5d40367df3ea158da96971edf51672dec9c3d477641cb086fb3b358dd872cc
exit 1
```

结论：单字节损坏即被检出。**恢复步骤：** 该归档不可用（不能用新 hash 重签继续
发布——checksum 保护的就是这个事实）；从干净环境重建该 crate 的归档
（`cargo package` 流程，§2），重新跑完整校验。

### 6.3 演练 3：tag 丢失（lost tag）

步骤（发布后 tag 引用被删除时的恢复路径）：

```text
1. git tag -d v0.13.0-drill          # 模拟丢失（只删 ref，对象还在）
2. git fsck --no-reflogs --unreachable   # 找 dangling tag 对象
3. git update-ref refs/tags/v0.13.0-drill <fsck 报告的 tag 对象 hash>
4. git tag -v v0.13.0-drill              # 恢复后签名必须仍可验证
```

真实输出（scratch git 仓库，演练签名 tag `bfecfa4b…`）：

```text
$ git tag -d v0.13.0-drill
Deleted tag 'v0.13.0-drill' (was bfecfa4)
$ git tag -v v0.13.0-drill
error: tag 'v0.13.0-drill' not found.
$ git fsck --no-reflogs --unreachable
unreachable tag bfecfa4b398225fe5246d2c923bbff0348182a03
$ git update-ref refs/tags/v0.13.0-drill bfecfa4b398225fe5246d2c923bbff0348182a03
$ git tag -v v0.13.0-drill
gpg: Good signature from "Consema Release Drill <release-drill@consema.invalid>" [ultimate]
verify exit=0
```

结论：删除 ref 后 tag 对象仍是 dangling object，`fsck` 可找回、`update-ref` 恢复
同一对象，签名原样可验证（对象 hash 不变）。**恢复步骤：** 见上；若对象已被
`git gc` 剪除（未推送的 tag 长期 dangling 后），唯一可靠恢复源是远程副本或
发布记录里登记的对象 hash——所以发布记录必须登记
`git rev-parse <tag>^{tag}` 的 tag 对象 hash（release-sign.ps1 的 `-SignTag`
输出已包含）。**禁止**用 `git tag -a` 重建同名 tag（会铸造新对象，旧签名失效）。

### 6.4 演练边界（诚实记录）

- 演练密钥（82301612…）与 scratch 仓库均不进入任何发布记录；0.13.0 正式签名用
  真实密钥按 §4.1 执行。
- 未演练：gpg 私钥丢失的恢复（不可恢复——这正是备份与吊销证书存在的原因，
  §4.4）；远程篡改场景（不在 §19.4 恢复演练范围）。

## 7. 0.13.0 发布检查单（收口时按序执行，M9 复核）

```text
□ 1. workspace 版本推进到 0.13.0（Cargo.toml [workspace.package] version）
□ 2. CI 10 job 全绿（含 package job，§2.2）——常设重建证明
□ 3. 本地干净重建：cargo fetch --locked + verify-package-archives.ps1（§2.1）
□ 4. SBOM：scripts/release-sbom.ps1 → docs/release/sbom-0.13.0.json（§5）
□ 5. Checksum：release-sign.ps1 -SignArtifacts → SHA256SUMS-0.13.0.txt(.asc/.sig)
□ 6. Tag：release-sign.ps1 -SignTag v0.13.0，登记 tag 对象 hash（§4.2）
□ 7. 全量校验：release-sign.ps1 -VerifyArtifacts（14 归档 + 双签名）exit 0
□ 8. 恢复演练按 §6 复跑一次并记录（若演练记录与本次差异，记录差异原因）
□ 9. 上述产物与本文件更新一并入库（发布记录 commit）
□ 10. SECURITY.md 的披露流程/支持周期章节随发布保持最新（§6 引用）
```

---

- 相关文件：`scripts/release-sign.ps1`、`scripts/release-sbom.ps1`、
  `scripts/verify-package-archives.ps1`、`.github/workflows/ci.yml`（package job）、
  `docs/release/SHA256SUMS-0.8.0.txt(.asc/.sig)`、`docs/release/sbom-0.8.0.json`、
  `SECURITY.md`（披露与支持周期章节）。
