param(
    [string]$TomlTestVersion = 'v2.2.0'
)

$ErrorActionPreference = 'Stop'
# 注（2026-08-13）：六仓拆分后母仓根无 Cargo.toml/workspace——本脚本的
# `cargo build --locked -p consema-conformance` 在母仓原位必然失败（exit 101）；
# 须从 consema-rs 检出运行（脚本保留于本仓 scripts/ 作记录载体，无 CI job
# 执行；官方 toml-test 205 valid + 474 invalid 的记录见 fuzz-evidence 与
# conformance/README 上游 gate 段）。
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }

& $cargo build --locked -p consema-conformance --bin consema-toml-test-decoder
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$targetDirectory = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $workspaceRoot 'target' }
$decoder = Join-Path $targetDirectory 'debug\consema-toml-test-decoder.exe'
& go run "github.com/toml-lang/toml-test/v2/cmd/toml-test@$TomlTestVersion" test -toml 1.0 -decoder $decoder
exit $LASTEXITCODE
