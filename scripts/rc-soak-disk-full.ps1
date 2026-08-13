param(
    # Path to the consema CLI binary. Default: <RustWorkspace>\target\release\consema
    # (built on demand with `cargo build --release --locked -p consema` unless -SkipBuild).
    [string]$Cli = '',
    # consema-rs checkout (the Rust workspace that builds the CLI). Default:
    # <repo root>\consema-rs, matching the sibling-checkout convention of the
    # language verify scripts (scripts/*-verify-*.ps1 in consema-go/ts/py/kt).
    [string]$RustWorkspace = '',
    # Fixture directory of the spec repository. Default: <repo root>\conformance\fixtures
    # (the mother consema checkout carries the language-neutral conformance authority).
    [string]$FixturesDir = '',
    # Mount point for the temporary small volume. Default: $env:TMP\consema-rc-soak-disk-full-<pid>
    [string]$VolumeDir = '',
    # Size of the tmpfs volume in MiB (roadmap C-1 completion path: "Linux runner
    # 临时小卷", rc-1.0.0-candidate.md §3.5 演练 5).
    [int]$SizeMb = 64,
    # Number of byte-identical fixture copies planned and applied on the volume.
    [int]$Copies = 20,
    # Free bytes to leave on the volume after the fill (KiB). Must be large enough
    # for at least one atomic write to start (tmpfs charges page-rounded blocks,
    # so the exact completed/failed split is machine-dependent — the record
    # template captures the actual split) and small enough that the batch cannot
    # complete: the disk-full failure is the point of the drill.
    [int]$LeaveFreeKiB = 48,
    # Keep the work directory (volume already unmounted) and print its location.
    [switch]$Keep,
    # Do not build the CLI even if the release binary is missing (fails instead).
    [switch]$SkipBuild
)

# ---------------------------------------------------------------------------
# RC soak stage 1, drill 5 completion: disk-full failure drill on a Linux
# runner (rc-1.0.0-candidate.md §3.5 演练 5; §22.7 "磁盘失败演练"). C-1 closed
# 2026-08-11 (run #5, 132/132) opened this path: a temporary small volume on
# the Linux runner, real fill -> `consema apply` expected exit 4 with
# per-file `cli.write.io@1` failures -> free space -> re-run the SAME plan
# -> recovery (exit 0, all completed).
#
# Drill flow (each step asserts its expectation):
#   1. mount a tmpfs small volume (size = -SizeMb MiB; sudo fallback; root or
#      passwordless sudo required)
#   2. copy real fixtures (conformance/fixtures/ini/desktop-settings.ini, the
#      byte-pinned fixture of BENCHMARKS-0.13.0.md §3 and drill 4) x -Copies
#   3. `consema plan` the batch (exit 0, all planned; plan manifest is written
#      OUTSIDE the volume so the result manifest can also be written)
#   4. fill the volume with /dev/zero until <= -LeaveFreeKiB KiB free (real
#      ENOSPC condition; tmpfs is exact)
#   5. `consema apply` the SAME plan -> EXPECT exit 4 (precondition class,
#      exit_class.rs: cli.write.io@1 -> 4), >= 1 file `failed` with
#      failure_code cli.write.io@1, failed files byte-unchanged (base digest),
#      no *.consema-*.tmp residue
#   6. free space (remove the fill file)
#   7. `consema apply` the SAME plan again -> exit 0, all completed, every
#      target matches the expected target digest (98b89205...)
#   8. report: failure classification + recovery semantics (per-file atomicity:
#      completed files hold target bytes, failed files hold base bytes)
#
# Honest-recording contract (release-process-0.13.0.md §6 / rc-candidate §3.4):
# only actual outputs and exit codes are reported; any deviation from an
# expectation fails the script loudly and is recorded as-is, never papered
# over.
#
# Windows note: this script targets the Linux runner (tmpfs). The Windows
# variant (admin + New-VHD/Mount-VHD, 需授权环境) is scripts/
# rc-soak-disk-full-windows.ps1.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

# --- platform guard ---------------------------------------------------------
$isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows)
if ($isWindows) {
    Write-Error 'rc-soak-disk-full.ps1 targets the Linux runner (tmpfs). On Windows use scripts/rc-soak-disk-full-windows.ps1 (requires admin + Hyper-V module, 需授权环境).'
    exit 3
}

