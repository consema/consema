param(
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$oracleRoot = [IO.Path]::GetFullPath((Join-Path $workspaceRoot 'target\oracles'))
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\windows-ini-v1\manifest.json'
$adapterPath = Join-Path $workspaceRoot 'scripts\oracles\WindowsIniOracle.cs'
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'windows-ini-v1.tsv'
}

function Convert-Hex([string]$value) {
    $digits = -join ($value.ToCharArray() | Where-Object { -not [char]::IsWhiteSpace($_) })
    if (($digits.Length % 2) -ne 0) { throw 'hex input has an odd digit count' }
    $bytes = New-Object byte[] ($digits.Length / 2)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        $pair = $digits.Substring($index * 2, 2)
        if ($pair -cnotmatch '^[0-9a-f]{2}$') { throw 'hex input is not canonical lowercase' }
        $bytes[$index] = [Convert]::ToByte($pair, 16)
    }
    return $bytes
}

function ConvertTo-Utf16Hex([string]$value) {
    return [BitConverter]::ToString([Text.Encoding]::BigEndianUnicode.GetBytes($value)).Replace('-', '').ToLowerInvariant()
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -ne 'consema.ini.windows-wide-api-differential@1') {
    throw "unexpected Windows INI oracle suite: $($manifest.suite)"
}
$windowsBuild = [Environment]::OSVersion.Version.ToString()
if ($windowsBuild -cne $manifest.authority.windows_build) {
    # Allowed skip path (2026-08-14 波 2，对照 run-hcl-go-oracle.ps1 体例)：
    # build 不匹配（hosted runner 10.0.26100 vs pinned 10.0.26200.0）此前无条件
    # throw，使该 oracle 在任何 hosted runner 上不可执行；现按 documented skip
    # （exit 3）处理。注（2026-08-15 波 4）：本 manifest（windows-ini-v1）不含
    # skip_path 记录——七份 oracle manifest 中仅 hcl-go-v1 与 plist-macos-v1
    # 携带 skip_path；此 skip 是 runtime 约束检查的常设属性，不声称记录于
    # manifest。
    Write-Output "Windows INI oracle: SKIPPED (Windows build mismatch: expected $($manifest.authority.windows_build), got $windowsBuild; documented skip (exit 3) — runtime-constraint check, not a manifest skip_path record)"
    exit 3
}
$kernelPath = Join-Path ([Environment]::SystemDirectory) 'kernel32.dll'
$kernelVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($kernelPath).FileVersion
$kernelHash = (Get-FileHash -LiteralPath $kernelPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($kernelVersion -cne $manifest.authority.module_file_version -or $kernelHash -cne $manifest.authority.module_sha256) {
    throw "kernel32 authority mismatch: version=$kernelVersion sha256=$kernelHash"
}
$adapterHash = (Get-FileHash -LiteralPath $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($adapterHash -cne $manifest.adapter.source_sha256) {
    throw "Windows INI adapter digest mismatch: expected $($manifest.adapter.source_sha256), got $adapterHash"
}

$compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
$compilerParameters.TreatWarningsAsErrors = $true
$compilerParameters.WarningLevel = 4
Add-Type -Path $adapterPath -CompilerParameters $compilerParameters
$caseRoot = Join-Path $oracleRoot ('windows-ini-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $caseRoot | Out-Null
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$windowsBuild`t$kernelVersion`t$kernelHash")
$seen = @{}
try {
    foreach ($case in $manifest.cases) {
        if ($seen.ContainsKey($case.id)) { throw "duplicate Windows INI oracle case id: $($case.id)" }
        $seen[$case.id] = $true
        $containerPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
        if (-not $containerPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Windows INI oracle input escapes workspace: $($case.input)"
        }
        $bytes = Convert-Hex (Get-Content -LiteralPath $containerPath -Raw -Encoding ascii)
        $inputPath = Join-Path $caseRoot ([Guid]::NewGuid().ToString('N') + '.ini')
        [IO.File]::WriteAllBytes($inputPath, $bytes)
        $digest = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($digest -cne $case.input_sha256) {
            throw "Windows INI input digest mismatch for $($case.id): $digest"
        }

        foreach ($query in $case.queries) {
            switch ($query.kind) {
                'value' {
                    $actual = ConvertTo-Utf16Hex ([Consema.Oracle.WindowsIniOracle]::ReadValue(
                        $inputPath, $query.section, $query.key, $query.default))
                    if ($actual -cne $query.utf16be_hex) {
                        throw "Windows INI value disagreement for $($case.id): expected $($query.utf16be_hex), got $actual"
                    }
                }
                'sections' {
                    $actual = @([Consema.Oracle.WindowsIniOracle]::ReadSections($inputPath) | ForEach-Object { ConvertTo-Utf16Hex $_ })
                    if (($actual -join ',') -cne (@($query.utf16be_hex) -join ',')) {
                        throw "Windows INI section disagreement for $($case.id)"
                    }
                }
                'keys' {
                    $actual = @([Consema.Oracle.WindowsIniOracle]::ReadKeys($inputPath, $query.section) | ForEach-Object { ConvertTo-Utf16Hex $_ })
                    if (($actual -join ',') -cne (@($query.utf16be_hex) -join ',')) {
                        throw "Windows INI key disagreement for $($case.id)"
                    }
                }
                default { throw "unknown Windows INI query kind: $($query.kind)" }
            }
        }
        $report.Add("case`t$($case.id)`t$($case.queries.Count)`t$digest")
        Write-Output "PASS $($case.id)"
    }
} finally {
    $resolvedCaseRoot = [IO.Path]::GetFullPath($caseRoot)
    if (-not $resolvedCaseRoot.StartsWith($oracleRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing unsafe Windows INI cleanup target: $resolvedCaseRoot"
    }
    if (Test-Path -LiteralPath $resolvedCaseRoot) {
        Remove-Item -LiteralPath $resolvedCaseRoot -Recurse -Force
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "Windows INI differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
