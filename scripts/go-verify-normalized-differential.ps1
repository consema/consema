param(
    [string]$CaseFile = '',
    [string]$OutDir = ''
)

# ---------------------------------------------------------------------------
# Cross-language normalized-result differential verification (milestone
# 0.15.0 G1.5; docs/go-implementation-plan.md §4.4 and §2.2; roadmap §16.2
# line 1488; §11.2 lines 849-861).
#
# Pipeline (Go never imports or calls Rust, RFC 0016 §1.1):
#   1. builds the minimal Rust evidence example
#      (crates/consema-conformance/examples/emit_normalized_results.rs);
#   2. runs it over the checked-in case set
#      (go/conformance/differential/normalized/cases.json) into <OutDir> as
#      one `<case-id>.txt` normalized-facts file per case;
#   3. runs the Go side (`go test ./conformance/differential/normalized/`
#      with CONSEMA_DIFFERENTIAL_NORMALIZED_RUST_DIR set) which computes the
#      Go normalized results for the same input set and compares them field
#      by field with the Rust evidence files (case id + field + both values
#      on divergence).
#
# The compared facts are the language-neutral behavior surface of roadmap
# §11.2: parse formation, diagnostic code/order (never text), query
# count/identity/order, projection/materialization reports, edit result
# bytes or failure codes, and resource-limit completion semantics. A
# divergence is a finding for the roadmap §11.3 process, never a silent
# Rust-side "fix".
#
# Requirements: cargo (or $env:CONSEMA_CARGO) and go on PATH. Windows
# PowerShell 5.1 compatible, no third-party dependencies.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$goDir = Join-Path $workspaceRoot 'go'

# --- repo layout sanity ------------------------------------------------------
if (-not (Test-Path (Join-Path $workspaceRoot 'Cargo.toml')) -or
    -not (Test-Path (Join-Path $workspaceRoot 'crates\consema-conformance\Cargo.toml'))) {
    Write-Error "consema workspace not found: $workspaceRoot"
    exit 1
}
if (-not (Test-Path (Join-Path $goDir 'go.mod'))) {
    Write-Error "Go module not found: $goDir"
    exit 1
}
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Error 'go is not on PATH'
    exit 1
}

# --- case set ----------------------------------------------------------------
if ($CaseFile -eq '') {
    $CaseFile = Join-Path $goDir 'conformance\differential\normalized\cases.json'
}
if (-not (Test-Path $CaseFile)) {
    Write-Error "normalized differential case file not found: $CaseFile"
    exit 1
}
# UTF8 explicit: PowerShell 5.1 Get-Content defaults to the ANSI codepage.
$cases = Get-Content $CaseFile -Raw -Encoding UTF8 | ConvertFrom-Json
$caseCount = @($cases.cases).Count
if ($caseCount -lt 40) {
    Write-Error "normalized differential case file has $caseCount cases, want >= 40"
    exit 1
}

# --- Rust side ---------------------------------------------------------------
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }
if (-not (Get-Command $cargo -ErrorAction SilentlyContinue)) {
    Write-Error "cargo is not available ('$cargo')"
    exit 1
}
Write-Host "[1/3] building the Rust evidence example (emit_normalized_results)..."
& $cargo build --locked -p consema-conformance --example emit_normalized_results
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$targetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $workspaceRoot 'target' }
$example = Join-Path $targetDir 'debug\examples\emit_normalized_results.exe'
if (-not (Test-Path $example)) {
    Write-Error "Rust example binary not found: $example"
    exit 1
}
if ($OutDir -eq '') {
    $OutDir = Join-Path $targetDir 'go-differential-normalized'
}
# The env var is consumed by `go test` from the package directory, so it
# must be absolute.
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force $OutDir | Out-Null

Write-Host "[2/3] running the Rust example over $caseCount cases -> $OutDir"
& $example $CaseFile $OutDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "emit_normalized_results failed (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}

# --- Go side -----------------------------------------------------------------
Write-Host "[3/3] running the Go differential test (normalized_test.go)..."
$env:CONSEMA_DIFFERENTIAL_NORMALIZED_RUST_DIR = $OutDir
# Capture files live outside $OutDir: that directory must contain only the
# Rust example's `<case-id>.txt` files (the Go test rejects any other file).
$logDir = Join-Path $env:TEMP 'consema-go-normalized'
New-Item -ItemType Directory -Force $logDir | Out-Null
$stdoutFile = Join-Path $logDir 'go-test.stdout.txt'
$stderrFile = Join-Path $logDir 'go-test.stderr.txt'
Push-Location $goDir
try {
    & go test -count=1 -v ./conformance/differential/normalized/ 1> $stdoutFile 2> $stderrFile
    $testCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
Get-Content $stdoutFile | ForEach-Object { Write-Host $_ }
if (Test-Path $stderrFile) {
    Get-Content $stderrFile | ForEach-Object { Write-Host $_ }
}

# The differential test must have RUN (not skipped) and passed.
$output = Get-Content $stdoutFile -Raw
if ($output -match '--- SKIP: TestNormalizedDifferential') {
    Write-Error 'the differential test skipped: the Rust evidence directory was not provisioned'
    exit 1
}
if ($output -notmatch '--- PASS: TestNormalizedDifferential') {
    Write-Error "the differential test did not pass (go test exit $testCode)"
    if ($testCode -eq 0) { exit 1 } else { exit $testCode }
}
if ($testCode -ne 0) {
    exit $testCode
}

$summary = [regex]::Match($output, 'normalized-result differential: \d+/\d+ equal')
if ($summary.Success) {
    Write-Host "RESULT: $($summary.Value)"
} else {
    Write-Error 'cannot find the normalized-result differential summary line in the test output'
    exit 1
}
Write-Host "normalized-result differential verification complete (exit 0)"
exit 0