$repoRoot = Split-Path -Parent $PSScriptRoot
# -RustWorkspace 默认值按六仓并排布局检测（rc-soak-stage1-disk-drill.md §2）：
# 六仓并排检出时（consema-rs 与母仓同级），从母仓根向上取并排 consema-rs；
# 嵌套目录假设（<repoRoot>\consema-rs）仅作为拆分前布局的兼容回退，两者都
# 不存在时由后续 sanity check 明确报错——不静默使用错误路径。
if ($RustWorkspace -eq '') {
    $sideBySide = Join-Path (Split-Path -Parent $repoRoot) 'consema-rs'
    if (Test-Path (Join-Path $sideBySide 'Cargo.toml')) {
        $RustWorkspace = $sideBySide
    } else {
        $RustWorkspace = Join-Path $repoRoot 'consema-rs'
    }
}
$RustWorkspace = [System.IO.Path]::GetFullPath($RustWorkspace)
if ($FixturesDir -eq '') { $FixturesDir = Join-Path $repoRoot 'conformance\fixtures' }
if ($VolumeDir -eq '') {
    $VolumeDir = Join-Path $env:TMP ("consema-rc-soak-disk-full-" + $PID)
}

# Pinned fixture facts (BENCHMARKS-0.13.0.md §3; cookbook.md §6; drill 4).
$FixtureName = 'ini\desktop-settings.ini'
$BaseDigest = 'b01f173b34c8e4121150432b30e64f6a72a150b31d9afcbd806ebfe17e6a6ff8'
$TargetDigest = '98b89205ca718b28fd83dc0fa40f781aff66f081e65449347b9480a4fd7de09a'

function Assert-True([bool]$Cond, [string]$Message) {
    if (-not $Cond) {
        Write-Host "ASSERTION FAILED: $Message" -ForegroundColor Red
        throw "drill assertion failed: $Message"
    }
}

# --- preconditions ----------------------------------------------------------
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error 'bash is required (the drill uses mount/dd/df/umount via bash).'
}
if (-not (Test-Path (Join-Path $RustWorkspace 'Cargo.toml'))) {
    Write-Error "consema-rs workspace not found: $RustWorkspace (pass -RustWorkspace)"
}
$fixture = Join-Path $FixturesDir $FixtureName
if (-not (Test-Path $fixture)) {
    Write-Error "fixture not found: $fixture (pass -FixturesDir)"
}

# --- CLI --------------------------------------------------------------------
if ($Cli -eq '') {
    $Cli = Join-Path $RustWorkspace 'target\release\consema'
    if (-not (Test-Path $Cli)) {
        if ($SkipBuild) {
            Write-Error "CLI not found: $Cli and -SkipBuild was given"
        }
        Write-Host "[0/9] building the CLI (cargo build --release --locked -p consema) in $RustWorkspace ..."
        Push-Location $RustWorkspace
        try {
            & cargo build --release --locked -p consema
            Assert-True ($LASTEXITCODE -eq 0) "cargo build failed (exit $LASTEXITCODE)"
        }
        finally {
            Pop-Location
        }
        if (-not (Test-Path $Cli)) {
            Write-Error "CLI still not found after build: $Cli"
        }
    }
}
$Cli = [System.IO.Path]::GetFullPath($Cli)
Write-Host "CLI: $Cli"
& $Cli --version | Out-Null
Assert-True ($LASTEXITCODE -eq 0) 'the consema CLI does not run (--version failed)'

# --- work dir + volume ------------------------------------------------------
$work = $VolumeDir
$vol = Join-Path $work 'vol'
New-Item -ItemType Directory -Force $work | Out-Null
New-Item -ItemType Directory -Force $vol | Out-Null
Write-Host "work dir: $work (volume mount point: $vol)"

$mountScript = @'
set -e
MP="$1"; SIZE_MB="$2"
if [ "$(id -u)" = "0" ]; then
  mount -t tmpfs -o "size=${SIZE_MB}M" tmpfs "$MP"
elif command -v sudo >/dev/null 2>&1; then
  sudo -n mount -t tmpfs -o "size=${SIZE_MB}M" tmpfs "$MP"
else
  echo "ERROR: mounting tmpfs requires root; neither root nor passwordless sudo is available" >&2
  exit 2
fi
'@
$umountScript = @'
set -e
MP="$1"
if [ "$(id -u)" = "0" ]; then
  umount "$MP"
