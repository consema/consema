param(
    [string]$SuiteRoot = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$expectedCommit = '6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f'
$expectedTag = 'data-2022-01-17'
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }

if (-not $SuiteRoot) {
    $SuiteRoot = Join-Path $workspaceRoot 'target\yaml-test-suite-data-2022-01-17'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $workspaceRoot 'target\yaml-test-suite-data-2022-01-17.tsv'
}

if (-not (Test-Path -LiteralPath $SuiteRoot)) {
    & git clone --depth 1 --branch $expectedTag https://github.com/yaml/yaml-test-suite.git $SuiteRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$head = (& git -c "safe.directory=$($SuiteRoot.Replace('\', '/'))" -C $SuiteRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($head -ne $expectedCommit) {
    throw "yaml-test-suite commit mismatch: expected $expectedCommit, got $head"
}

& $cargo build --locked -p consema-conformance --bin consema-yaml-test-adapter
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$targetDirectory = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $workspaceRoot 'target' }
$adapter = Join-Path $targetDirectory 'debug\consema-yaml-test-adapter.exe'
& $adapter $SuiteRoot $ReportPath
exit $LASTEXITCODE
