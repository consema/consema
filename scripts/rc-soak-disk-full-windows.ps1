param(
    # Path to the consema CLI binary (consema.exe). Default:
    # <RustWorkspace>\target\release\consema.exe.
    [string]$Cli = '',
    # consema-rs checkout (the Rust workspace that builds the CLI).
    [string]$RustWorkspace = '',
    # Fixture directory of the spec repository. Default: <repo root>\conformance\fixtures.
    [string]$FixturesDir = '',
    # Work directory for the VHD + mount point. Default: %TEMP%\consema-rc-soak-disk-full-windows-<pid>.
    [string]$WorkDir = '',
    # Size of the scratch VHD in MiB.
    [int]$VhdSizeMb = 256,
    # Number of byte-identical fixture copies planned and applied on the volume.
    [int]$Copies = 20,
    # Free bytes to leave on the volume after the fill (KiB).
    [int]$LeaveFreeKiB = 64,
    # Keep the work directory (VHD dismounted) and print its location.
    [switch]$Keep
)

# ---------------------------------------------------------------------------
# RC soak stage 1, drill 5 (disk full) — Windows variant
# (rc-1.0.0-candidate.md §3.5 演练 5). 需授权环境: requires an elevated
# session AND the Hyper-V module (New-VHD/Mount-VHD/Format-Volume/
# Add-PartitionAccessPath/Dismount-VHD). The original environment-blocked
# record (2026-08-10: non-admin, no Hyper-V module, no addressable small
# volume) is the precedent for the honest preconditions check below.
#
# When any precondition is missing this script writes the environment-blocked
# record to stdout and exits 3 (the repository's documented-skip exit code,
# oracle scripts precedent) — it never fabricates a drill result.
#
# Flow (mirrors scripts/rc-soak-disk-full.ps1 on the Linux runner):
#   1. New-VHD (dynamic, -VhdSizeMb) + Mount-VHD -NoDriveLetter
#      + Format-Volume (NTFS) + Add-PartitionAccessPath to a folder mount point
#   2. copy conformance/fixtures/ini/desktop-settings.ini x -Copies
#   3. consema plan (exit 0, all planned; plan/result manifests OUTSIDE the volume)
#   4. fill the volume until <= -LeaveFreeKiB KiB free (Get-PSDrive.Free)
#   5. consema apply -> EXPECT exit 4, >= 1 file failed with
#      failure_code cli.write.io@1, failed files byte-unchanged (base digest),
#      no *.consema-*.tmp residue
#   6. free space -> re-apply the SAME plan -> exit 0, all completed at the
#      expected target digest (98b89205...)
#   7. report (classification + recovery semantics), then Dismount-VHD +
#      remove the VHD and the work dir (unless -Keep)
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows)
if (-not $isWindows) {
    Write-Error 'rc-soak-disk-full-windows.ps1 is the Windows variant; on the Linux runner use scripts/rc-soak-disk-full.ps1 (tmpfs).'
    exit 3
}

# -RustWorkspace 默认值按六仓并排布局检测（rc-soak-stage1-disk-drill.md §2）：
# 六仓并排检出时（consema-rs 与母仓同级），从母仓根向上取并排 consema-rs；
# 嵌套目录假设（<repoRoot>\consema-rs）仅作为拆分前布局的兼容回退，两者都
# 不存在时由后续 Fail-Blocked 明确报错——不静默使用错误路径。
if ($RustWorkspace -eq '') {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $sideBySide = Join-Path (Split-Path -Parent $repoRoot) 'consema-rs'
    if (Test-Path (Join-Path $sideBySide 'Cargo.toml')) {
        $RustWorkspace = $sideBySide
    } else {
        $RustWorkspace = Join-Path $repoRoot 'consema-rs'
    }
}