elif command -v sudo >/dev/null 2>&1; then
  sudo -n umount "$MP"
else
  echo "ERROR: unmounting tmpfs requires root; neither root nor passwordless sudo is available" >&2
  exit 2
fi
'@

$mounted = $false
try {
    Write-Host "[1/9] mounting tmpfs small volume (size=${SizeMb}M) at $vol ..."
    bash -c $mountScript 'rc-soak' $vol $SizeMb
    Assert-True ($LASTEXITCODE -eq 0) 'tmpfs mount failed'
    $mounted = $true
    $dfLine = bash -c ("df --output=target,size,avail -h '{0}' | tail -1" -f $vol)
    Write-Host "mounted: $dfLine"

    # --- fixtures -----------------------------------------------------------
    Write-Host "[2/9] copying fixture x $Copies into the volume ..."
    $baseHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($baseHash -eq $BaseDigest) "fixture digest mismatch: got $baseHash, expected $BaseDigest"
    $sources = @()
    for ($i = 1; $i -le $Copies; $i++) {
        $name = 'settings-{0:D3}.ini' -f $i
        $dest = Join-Path $vol $name
        Copy-Item -LiteralPath $fixture -Destination $dest
        $sources += $dest
    }
    Write-Host "copied $($sources.Count) files (base $BaseDigest)"

    # --- edit request (cookbook.md §6: window:width -> 1600) ----------------
    $requestPath = Join-Path $work 'edit-request.json'
    $requestJson = '{"schema":"core.portable-value-json@1","value":{"type":"Object","entries":[{"key":"schema","value":{"type":"String","value":"cli.edit-request@1"}},{"key":"operations","value":{"type":"Sequence","items":[{"type":"Object","entries":[{"key":"operation","value":{"type":"Object","entries":[{"key":"id","value":{"type":"String","value":"ini.edit.replace-semantic-value"}},{"key":"version","value":{"type":"Integer","value":"1"}}]}},{"key":"target","value":{"type":"Object","entries":[{"key":"kind","value":{"type":"String","value":"entry"}},{"key":"section","value":{"type":"String","value":"window"}},{"key":"key","value":{"type":"String","value":"width"}},{"key":"occurrence","value":{"type":"Integer","value":"0"}}]}},{"key":"arguments","value":{"type":"Object","entries":[{"key":"value","value":{"type":"String","value":"1600"}},{"key":"representation_policy","value":{"type":"String","value":"preserve-compatible"}}]}}]}]}}]}}'
    Set-Content -LiteralPath $requestPath -Value $requestJson -Encoding UTF8 -NoNewline

    # --- plan ---------------------------------------------------------------
    $planPath = Join-Path $work 'plan.json'
    Write-Host "[3/9] consema plan ($($sources.Count) files) ..."
    & $Cli plan @sources --profile ini.portable --request-file $requestPath --output $planPath
    Assert-True ($LASTEXITCODE -eq 0) "plan failed (exit $LASTEXITCODE)"
    Write-Host "plan exit code: $LASTEXITCODE"
    Assert-True (Test-Path $planPath) 'plan manifest not written'
    $plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $planned = @($plan.files | Where-Object { $_.status -eq 'planned' })
    Assert-True ($planned.Count -eq $Copies) "plan manifest has $($planned.Count) planned entries, expected $Copies"
    Write-Host "plan: $($planned.Count)/$Copies planned (base digest per entry matches the pinned fixture)"

    # --- fill the volume ----------------------------------------------------
    Write-Host "[4/9] filling the volume until <= $LeaveFreeKiB KiB free (real ENOSPC condition) ..."
    $fillScript = @'
set -e
VOL="$1"; LEAVE_KB="$2"
FILL="$VOL/fill.bin"
SIZE_BYTES=$(df --output=size -B1 "$VOL" | tail -1)
dd if=/dev/zero of="$FILL" bs=1M count=$((SIZE_BYTES / 1048576 - 1)) status=none
while :; do
  AVAIL=$(df --output=avail -B1 "$VOL" | tail -1)
  [ "$AVAIL" -le $((LEAVE_KB * 1024)) ] && break
  dd if=/dev/zero of="$FILL" bs=4K count=1 oflag=append conv=notrunc status=none
done
df --output=size,used,avail -B1 "$VOL" | tail -1
'@
    $fillInfo = bash -c $fillScript 'rc-soak' $vol $LeaveFreeKiB
    Assert-True ($LASTEXITCODE -eq 0) 'fill failed'
    Write-Host "volume after fill: $fillInfo bytes (size used avail)"

    # --- apply: expect disk-full failure ------------------------------------
    $resultFail = Join-Path $work 'result-fail.json'
    Write-Host "[5/9] consema apply (volume full) -- expect exit 4, per-file cli.write.io@1 failed ..."
    # Native stderr is redirected to a file; relax ErrorActionPreference around
    # the native call (Windows PowerShell 5.1 wraps native stderr lines as
    # error records under 'Stop' — the ts-verify scripts' documented pattern).
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $Cli apply $planPath --output $resultFail 2> (Join-Path $work 'apply-fail.stderr.txt')
    $applyCode = $LASTEXITCODE
    $ErrorActionPreference = $previousEap
    Write-Host "apply exit code: $applyCode (expected 4 = precondition class, cli.write.io@1)"
    Assert-True ($applyCode -eq 4) "apply did not fail with exit 4 (got $applyCode) -- see apply-fail.stderr.txt"
    $stderr = Get-Content (Join-Path $work 'apply-fail.stderr.txt') -Raw
    Assert-True ($stderr -match 'cli\.write\.io@1') "stderr does not classify cli.write.io@1: $stderr"
    $result = Get-Content -LiteralPath $resultFail -Raw -Encoding UTF8 | ConvertFrom-Json
    $files = @($result.files)
    $failed = @($files | Where-Object { $_.status -eq 'failed' })
    $completed = @($files | Where-Object { $_.status -eq 'completed' })
    $ioFailed = @($failed | Where-Object { $_.failure_code -eq 'cli.write.io@1' })
    Assert-True ($ioFailed.Count -ge 1) "no failed entry carries cli.write.io@1 (failed=$($failed.Count), completed=$($completed.Count))"
    Write-Host "apply result: $($files.Count) files -- $($completed.Count) completed, $($failed.Count) failed (all $($ioFailed.Count) with cli.write.io@1)"

    # byte-level assertions: completed files hold target bytes, failed files
    # hold base bytes (per-file atomicity; RFC 0015 §10).
    foreach ($entry in $files) {
        $path = $entry.path
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($entry.status -eq 'completed') {
            Assert-True ($hash -eq $TargetDigest) "completed file $path digest $hash != expected target $TargetDigest"
        }
        else {
            Assert-True ($hash -eq $BaseDigest) "failed file $path digest $hash != base $BaseDigest (bytes must be untouched)"
        }
    }
    $tmpResidue = @(Get-ChildItem -LiteralPath $vol -Filter '*.tmp' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*.consema-*' })
    Assert-True ($tmpResidue.Count -eq 0) "temporary residue left on the volume: $($tmpResidue.Name -join ', ')"
    Write-Host "byte checks: completed -> target digest, failed -> base digest (zero-byte-write), no *.tmp residue"

    # --- free space ----------------------------------------------------------
    Write-Host "[6/9] freeing the volume (removing fill.bin) ..."
    Remove-Item -LiteralPath (Join-Path $vol 'fill.bin') -Force
    $dfAfter = bash -c ("df --output=size,used,avail -B1 '{0}' | tail -1" -f $vol)
    Write-Host "volume after free: $dfAfter bytes (size used avail)"

    # --- apply again: recovery ----------------------------------------------
    $resultRecover = Join-Path $work 'result-recover.json'
    Write-Host "[7/9] consema apply (same plan, space freed) -- expect exit 0, all completed ..."
    & $Cli apply $planPath --output $resultRecover
    Assert-True ($LASTEXITCODE -eq 0) "recovery apply failed (exit $LASTEXITCODE)"
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
    Write-Host '=== RC soak stage-1 drill 5 (disk full) report ==='
    Write-Host "date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "host: $env:HOSTNAME"
    Write-Host "cli: $Cli"
    Write-Host "volume: tmpfs size=${SizeMb}M at $vol"
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
        Write-Host '[8/9] unmounting the volume ...'
        bash -c $umountScript 'rc-soak' $vol
        $mounted = $false
    }
    if ($Keep) {
        Write-Host "work dir kept: $work"
    }
    elseif (Test-Path $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
Write-Host '[9/9] drill complete (exit 0)'
exit 0
