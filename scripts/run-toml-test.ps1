param(
    [string]$TomlTestVersion = 'v2.2.0'
)

$ErrorActionPreference = 'Stop'
# 注（2026-08-13，2026-08-14 波 2 修订，2026-08-15 波 5 归正）：六仓拆分后母仓根
# 无 Cargo.toml/workspace——本脚本的 `cargo build --locked -p consema-conformance`
# 在母仓原位必然失败（exit 101）；脚本只存在于母仓 scripts/（consema-rs 无副本，
# 无处可检），目前作为记录载体保留、无 CI job 执行（官方 toml-test 205 valid +
# 474 invalid 的记录载体是 docs/UPSTREAM-TOML-TEST.md 与 conformance/README 上游
# gate 段——本脚本为纯执行器、零写入命令，fuzz-evidence 不含该记录，2026-08-15
# 波 5 归正证据指针）；可执行入口的迁移/重建待总指挥决策。
# OS 约束（2026-08-15 波 5 如实披露）：本脚本为 Windows-only——decoder 路径硬编码
# `debug\consema-toml-test-decoder.exe` 反斜杠形态（下方 $decoder）；POSIX + pwsh7
# 主机即使满足全部隐式前置（cargo/CONSEMA_CARGO、go 在 PATH、并排 consema-rs 检出）
# 也会在此路径查找处失败。
# 供应链注（2026-08-15 波 5 如实披露）：toml-test 经 `go run pkg@version` 运行时从
# Go proxy 解析模块及其传递闭包（版本钉定 @v2.2.0；字节经 Go sumdb 校验，但母仓
# 无 go.mod/go.sum、下载字节在仓库内零锚定）——与 docs-site.yml mdbook 0.5.4 与
# kt kotlinc zip 的 sha256 固定姿态不同，属已披露差异。
# 注意：若未来迁移执行，必须先修正 target 路径解析——cargo build 按启动 cwd 解析、
# 脚本按自身位置解析 target 目录，两者不一致会静默命中陈旧二进制。
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }

& $cargo build --locked -p consema-conformance --bin consema-toml-test-decoder
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$targetDirectory = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $workspaceRoot 'target' }
$decoder = Join-Path $targetDirectory 'debug\consema-toml-test-decoder.exe'
& go run "github.com/toml-lang/toml-test/v2/cmd/toml-test@$TomlTestVersion" test -toml 1.0 -decoder $decoder
exit $LASTEXITCODE
