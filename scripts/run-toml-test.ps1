param(
    [string]$TomlTestVersion = 'v2.2.0'
)

$ErrorActionPreference = 'Stop'
# 注（2026-08-13，2026-08-14 波 2 修订）：六仓拆分后母仓根无 Cargo.toml/workspace——
# 本脚本的 `cargo build --locked -p consema-conformance` 在母仓原位必然失败（exit 101）；
# 脚本只存在于母仓 scripts/（consema-rs 无副本，无处可检），目前作为记录载体保留、
# 无 CI job 执行（官方 toml-test 205 valid + 474 invalid 的记录见 fuzz-evidence 与
# conformance/README 上游 gate 段）；可执行入口的迁移/重建待总指挥决策。
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