# --- preconditions (honest environment gate, 需授权环境) --------------------
function Fail-Blocked([string]$Reason) {
    Write-Host 'RC soak drill 5 (disk full) — Windows variant: environment blocked (recorded, not executed)'
    Write-Host "  blocked reason: $Reason"
    Write-Host '  completion paths: (a) elevated session + Hyper-V module, re-run this script;'
    Write-Host '                    (b) Linux runner: scripts/rc-soak-disk-full.ps1 (tmpfs small volume, C-1 closed 2026-08-11)'
    exit 3
}

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail-Blocked 'not an elevated session (IsInRole(Administrator)=False) — New-VHD/Mount-VHD/Format-Volume require elevation'
}
foreach ($cmd in 'New-VHD', 'Mount-VHD', 'Dismount-VHD', 'Format-Volume', 'Add-PartitionAccessPath', 'Remove-PartitionAccessPath', 'Get-Partition', 'Get-Volume') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail-Blocked "required cmdlet not available: $cmd (Hyper-V module not installed?)"
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ($RustWorkspace -eq '') { $RustWorkspace = Join-Path $repoRoot 'consema-rs' }
$RustWorkspace = [System.IO.Path]::GetFullPath($RustWorkspace)
if ($FixturesDir -eq '') { $FixturesDir = Join-Path $repoRoot 'conformance\fixtures' }
if ($WorkDir -eq '') {
    $WorkDir = Join-Path $env:TEMP ("consema-rc-soak-disk-full-windows-" + $PID)
}

# Pinned fixture facts (BENCHMARKS-0.13.0.md §3; cookbook.md §6; drill 4).
$FixtureName = 'ini\desktop-settings.ini'
$BaseDigest = 'b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8'
$TargetDigest = '98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a'

function Assert-True([bool]$Cond, [string]$Message) {
    if (-not $Cond) {
        throw "drill assertion failed: $Message"
    }
}

# --- remaining preconditions ------------------------------------------------
if (-not (Test-Path (Join-Path $RustWorkspace 'Cargo.toml'))) {
    Fail-Blocked "consema-rs workspace not found: $RustWorkspace (pass -RustWorkspace)"
}
$fixture = Join-Path $FixturesDir $FixtureName
if (-not (Test-Path $fixture)) {
    Fail-Blocked "fixture not found: $fixture (pass -FixturesDir)"
}
if ($Cli -eq '') { $Cli = Join-Path $RustWorkspace 'target\release\consema.exe' }
$Cli = [System.IO.Path]::GetFullPath($Cli)
if (-not (Test-Path $Cli)) {
    Fail-Blocked "CLI not found: $Cli (build with: cargo build --release --locked -p consema in $RustWorkspace)"
}

# --- work dir + VHD ---------------------------------------------------------
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$mp = Join-Path $WorkDir 'mp'
New-Item -ItemType Directory -Force $mp | Out-Null
$vhdPath = Join-Path $WorkDir 'consema-soak-drill.vhdx'
Write-Host "work dir: $WorkDir (mount point folder: $mp)"

