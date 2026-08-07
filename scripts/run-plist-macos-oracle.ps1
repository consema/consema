param(
    [string]$SwiftToolchainPath = '',
    [string]$PlutilPath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\plist-macos-v1\manifest.json'
$driverSource = Join-Path $workspaceRoot 'scripts\oracles\PropertyListOracle.swift'
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'

if (-not $SwiftToolchainPath) {
    $SwiftToolchainPath = '/usr/bin'
}
if (-not $PlutilPath) {
    $PlutilPath = '/usr/bin/plutil'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'plist-macos-v1.tsv'
}

# Allowed skip path: the plist differential gate runs on a pinned macOS
# runner only (RFC 0013 Section 13, plan risk R-15). On any non-macOS host
# the wrapper skips explicitly with exit code 3, recorded in the manifest,
# mirroring how run-hcl-go-oracle.ps1 documents its skip.
if (-not $IsMacOS) {
    Write-Output 'Plist macOS differential: SKIPPED (oracle requires a pinned macOS runner; allowed skip path recorded in conformance/oracles/plist-macos-v1/manifest.json)'
    exit 3
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.plist.macos-differential@1') {
    throw "unexpected Plist macOS oracle suite: $($manifest.suite)"
}

$driverHash = (Get-FileHash -LiteralPath $driverSource -Algorithm SHA256).Hash.ToLowerInvariant()
if ($driverHash -cne $manifest.driver.source_sha256) {
    throw "Plist macOS driver digest mismatch: expected $($manifest.driver.source_sha256), got $driverHash"
}

$swift = Join-Path $SwiftToolchainPath 'swift'
$swiftc = Join-Path $SwiftToolchainPath 'swiftc'
if (-not (Test-Path -LiteralPath $swift) -or -not (Test-Path -LiteralPath $swiftc)) {
    throw "pinned Swift toolchain is missing under $SwiftToolchainPath"
}
if (-not (Test-Path -LiteralPath $PlutilPath)) {
    throw "pinned plutil is missing at $PlutilPath"
}
if (-not (Test-Path -LiteralPath '/usr/bin/sw_vers')) {
    throw 'sw_vers is missing; a pinned macOS host is required'
}
if (-not (Test-Path -LiteralPath '/usr/bin/xcodebuild')) {
    throw 'xcodebuild is missing; the pinned Xcode toolchain is required'
}

# Runtime facts: macOS product version, Xcode version, Swift version must
# match the pins exactly. The Foundation facts reported by the driver
# (os.version, corefoundation.version) are recorded in the report but not
# compared: Apple build numbers are not documented publicly, and the
# product/toolchain versions above pin the platform already.
$macosVersion = (& /usr/bin/sw_vers -productVersion)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$macosVersion = $macosVersion.Trim()
if ($macosVersion -cne $manifest.runtime.'macos.product_version') {
    throw "macOS version mismatch: expected $($manifest.runtime.'macos.product_version'), got $macosVersion"
}

$xcodeLines = @(& /usr/bin/xcodebuild -version)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$xcodeVersion = $xcodeLines[0] -replace '^Xcode\s+', ''
if ($xcodeVersion -cne $manifest.runtime.'xcode.version') {
    throw "Xcode version mismatch: expected $($manifest.runtime.'xcode.version'), got $xcodeVersion"
}

$swiftLines = @(& $swift --version)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$swiftVersion = ($swiftLines[0] -replace '^.*Swift version ', '') -replace '\s+\(.*$', ''
if ($swiftVersion -cne $manifest.runtime.'swift.version') {
    throw "Swift version mismatch: expected $($manifest.runtime.'swift.version'), got $swiftVersion"
}

# Compile the pinned driver once; per-case invocations run the binary.
$driverBin = Join-Path $oracleRoot 'plist-macos-oracle-bin'
& $swiftc -O -warnings-as-errors $driverSource -o $driverBin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$work = Join-Path $oracleRoot 'plist-macos-v1-work'
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Get-SortedLines {
    param([string[]]$Lines)
    return @($Lines | Sort-Object)
}

function Assert-ValuesMultisetEqual {
    param([string]$CaseId, [string[]]$Left, [string[]]$Right)
    $left = Get-SortedLines $Left
    $right = Get-SortedLines $Right
    if (($left -join "`n") -cne ($right -join "`n")) {
        throw "Plist macOS oracle value disagreement for $($CaseId)`nexpected:`n$($left -join "`n")`nactual:`n$($right -join "`n")"
    }
}

function Assert-ValuesExactEqual {
    param([string]$CaseId, [string[]]$Left, [string[]]$Right)
    if (($Left -join "`n") -cne ($Right -join "`n")) {
        throw "Plist macOS driver value disagreement for $($CaseId)`nexpected:`n$($Left -join "`n")`nactual:`n$($Right -join "`n")"
    }
}

$seen = @{}
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("suite`t$($manifest.suite)")
$report.Add("runtime`t$($manifest.runtime.'macos.product_version')`t$($manifest.runtime.'xcode.version')`t$($manifest.runtime.'swift.version')")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) {
        throw "duplicate Plist macOS oracle case id: $($case.id)"
    }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Plist macOS oracle input escapes workspace: $($case.input)"
    }
    $inputHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($inputHash -cne $case.input_sha256) {
        throw "Plist macOS oracle input digest mismatch for $($case.id): expected $($case.input_sha256), got $inputHash"
    }
    if ($case.expected.lint -notin @('ok', 'error')) {
        throw "unknown expected lint outcome in $($case.id): $($case.expected.lint)"
    }
    if ($case.expected.detected_format -notin @('xml1', 'binary1')) {
        throw "unknown expected detected format in $($case.id): $($case.expected.detected_format)"
    }
    if ($case.expected.convert.to_xml1 -notin @('ok', 'error') -or $case.expected.convert.to_binary1 -notin @('ok', 'error')) {
        throw "unknown expected convert outcome in $($case.id)"
    }
    if ($case.expected.values -ne 'ok') {
        throw "unknown expected values outcome in $($case.id): $($case.expected.values)"
    }

    # Lint leg: plutil -lint must agree with the expected outcome and the
    # Swift driver must agree on ok/error and the detected format.
    $plutilLint = @(& $PlutilPath -lint $inputPath)
    $plutilLintOk = ($LASTEXITCODE -eq 0)
    $driverLint = @(& $driverBin lint $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $driverLintOk = ($driverLint[0] -like "lint`tok*")
    if ($case.expected.lint -eq 'ok') {
        if (-not $plutilLintOk -or -not $driverLintOk) {
            throw "Plist macOS oracle lint disagreement for $($case.id): plutil=$($plutilLint -join '; ') driver=$($driverLint -join '; ')"
        }
        if (-not ($driverLint[0] -like "lint`tok`t$($case.expected.detected_format)")) {
            throw "Plist macOS oracle format disagreement for $($case.id): expected $($case.expected.detected_format), got $($driverLint[0])"
        }
    }
    else {
        if ($plutilLintOk -or $driverLintOk) {
            throw "Plist macOS oracle expected lint error for $($case.id), got plutil=$($plutilLint -join '; ') driver=$($driverLint -join '; ')"
        }
    }

    $converted = @{}
    foreach ($direction in @('xml1', 'binary1')) {
        $expected = $case.expected.convert.("to_$direction")
        $outPlutil = Join-Path $work "$($case.id)-to-$direction-plutil.plist"
        $outSwift = Join-Path $work "$($case.id)-to-$direction-swift.plist"
        if (Test-Path -LiteralPath $outPlutil) { Remove-Item -LiteralPath $outPlutil -Force }
        if (Test-Path -LiteralPath $outSwift) { Remove-Item -LiteralPath $outSwift -Force }
        & $PlutilPath -convert $direction -o $outPlutil $inputPath
        $plutilExit = $LASTEXITCODE
        $plutilOk = ($plutilExit -eq 0)
        $driverConvert = @(& $driverBin convert $direction $inputPath $outSwift)
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $driverOk = ($driverConvert[0] -like "convert`tok*")
        if ($expected -eq 'ok') {
            if (-not $plutilOk -or -not $driverOk) {
                throw "Plist macOS oracle convert disagreement for $($case.id) to ${direction}: plutil exit=$plutilExit driver=$($driverConvert -join '; ')"
            }
            # Cross-oracle byte identity: both invoke the same Foundation
            # writer, so the converted bytes must be identical.
            $plutilHash = (Get-FileHash -LiteralPath $outPlutil -Algorithm SHA256).Hash.ToLowerInvariant()
            $swiftHash = (Get-FileHash -LiteralPath $outSwift -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($plutilHash -cne $swiftHash) {
                throw "Plist macOS oracle cross-oracle byte disagreement for $($case.id) to ${direction}: plutil $plutilHash vs driver $swiftHash"
            }
            # Reparse closure: the converted bytes must lint clean again.
            & $PlutilPath -lint $outPlutil | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Plist macOS oracle reparse failure for $($case.id) to $direction"
            }
            if (($driverConvert -join "`n") -notlike "*reparse`tok*") {
                throw "Plist macOS oracle driver reparse failure for $($case.id) to ${direction}: $($driverConvert -join '; ')"
            }
            $converted[$direction] = $outPlutil
        }
        else {
            if ($plutilOk -or $driverOk) {
                throw "Plist macOS oracle expected convert error for $($case.id) to ${direction}, got plutil exit=$plutilExit driver=$($driverConvert -join '; ')"
            }
        }
    }

    # Values leg: plutil -p of the fixture and of every successfully
    # converted file must agree as sorted-line multisets (Foundation does
    # not guarantee NSDictionary iteration order), and the Swift driver's
    # deterministic value dump must agree exactly across the same files.
    $plutilValues = @(& $PlutilPath -p $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $driverValues = @(& $driverBin values $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    foreach ($direction in @('xml1', 'binary1')) {
        if ($converted.ContainsKey($direction)) {
            $convertedValues = @(& $PlutilPath -p $converted[$direction])
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            Assert-ValuesMultisetEqual $case.id $plutilValues $convertedValues
            $driverConverted = @(& $driverBin values $converted[$direction])
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            Assert-ValuesExactEqual $case.id $driverValues $driverConverted
        }
    }

    $report.Add("case`t$($case.id)`t$($case.expected.lint)`t$($case.expected.convert.to_xml1)`t$($case.expected.convert.to_binary1)`t$($case.expected.values)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "Plist macOS differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
