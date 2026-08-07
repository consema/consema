param(
    [string]$GoRoot = '',
    [string]$DriverPath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\hcl-go-v1\manifest.json'
$driverSource = Join-Path $workspaceRoot 'conformance\oracles\hcl-go-v1\main.go'
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'

if (-not $GoRoot) {
    $GoRoot = Join-Path $oracleRoot 'go-1.26.5'
}
if (-not $DriverPath) {
    $DriverPath = Join-Path $workspaceRoot 'conformance\oracles\hcl-go-v1\hcl-go-differential.exe'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'hcl-go-v1.tsv'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.hcl.go-differential@1') {
    throw "unexpected HCL Go oracle suite: $($manifest.suite)"
}

$driverHash = (Get-FileHash -LiteralPath $driverSource -Algorithm SHA256).Hash.ToLowerInvariant()
if ($driverHash -cne $manifest.driver.source_sha256) {
    throw "HCL Go driver digest mismatch: expected $($manifest.driver.source_sha256), got $driverHash"
}

$driver = Join-Path $GoRoot 'bin\go.exe'
if (-not (Test-Path -LiteralPath $driver)) {
    # Allowed skip path: no pinned Go toolchain is installed (RFC 0014 §12
    # records the skip in the manifest; Windows CI without a Go runner skips
    # explicitly per the repository oracle precedent).
    Write-Output "HCL Go differential: SKIPPED (no pinned Go toolchain under $GoRoot)"
    exit 3
}
if (-not (Test-Path -LiteralPath $DriverPath)) {
    # The driver executable is a build artifact of the pinned module
    # (go.mod/go.sum digest-pinned); build it from source when missing.
    $oracleDir = Join-Path $workspaceRoot 'conformance\oracles\hcl-go-v1'
    $previous = Get-Location
    Set-Location $oracleDir
    try {
        & $driver build -o $DriverPath . | Out-Null
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        Set-Location $previous
    }
}

$runtimeLines = @(& $DriverPath --runtime)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtime = @{}
foreach ($line in $runtimeLines) {
    $parts = $line -split "`t", 2
    if ($parts.Count -ne 2 -or $runtime.ContainsKey($parts[0])) {
        throw "invalid or duplicate runtime fact: $line"
    }
    $runtime[$parts[0]] = $parts[1]
}
foreach ($fact in $manifest.runtime.PSObject.Properties) {
    if ($fact.Name -eq 'windows_build') { continue }
    if (-not $runtime.ContainsKey($fact.Name) -or $runtime[$fact.Name] -cne $fact.Value) {
        throw "runtime mismatch for $($fact.Name): expected $($fact.Value), got $($runtime[$fact.Name])"
    }
}
$windowsBuild = [Environment]::OSVersion.Version.ToString()
if ($windowsBuild -cne $manifest.runtime.windows_build) {
    throw "Windows build mismatch: expected $($manifest.runtime.windows_build), got $windowsBuild"
}

$seen = @{}
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$($manifest.runtime.'go.version')`t$($manifest.runtime.'hcl.module')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) {
        throw "duplicate HCL Go oracle case id: $($case.id)"
    }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "HCL Go oracle input escapes workspace: $($case.input)"
    }
    $mode = switch ($case.mode) {
        'document' { '--document' }
        'expression' { '--expression' }
        default { throw "unknown oracle mode in $($case.id): $($case.mode)" }
    }

    $actual = @(& $DriverPath $mode $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    switch ($case.expected.outcome) {
        'accept' { $expected.Add("outcome`taccept") }
        'reject' { $expected.Add("outcome`treject") }
        default { throw "unknown expected outcome in $($case.id): $($case.expected.outcome)" }
    }
    if (($actual -join "`n") -cne ($expected -join "`n")) {
        throw "HCL Go oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actual -join "`n")"
    }
    $report.Add("case`t$($case.id)`t$($case.expected.outcome)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "HCL Go differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
