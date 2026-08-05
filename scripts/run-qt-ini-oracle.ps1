param(
    [string]$QtHome = '',
    [string]$CompilerHome = '',
    [string]$QtPackagePath = '',
    [string]$CompilerPackagePath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\qt-ini-v1\manifest.json'
$adapterPath = Join-Path $workspaceRoot 'scripts\oracles\QtIniOracle.cpp'
$workRoot = Join-Path $oracleRoot 'qt-ini-official-work'

if (-not $QtHome) { $QtHome = Join-Path $oracleRoot 'qt-6.10.2' }
if (-not $CompilerHome) {
    $CompilerHome = Join-Path $oracleRoot 'qt-mingw-13.1.0\Tools\mingw1310_64'
}
if (-not $QtPackagePath) {
    $QtPackagePath = Join-Path $oracleRoot '6.10.2-0-202601261212qtbase-Windows-Windows_11_24H2-Mingw-Windows-Windows_11_24H2-X86_64.7z'
}
if (-not $CompilerPackagePath) {
    $CompilerPackagePath = Join-Path $oracleRoot '13.1.0-202407240918mingw1310.7z'
}
if (-not $ReportPath) { $ReportPath = Join-Path $oracleRoot 'qt-ini-v1.tsv' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.ini.qt610-portable-differential@1') {
    throw "unexpected Qt oracle suite: $($manifest.suite)"
}

function Assert-FileHash([string]$Path, [string]$Algorithm, [string]$Expected, [string]$Label) {
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    if ($actual -cne $Expected) {
        throw "$Label digest mismatch: expected $Expected, got $actual"
    }
}

Assert-FileHash $QtPackagePath SHA1 $manifest.authority.package_sha1 'Qt package SHA-1'
Assert-FileHash $QtPackagePath SHA256 $manifest.authority.package_sha256 'Qt package SHA-256'
Assert-FileHash $CompilerPackagePath SHA1 $manifest.compiler.package_sha1 'MinGW package SHA-1'
Assert-FileHash $CompilerPackagePath SHA256 $manifest.compiler.package_sha256 'MinGW package SHA-256'
Assert-FileHash $adapterPath SHA256 $manifest.adapter.source_sha256 'Qt adapter'

$compiler = Join-Path $CompilerHome 'bin\g++.exe'
$qtCore = Join-Path $QtHome 'bin\Qt6Core.dll'
Assert-FileHash $compiler SHA256 $manifest.compiler.executable_sha256 'MinGW compiler'
Assert-FileHash $qtCore SHA256 $manifest.authority.qt6core_sha256 'Qt6Core'
$versionLine = @(& $compiler --version)[0]
if ($versionLine -cne $manifest.compiler.version_line) {
    throw "MinGW version mismatch: expected $($manifest.compiler.version_line), got $versionLine"
}

New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
$executable = Join-Path $workRoot 'QtIniOracle.exe'
$compileArguments = @(
    '-std=c++20', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
    '-DUNICODE', '-D_UNICODE',
    '-I', (Join-Path $QtHome 'include'),
    '-I', (Join-Path $QtHome 'include\QtCore'),
    $adapterPath,
    '-L', (Join-Path $QtHome 'lib'),
    '-lQt6Core',
    '-o', $executable
)
& $compiler @compileArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:Path = (Join-Path $QtHome 'bin') + ';' + (Join-Path $CompilerHome 'bin') + ';' + $env:Path

$runtimeLines = @(& $executable --runtime)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtime = @{}
foreach ($line in $runtimeLines) {
    $parts = $line -split "`t", 2
    if ($parts.Count -ne 2 -or $runtime.ContainsKey($parts[0])) {
        throw "invalid or duplicate Qt runtime fact: $line"
    }
    $runtime[$parts[0]] = $parts[1]
}
foreach ($fact in $manifest.runtime.PSObject.Properties) {
    if ($fact.Name -eq 'windows_build') { continue }
    if (-not $runtime.ContainsKey($fact.Name) -or $runtime[$fact.Name] -cne $fact.Value) {
        throw "Qt runtime mismatch for $($fact.Name): expected $($fact.Value), got $($runtime[$fact.Name])"
    }
}
$windowsBuild = [Environment]::OSVersion.Version.ToString()
if ($windowsBuild -cne $manifest.runtime.windows_build) {
    throw "Windows build mismatch: expected $($manifest.runtime.windows_build), got $windowsBuild"
}

$seen = @{}
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$($manifest.runtime.'qt.version')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) { throw "duplicate Qt oracle case id: $($case.id)" }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Qt oracle input escapes workspace: $($case.input)"
    }
    $actual = @(& $executable $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($case.expected.outcome -cne 'complete') {
        throw "unknown Qt oracle outcome in $($case.id): $($case.expected.outcome)"
    }
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    $expected.Add('complete')
    foreach ($entry in $case.expected.entries) {
        if ($entry.Count -ne 2) { throw "invalid Qt entry in $($case.id)" }
        $expected.Add("entry`t$($entry[0])`t$($entry[1])")
    }
    if (($actual -join "`n") -cne ($expected -join "`n")) {
        throw "Qt oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actual -join "`n")"
    }
    $report.Add("case`t$($case.id)`tcomplete`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "Qt INI differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