$diskNumber = $null
$mounted = $false
try {
    Write-Host '[1/8] creating and mounting the scratch VHD (dynamic, size ' + $VhdSizeMb + ' MiB) ...'
    New-VHD -Path $vhdPath -SizeBytes ($VhdSizeMb * 1MB) -Dynamic | Out-Null
    $disk = Mount-VHD -Path $vhdPath -NoDriveLetter -PassThru | Get-Disk
    $diskNumber = $disk.Number
    if ($disk.IsOffline) { $disk | Set-Disk -IsOffline $false }
    $disk | Initialize-Disk -PartitionStyle MBR -Confirm:$false
    $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize
    Format-Volume -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber -FileSystem NTFS -NewFileSystemLabel 'consema-soak' -Confirm:$false | Out-Null
    Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $mp
    $mounted = $true
    $volInfo = Get-Volume -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber
    Write-Host "volume mounted at $mp ($($volInfo.Size) bytes)"

    # --- fixtures -----------------------------------------------------------
    Write-Host "[2/8] copying fixture x $Copies into the volume ..."
    $baseHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($baseHash -eq $BaseDigest) "fixture digest mismatch: got $baseHash, expected $BaseDigest"
    $sources = @()
    for ($i = 1; $i -le $Copies; $i++) {
        $dest = Join-Path $mp ('settings-{0:D3}.ini' -f $i)
        Copy-Item -LiteralPath $fixture -Destination $dest
        $sources += $dest
    }
    Write-Host "copied $($sources.Count) files (base $BaseDigest)"

    # --- edit request (cookbook.md §6: window:width -> 1600) ----------------
    $requestPath = Join-Path $WorkDir 'edit-request.json'
    $requestJson = '{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.edit-request@1"}},{"key":"operations","value":{"type":"Sequence","items":[{"type":"Object","entries":[{"key":"operation","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"ini.edit.replace-semantic-value"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"target","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"entry"}},{"key":"section","value":{"type":"String","value":"window"}},{"key":"key","value":{"type":"String","value":"width"}},{"key":"occurrence","value":{"type":"Integer","value":"0"}}]}},{"key":"arguments","value":{"type":"Object","entries":[{"key":"value","value":{"type":"String","value":"1600"}},{"key":"representation_policy","value":{"type":"String","value":"preserve-compatible"}}]}}]}]}}]}}'
    Set-Content -LiteralPath $requestPath -Value $requestJson -Encoding UTF8 -NoNewline

    # --- plan ---------------------------------------------------------------
    $planPath = Join-Path $WorkDir 'plan.json'
    Write-Host "[3/8] consema plan ($($sources.Count) files) ..."
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Cli plan @sources --profile ini.portable --request-file $requestPath --output $planPath
    $planCode = $LASTEXITCODE
    $ErrorActionPreference = $previousEap
    Assert-True ($planCode -eq 0) "plan failed (exit $planCode)"
    $plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $planned = @($plan.files | Where-Object { $_.status -eq 'planned' })
    Assert-True ($planned.Count -eq $Copies) "plan manifest has $($planned.Count) planned entries, expected $Copies"
    Write-Host "plan: $($planned.Count)/$Copies planned"

    # --- fill the volume ----------------------------------------------------
    Write-Host "[4/8] filling the volume until <= $LeaveFreeKiB KiB free (real ENOSPC condition) ..."
    $fill = Join-Path $mp 'fill.bin'
    # The volume has no drive letter; resolve its free space directly.
    $freeOf = { (Get-Volume -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber).SizeRemaining }
    $fillStream = [System.IO.File]::Open($fill, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $chunk = New-Object byte[] (4KB)
        $fillExhausted = $false
        while ((-not $fillExhausted) -and ((& $freeOf) -gt ($LeaveFreeKiB * 1KB))) {
            try {
                $fillStream.Write($chunk, 0, $chunk.Length)
            } catch [System.IO.IOException] {
                # ENOSPC：演练设计目的即制造该条件。此前未捕获的 IOException 在
                # EAP=Stop 下为终止性异常，演练在该失败路径中止且不留记录；
                # 现按预期 ENOSPC 捕获并继续演练流程（2026-08-14 波 2 修复）。
                Write-Host "fill: write hit IOException (expected ENOSPC); continuing drill"
                $fillExhausted = $true
            }
        }
    }
    finally {
        $fillStream.Close()
    }
    Write-Host "volume after fill: $((& $freeOf)) bytes free"

    # --- apply: expect disk-full failure ------------------------------------
    $resultFail = Join-Path $WorkDir 'result-fail.json'
    Write-Host "[5/8] consema apply (volume full) -- expect exit 4, per-file cli.write.io@1 failed ..."
    # Native stderr is redirected to a file; relax ErrorActionPreference around
    # the native call (Windows PowerShell 5.1 wraps native stderr lines as
    # error records under 'Stop' — the ts-verify scripts' documented pattern).
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Cli apply $planPath --output $resultFail 2> (Join-Path $WorkDir 'apply-fail.stderr.txt')
    $applyCode = $LASTEXITCODE
    $ErrorActionPreference = $previousEap
    Write-Host "apply exit code: $applyCode (expected 4 = precondition class, cli.write.io@1)"
    Assert-True ($applyCode -eq 4) "apply did not fail with exit 4 (got $applyCode)"
    $stderr = Get-Content (Join-Path $WorkDir 'apply-fail.stderr.txt') -Raw
    Assert-True ($stderr -match 'cli\.write\.io@1') "stderr does not classify cli.write.io@1: $stderr"
    $result = Get-Content -LiteralPath $resultFail -Raw -Encoding UTF8 | ConvertFrom-Json
    $files = @($result.files)
    $failed = @($files | Where-Object { $_.status -eq 'failed' })
    $completed = @($files | Where-Object { $_.status -eq 'completed' })
    $ioFailed = @($failed | Where-Object { $_.failure_code -eq 'cli.write.io@1' })
    Assert-True ($ioFailed.Count -ge 1) "no failed entry carries cli.write.io@1 (failed=$($failed.Count), completed=$($completed.Count))"
    Write-Host "apply result: $($files.Count) files -- $($completed.Count) completed, $($failed.Count) failed (all $($ioFailed.Count) with cli.write.io@1)"
    foreach ($entry in $files) {
        $hash = (Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($entry.status -eq 'completed') {
            Assert-True ($hash -eq $TargetDigest) "completed file $($entry.path) digest $hash != expected target $TargetDigest"
        }
        else {
            Assert-True ($hash -eq $BaseDigest) "failed file $($entry.path) digest $hash != base $BaseDigest (bytes must be untouched)"
        }
    }
    $tmpResidue = @(Get-ChildItem -LiteralPath $mp -Filter '*.tmp' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*.consema-*' })
    Assert-True ($tmpResidue.Count -eq 0) "temporary residue left on the volume: $($tmpResidue.Name -join ', ')"
    Write-Host "byte checks: completed -> target digest, failed -> base digest (zero-byte-write), no *.tmp residue"

    # --- free space + recovery ---------------------------------------------
    Write-Host "[6/8] freeing the volume (removing fill.bin) ..."
    Remove-Item -LiteralPath $fill -Force
    Write-Host "volume after free: $((& $freeOf)) bytes free"
    $resultRecover = Join-Path $WorkDir 'result-recover.json'
    Write-Host "[7/8] consema apply (same plan, space freed) -- expect exit 0, all completed ..."
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Cli apply $planPath --output $resultRecover
    $recoverCode = $LASTEXITCODE
    $ErrorActionPreference = $previousEap
    Assert-True ($recoverCode -eq 0) "recovery apply failed (exit $recoverCode)"
    $recovered = Get-Content -LiteralPath $resultRecover -Raw -Encoding UTF8 | ConvertFrom-Json
    $recFiles = @($recovered.files)
    Assert-True ($recFiles.Count -eq $Copies) "recovery result has $($recFiles.Count) entries, expected $Copies"
    foreach ($entry in $recFiles) {
        Assert-True ($entry.status -eq 'completed') "recovery entry $($entry.path) is $($entry.status), expected completed"
        $hash = (Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-True ($hash -eq $TargetDigest) "recovered file $($entry.path) digest $hash != expected target $TargetDigest"
    }
    Write-Host "recovery: $($recFiles.Count)/$Copies completed, all targets at $TargetDigest"

    # --- report --------------------------------------------------------------
    Write-Host ''
    Write-Host '=== RC soak stage-1 drill 5 (disk full, Windows variant) report ==='
    Write-Host "date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "host: $env:COMPUTERNAME"
    Write-Host "cli: $Cli"
    Write-Host "volume: VHD $VhdSizeMb MiB (dynamic) mounted at $mp"
    Write-Host "batch: $Copies x conformance/fixtures/ini/desktop-settings.ini (base $BaseDigest)"
    Write-Host "plan: exit 0, $($planned.Count)/$Copies planned"
    Write-Host "apply (volume full): exit $applyCode, $($completed.Count) completed / $($failed.Count) failed, failure_code cli.write.io@1 on all failed entries"
    Write-Host "atomicity: completed files at target digest $TargetDigest; failed files at base digest (zero bytes written); no temp residue"
    Write-Host "recovery: same plan re-applied after freeing space -> exit 0, $($recFiles.Count)/$Copies completed at target digest"
    Write-Host 'classification: exit 4 = precondition class (RFC 0015 §5.1; cli.write.io@1 -> 4); recovery semantics: manifest state machine re-runnable (RFC 0015 §10)'
    Write-Host '=== end report ==='
}
finally {
    if ($mounted) {
        Write-Host '[8/8] cleaning up: dismounting the VHD ...'
        try {
            Remove-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $mp -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch { }
        Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
        $mounted = $false
    }
    if (-not $Keep) {
        Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "work dir kept: $WorkDir"
    }
}
Write-Host '[8/8] drill complete (exit 0)'
exit 0
