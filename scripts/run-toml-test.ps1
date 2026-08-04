param(
    [string]$TomlTestVersion = 'v2.2.0'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }

& $cargo build --locked -p consema-conformance --bin consema-toml-test-decoder
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$decoder = Join-Path $workspaceRoot 'target\debug\consema-toml-test-decoder.exe'
& go run "github.com/toml-lang/toml-test/v2/cmd/toml-test@$TomlTestVersion" test -toml 1.0 -decoder $decoder
exit $LASTEXITCODE
