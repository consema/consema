param(
    [string]$JavaHome = '',
    [string]$PackagePath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\java-properties-v1\manifest.json'
$adapterPath = Join-Path $workspaceRoot 'scripts\oracles\PropertiesOracle.java'
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'
$workRoot = Join-Path $oracleRoot 'properties-oracle-work'

if (-not $JavaHome) {
    $JavaHome = Join-Path $oracleRoot 'microsoft-jdk-25.0.4\jdk-25.0.4+7'
}
if (-not $PackagePath) {
    $PackagePath = Join-Path $oracleRoot 'microsoft-jdk-25.0.4-windows-x64.zip'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'java-properties-v1.tsv'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -ne 'consema.java-properties.jdk25-differential@1') {
    throw "unexpected Properties oracle suite: $($manifest.suite)"
}

# 前置可及化（2026-08-15 波 4，与 run-plistlib-oracle.ps1 同族）：documented
# skip（exit 3）检查必须在任何钉版工具链文件访问（Get-FileHash zip /
# Test-Path javac.exe）之前——钉版工件在本仓任何 checkout 都不存在，若先做
# 文件检查，脚本以 exit 1 终止，skip 路径不可达（对照 run-hcl-go-oracle.ps1
# 体例，skip 检查同样在工具链探测之前）。
$windowsBuild = [Environment]::OSVersion.Version.ToString()
if ($windowsBuild -cne $manifest.runtime.windows_build) {
    Write-Output "Properties JDK oracle: SKIPPED (Windows build mismatch: expected $($manifest.runtime.windows_build), got $windowsBuild; documented skip path, 2026-08-15 波 4 前置可及化 对照 run-hcl-go-oracle.ps1 体例)"
    exit 3
}

$packageHash = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($packageHash -cne $manifest.authority.package_sha256) {
    throw "OpenJDK package digest mismatch: expected $($manifest.authority.package_sha256), got $packageHash"
}
$adapterHash = (Get-FileHash -LiteralPath $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($adapterHash -cne $manifest.adapter.source_sha256) {
    throw "Properties oracle adapter digest mismatch: expected $($manifest.adapter.source_sha256), got $adapterHash"
}

$javac = Join-Path $JavaHome 'bin\javac.exe'
$java = Join-Path $JavaHome 'bin\java.exe'
if (-not (Test-Path -LiteralPath $javac) -or -not (Test-Path -LiteralPath $java)) {
    throw "pinned OpenJDK executables are missing under $JavaHome"
}
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
& $javac -Xlint:all -Werror -d $workRoot $adapterPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$runtimeLines = @(& $java -cp $workRoot PropertiesOracle --runtime)
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
$seen = @{}
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$($manifest.runtime.'java.runtime.version')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) {
        throw "duplicate Properties oracle case id: $($case.id)"
    }
    $seen[$case.id] = $true
    if ($case.profile -notin @('reader', 'latin1')) {
        throw "unknown Properties oracle profile: $($case.profile)"
    }
    if ($case.storage -notin @('bytes', 'hex')) {
        throw "unknown Properties oracle storage: $($case.storage)"
    }
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Properties oracle input escapes workspace: $($case.input)"
    }

    $actual = @(& $java -cp $workRoot PropertiesOracle $case.profile $case.storage $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    switch ($case.expected.outcome) {
        'complete' {
            $expected.Add('complete')
            foreach ($entry in $case.expected.entries) {
                if ($entry.Count -ne 2) {
                    throw "invalid expected entry in $($case.id)"
                }
                $expected.Add("entry`t$($entry[0])`t$($entry[1])")
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
        throw "Properties oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actual -join "`n")"
    }
    $report.Add("case`t$($case.id)`t$($case.expected.outcome)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "Properties JDK differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
