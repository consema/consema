param(
    [string]$PythonHome = '',
    [string]$PackagePath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\python-configparser-v1\manifest.json'
$adapterPath = Join-Path $workspaceRoot 'scripts\oracles\configparser_oracle.py'
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'

if (-not $PythonHome) {
    $PythonHome = Join-Path $oracleRoot 'python-3.14.6'
}
if (-not $PackagePath) {
    $PackagePath = Join-Path $oracleRoot 'python-3.14.6-embeddable-amd64.zip'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'python-configparser-v1.tsv'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.ini.python-configparser314-differential@1') {
    throw "unexpected ConfigParser oracle suite: $($manifest.suite)"
}

$packageHash = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($packageHash -cne $manifest.authority.package_sha256) {
    throw "CPython package digest mismatch: expected $($manifest.authority.package_sha256), got $packageHash"
}
$adapterHash = (Get-FileHash -LiteralPath $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($adapterHash -cne $manifest.adapter.source_sha256) {
    throw "ConfigParser adapter digest mismatch: expected $($manifest.adapter.source_sha256), got $adapterHash"
}

$python = Join-Path $PythonHome 'python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw "pinned CPython executable is missing under $PythonHome"
}
$runtimeLines = @(& $python -I $adapterPath --runtime)
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
$report.Add("runtime`t$($manifest.runtime.'python.version')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) {
        throw "duplicate ConfigParser oracle case id: $($case.id)"
    }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "ConfigParser oracle input escapes workspace: $($case.input)"
    }

    $actual = @(& $python -I $adapterPath $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    switch ($case.expected.outcome) {
        'complete' {
            $expected.Add('complete')
            foreach ($entry in $case.expected.defaults) {
                if ($entry.Count -ne 2) {
                    throw "invalid expected default in $($case.id)"
                }
                $expected.Add("default`t$($entry[0])`t$($entry[1])")
            }
            foreach ($section in $case.expected.sections) {
                $expected.Add("section`t$($section.name)")
                foreach ($entry in $section.entries) {
                    if ($entry.Count -ne 2) {
                        throw "invalid expected section entry in $($case.id)"
                    }
                    $expected.Add("entry`t$($section.name)`t$($entry[0])`t$($entry[1])")
                }
            }
        }
        'failed' {
            $expected.Add("failed`t$($case.expected.exception)")
        }
        default {
            throw "unknown expected outcome in $($case.id): $($case.expected.outcome)"
        }
    }
    if (($actual -join "`n") -cne ($expected -join "`n")) {
        throw "ConfigParser oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actual -join "`n")"
    }
    $report.Add("case`t$($case.id)`t$($case.expected.outcome)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "ConfigParser differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
