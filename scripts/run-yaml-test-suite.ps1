param(
    [string]$SuiteRoot = '',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
# 注（2026-08-13，2026-08-14 波 2 修订）：六仓拆分后母仓根无 Cargo.toml/workspace——
# 本脚本的 `cargo build --locked -p consema-conformance` 在母仓原位必然失败（exit 101）；
# 脚本只存在于母仓 scripts/（consema-rs 无副本，无处可检），目前作为记录载体保留、
# 无 CI job 执行（官方 yaml-test-suite 402 项的记录见 fuzz-evidence 与 conformance/README
# 上游 gate 段）；可执行入口的迁移/重建待总指挥决策。
# 注意：若未来迁移执行，必须先修正 target 路径解析——cargo build 按启动 cwd 解析、
# 脚本按自身位置解析 target 目录，两者不一致会静默命中陈旧二进制。
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

if (-not (Test-Path -LiteralPath $SuiteRoot)) {
    & git clone --depth 1 --branch $expectedTag https://github.com/yaml/yaml-test-suite.git $SuiteRoot
    if ($LASTEXITCODE -ne 0) {
        # 部分克隆残留处理：删除残留目录，避免后续运行因目录已存在而跳过
        # clone、随后 rev-parse 失败并永久卡死（2026-08-14 波 2 修复）
        if (Test-Path -LiteralPath $SuiteRoot) { Remove-Item -LiteralPath $SuiteRoot -Recurse -Force }
        Write-Error "yaml-test-suite clone failed (exit $LASTEXITCODE); residual directory removed — 重跑将重新 clone"
        exit $LASTEXITCODE
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
