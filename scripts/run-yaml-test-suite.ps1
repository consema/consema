param(
    [string]$SuiteRoot = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
# 注（2026-08-13，2026-08-14 波 2 修订，2026-08-15 波 5 归正）：六仓拆分后母仓根
# 无 Cargo.toml/workspace——本脚本的 `cargo build --locked -p consema-conformance`
# 在母仓原位必然失败（exit 101）；脚本只存在于母仓 scripts/（consema-rs 无副本，
# 无处可检），目前作为记录载体保留、无 CI job 执行（官方 yaml-test-suite 402 项
# 的记录载体是 docs/UPSTREAM-YAML-TEST-SUITE.md 与 conformance/README 上游 gate
# 段——fuzz-evidence 不含该记录，2026-08-15 波 5 归正证据指针）；可执行入口的
# 迁移/重建待总指挥决策。
# 注意：若未来迁移执行，必须先修正 target 路径解析——cargo build 按启动 cwd 解析、
# 脚本按自身位置解析 target 目录，两者不一致会静默命中陈旧二进制。
# 编码注（2026-08-15 波 4）：本文件为 UTF-8 WITH BOM——Windows PowerShell 5.1
# 在中文代码页（936）下会把 BOM-less UTF-8 注释字节误读为 GBK，部分字符吞掉换行、
# 注释吞并下一行代码导致解析失败（实测）；BOM 使 5.1 正确解析，保留 BOM。
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$expectedCommit = '6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f'
$expectedTag = 'data-2022-01-17'
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }

if (-not $SuiteRoot) {
    $SuiteRoot = Join-Path $workspaceRoot 'target\yaml-test-suite-data-2022-01-17'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $workspaceRoot 'target\yaml-test-suite-data-2022-01-17.tsv'
}

function Remove-SuiteRoot {
    # 部分克隆残留处理（2026-08-14 波 2 修复 + 2026-08-15 波 4 补全）：clone 被
    # 硬杀（SIGKILL/断电/磁盘满）会留下带残缺 .git 的目录；目录只要存在，后续
    # 运行 Test-Path 为真 → 跳过 clone → rev-parse 失败 → 永久卡死。删除必须
    # 同时覆盖「clone 失败」与「目录已存在但 .git 残缺」两条路径。
    if (Test-Path -LiteralPath $SuiteRoot) {
        Remove-Item -LiteralPath $SuiteRoot -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $SuiteRoot)) {
    & git clone --depth 1 --branch $expectedTag https://github.com/yaml/yaml-test-suite.git $SuiteRoot
    if ($LASTEXITCODE -ne 0) {
        Remove-SuiteRoot
        Write-Error "yaml-test-suite clone failed (exit $LASTEXITCODE); residual directory removed — 重跑将重新 clone"
        exit $LASTEXITCODE
    }
} else {
    # 目录已存在：验证它是完整 work tree。残缺 .git（硬杀残留）下 rev-parse
    # 失败——删除并重克隆，而不是让后续运行永久卡在残留目录上。--verify
    # --quiet 使失败静默，exit code 是唯一事实。EAP 临时降为 Continue：
    # PS 5.1 下带重定向的 native stderr 是终止性 NativeCommandError
    # （与 verify-package-archives.ps1:62 同族修复）。
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git -c "safe.directory=$($SuiteRoot.Replace('\', '/'))" -C $SuiteRoot rev-parse --verify --quiet HEAD > $null 2>$null
    $ErrorActionPreference = $previousEap
    if ($LASTEXITCODE -ne 0) {
        Write-Output "yaml-test-suite: $SuiteRoot is not a valid git work tree (residual from a killed clone?); removing and re-cloning"
        Remove-SuiteRoot
        & git clone --depth 1 --branch $expectedTag https://github.com/yaml/yaml-test-suite.git $SuiteRoot
        if ($LASTEXITCODE -ne 0) {
            Remove-SuiteRoot
            Write-Error "yaml-test-suite re-clone failed (exit $LASTEXITCODE); residual directory removed — 重跑将重新 clone"
            exit $LASTEXITCODE
        }
    }
}

$head = (& git -c "safe.directory=$($SuiteRoot.Replace('\', '/'))" -C $SuiteRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($head -ne $expectedCommit) {
    throw "yaml-test-suite commit mismatch: expected $expectedCommit, got $head"
}

& $cargo build --locked -p consema-conformance --bin consema-yaml-test-adapter
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$targetDirectory = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $workspaceRoot 'target' }
$adapter = Join-Path $targetDirectory 'debug\consema-yaml-test-adapter.exe'
& $adapter $SuiteRoot $ReportPath
exit $LASTEXITCODE
