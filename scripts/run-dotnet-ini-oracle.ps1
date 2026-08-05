param(
    [string]$DotnetHome = '',
    [string]$PackagePath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\dotnet-ini-v1\manifest.json'
$workRoot = Join-Path $oracleRoot 'dotnet-ini-work'

if (-not $DotnetHome) { $DotnetHome = Join-Path $oracleRoot 'dotnet-sdk-10.0.302' }
if (-not $PackagePath) { $PackagePath = Join-Path $oracleRoot 'dotnet-sdk-10.0.302-win-x64.zip' }
if (-not $ReportPath) { $ReportPath = Join-Path $oracleRoot 'dotnet-ini-v1.tsv' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.ini.dotnet10-provider-differential@1') {
    throw "unexpected .NET INI oracle suite: $($manifest.suite)"
}

function Assert-FileHash([string]$Path, [string]$Algorithm, [string]$Expected, [string]$Label) {
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    if ($actual -cne $Expected) {
        throw "$Label digest mismatch: expected $Expected, got $actual"
    }
}

$dotnet = Join-Path $DotnetHome 'dotnet.exe'
$iniAssembly = Join-Path $DotnetHome 'shared\Microsoft.AspNetCore.App\10.0.10\Microsoft.Extensions.Configuration.Ini.dll'
$sourcePath = Join-Path $workspaceRoot $manifest.adapter.source
$projectPath = Join-Path $workspaceRoot $manifest.adapter.project
$nugetConfigPath = Join-Path $workspaceRoot $manifest.adapter.nuget_config
Assert-FileHash $PackagePath SHA512 $manifest.authority.package_sha512 '.NET SDK package SHA-512'
Assert-FileHash $PackagePath SHA256 $manifest.authority.package_sha256 '.NET SDK package SHA-256'
Assert-FileHash $dotnet SHA256 $manifest.authority.dotnet_executable_sha256 'dotnet executable'
Assert-FileHash $iniAssembly SHA256 $manifest.authority.ini_assembly_sha256 'IniConfigurationProvider assembly'
Assert-FileHash $sourcePath SHA256 $manifest.adapter.source_sha256 '.NET adapter source'
Assert-FileHash $projectPath SHA256 $manifest.adapter.project_sha256 '.NET adapter project'
Assert-FileHash $nugetConfigPath SHA256 $manifest.adapter.nuget_config_sha256 '.NET NuGet configuration'

$sdkVersion = (& $dotnet --version).Trim()
if ($sdkVersion -cne $manifest.runtime.'sdk.version') {
    throw ".NET SDK version mismatch: expected $($manifest.runtime.'sdk.version'), got $sdkVersion"
}
$cliHome = Join-Path $oracleRoot 'dotnet-cli-home'
$packages = Join-Path $oracleRoot 'dotnet-packages'
New-Item -ItemType Directory -Force -Path (Join-Path $cliHome '.dotnet\tools'),(Join-Path $workRoot 'obj') | Out-Null
$env:DOTNET_CLI_HOME = $cliHome
$env:NUGET_PACKAGES = $packages
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_NOLOGO = '1'
& $dotnet msbuild $projectPath -target:Restore -property:RestoreConfigFile="$nugetConfigPath" -property:NuGetAudit=false -property:BaseIntermediateOutputPath="$workRoot\obj\"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $dotnet build $projectPath --no-restore -c Release -o "$workRoot\out" -p:BaseIntermediateOutputPath="$workRoot\obj\"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$adapter = Join-Path $workRoot 'out\DotnetIniOracle.dll'

$runtimeLines = @(& $dotnet $adapter --runtime)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtime = @{}
foreach ($line in $runtimeLines) {
    $parts = $line -split "`t", 2
    if ($parts.Count -ne 2 -or $runtime.ContainsKey($parts[0])) {
        throw "invalid or duplicate .NET runtime fact: $line"
    }
    $runtime[$parts[0]] = $parts[1]
}
foreach ($fact in $manifest.runtime.PSObject.Properties) {
    if ($fact.Name -in @('sdk.version', 'host.version', 'windows_build')) { continue }
    if (-not $runtime.ContainsKey($fact.Name) -or $runtime[$fact.Name] -cne $fact.Value) {
        throw ".NET runtime mismatch for $($fact.Name): expected $($fact.Value), got $($runtime[$fact.Name])"
    }
}
$windowsBuild = [Environment]::OSVersion.Version.ToString()
if ($windowsBuild -cne $manifest.runtime.windows_build) {
    throw "Windows build mismatch: expected $($manifest.runtime.windows_build), got $windowsBuild"
}

$seen = @{}
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$($manifest.runtime.'dotnet.runtime-version')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) { throw "duplicate .NET INI oracle case id: $($case.id)" }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw ".NET INI oracle input escapes workspace: $($case.input)"
    }
    $actual = @(& $dotnet $adapter $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    switch ($case.expected.outcome) {
        'complete' {
            $expected.Add('complete')
            foreach ($entry in $case.expected.entries) {
                if ($entry.Count -ne 2) { throw "invalid .NET INI entry in $($case.id)" }
                $expected.Add("entry`t$($entry[0])`t$($entry[1])")
            }
        }
        'failed' { $expected.Add("failed`t$($case.expected.exception)") }
        default { throw "unknown .NET INI outcome in $($case.id): $($case.expected.outcome)" }
    }
    if (($actual -join "`n") -cne ($expected -join "`n")) {
        throw ".NET INI oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actual -join "`n")"
    }
    $report.Add("case`t$($case.id)`t$($case.expected.outcome)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output ".NET INI differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
