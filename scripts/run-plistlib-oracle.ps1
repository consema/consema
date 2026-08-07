param(
    [string]$PythonHome = '',
    [string]$PackagePath = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $workspaceRoot 'conformance\oracles\plist-macos-v1\manifest.json'
$oracleRoot = Join-Path $workspaceRoot 'target\oracles'

if (-not $PythonHome) {
    $PythonHome = Join-Path $oracleRoot 'python-3.14.6'
}
if (-not $PackagePath) {
    $PackagePath = Join-Path $oracleRoot 'python-3.14.6-embeddable-amd64.zip'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $oracleRoot 'plistlib-v1.tsv'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.suite -cne 'consema.plist.macos-differential@1') {
    throw "unexpected Plist oracle suite: $($manifest.suite)"
}

$packageHash = (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($packageHash -cne $manifest.plistlib.package.sha256) {
    throw "CPython package digest mismatch: expected $($manifest.plistlib.package.sha256), got $packageHash"
}

# The plistlib adapter is repository-embedded in this script (the M10 file
# domain carries no separate adapter file) and digest-pinned in the manifest.
# Verify the embedded text, write it to the oracle target directory, and
# re-verify the written file so the executed bytes are pinned exactly.
$adapterSource = @'
"""Consema's repository-owned CPython plistlib structural cross-check adapter.

Secondary alignment runner for the plist differential gate
(docs/plist-implementation-plan.md 6.3 and M10; RFC 0013 13).
plistlib is explicitly NOT the semantic authority: this adapter performs a
structural cross-check only (profile detection plus a deterministic typed
value dump). Its three-way divergences from Foundation (UID upper bound,
0x0F fill byte, extended-size marker) are recorded in
conformance/oracles/plist-macos-v1/manifest.json as exclusion D-19.
"""

from __future__ import annotations

import datetime
import hashlib
import plistlib
import platform
import struct
import sys
from pathlib import Path

_EPOCH = datetime.datetime(2001, 1, 1)


def transport(text: str) -> str:
    return text.encode("utf-8").hex()


def bits_double(value: float) -> str:
    return struct.pack(">d", value).hex()


def dump(value: object, lines: list[str]) -> None:
    if isinstance(value, bool):
        lines.append("v\tbool\t" + ("true" if value else "false"))
    elif isinstance(value, int):
        lines.append("v\tinteger\t" + str(value))
    elif isinstance(value, float):
        lines.append("v\treal\t" + bits_double(value))
    elif isinstance(value, str):
        lines.append("v\tstring\t" + transport(value))
    elif isinstance(value, bytes):
        lines.append("v\tdata\t" + value.hex())
    elif isinstance(value, datetime.datetime):
        seconds = (value - _EPOCH).total_seconds()
        lines.append("v\tdate\t" + bits_double(seconds))
    elif isinstance(value, plistlib.UID):
        lines.append("v\tuid\t" + str(value.data))
    elif isinstance(value, list):
        lines.append("v\tarray\t" + str(len(value)))
        for element in value:
            dump(element, lines)
    elif isinstance(value, dict):
        lines.append("v\tdict\t" + str(len(value)))
        for key in sorted(value):
            lines.append("k\t" + transport(key))
            dump(value[key], lines)
    else:
        raise ValueError("unhandled plistlib value: " + type(value).__name__)


def runtime_facts() -> None:
    print("python.implementation\t" + platform.python_implementation())
    print("python.version\t" + platform.python_version())
    print("python.compiler\t" + platform.python_compiler())
    print("os.name\t" + platform.system())
    print("os.release\t" + platform.release())
    print("os.machine\t" + platform.machine())


def run_case(path: Path) -> None:
    source = path.read_bytes()
    print("input-sha256\t" + hashlib.sha256(source).hexdigest())
    try:
        parsed = plistlib.loads(source)
    except plistlib.InvalidFileException as error:
        print("failed\t" + type(error).__module__ + "." + type(error).__name__)
        return
    profile = "binary1" if source.startswith(b"bplist") else "xml1"
    print("outcome\tok")
    print("profile\t" + profile)
    lines = []
    dump(parsed, lines)
    canonical = "\n".join(lines) + "\n"
    print("value-sha256\t" + hashlib.sha256(canonical.encode("utf-8")).hexdigest())
    for line in lines:
        print(line)


def main() -> None:
    if sys.argv[1:] == ["--runtime"]:
        runtime_facts()
        return
    if len(sys.argv) != 2:
        raise SystemExit("usage: plistlib_oracle.py <input> | --runtime")
    run_case(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
'@
$adapterBytes = [Text.Encoding]::UTF8.GetBytes($adapterSource)
$embeddedHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($adapterBytes)).Replace('-', '').ToLowerInvariant()
if ($embeddedHash -cne $manifest.plistlib.adapter.embedded_sha256) {
    throw "plistlib adapter digest mismatch: expected $($manifest.plistlib.adapter.embedded_sha256), got $embeddedHash"
}
$adapterPath = Join-Path $oracleRoot 'plistlib_oracle.py'
[IO.File]::WriteAllText($adapterPath, $adapterSource, [Text.UTF8Encoding]::new($false))
$adapterHash = (Get-FileHash -LiteralPath $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($adapterHash -cne $manifest.plistlib.adapter.embedded_sha256) {
    throw "written plistlib adapter digest mismatch: expected $($manifest.plistlib.adapter.embedded_sha256), got $adapterHash"
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
foreach ($fact in $manifest.plistlib.python.PSObject.Properties) {
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
$report.Add("runtime`t$($manifest.plistlib.python.'python.version')`t$windowsBuild")
foreach ($case in $manifest.cases) {
    if ($seen.ContainsKey($case.id)) {
        throw "duplicate Plist oracle case id: $($case.id)"
    }
    $seen[$case.id] = $true
    $inputPath = [IO.Path]::GetFullPath((Join-Path $workspaceRoot $case.input))
    if (-not $inputPath.StartsWith($workspaceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Plist oracle input escapes workspace: $($case.input)"
    }

    $actual = @(& $python -I $adapterPath $inputPath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $actualLines = @($actual | Select-Object -First 4)
    $expected = [System.Collections.Generic.List[string]]::new()
    $expected.Add("input-sha256`t$($case.input_sha256)")
    switch ($case.expected.plistlib.outcome) {
        'ok' {
            $expected.Add("outcome`tok")
            switch ($case.expected.plistlib.profile) {
                'plist.xml@1' { $expected.Add("profile`txml1") }
                'plist.binary@1' { $expected.Add("profile`tbinary1") }
                default { throw "unknown expected plistlib profile in $($case.id): $($case.expected.plistlib.profile)" }
            }
            $expected.Add("value-sha256`t$($case.expected.plistlib.value_sha256)")
        }
        'failed' {
            $expected.Add("failed`t$($case.expected.plistlib.exception)")
        }
        default {
            throw "unknown expected plistlib outcome in $($case.id): $($case.expected.plistlib.outcome)"
        }
    }
    if (($actualLines -join "`n") -cne ($expected -join "`n")) {
        throw "plistlib oracle disagreement for $($case.id)`nexpected:`n$($expected -join "`n")`nactual:`n$($actualLines -join "`n")"
    }
    $report.Add("case`t$($case.id)`tplistlib`t$($case.expected.plistlib.outcome)`t$($case.input_sha256)")
    Write-Output "PASS $($case.id)"
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
[IO.File]::WriteAllLines($ReportPath, $report, [Text.UTF8Encoding]::new($false))
Write-Output "plistlib differential: $($manifest.cases.Count)/$($manifest.cases.Count)"
Write-Output "Report: $ReportPath"
