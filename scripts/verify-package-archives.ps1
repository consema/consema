param(
    [string]$ArchiveDirectory = '',
    [switch]$SkipPackaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cargo = if ($env:CONSEMA_CARGO) { $env:CONSEMA_CARGO } else { 'cargo' }
$targetDirectory = if ($env:CARGO_TARGET_DIR) {
    [IO.Path]::GetFullPath($env:CARGO_TARGET_DIR)
} else {
    Join-Path $workspaceRoot 'target'
}

function Invoke-Cargo {
    param([string[]]$Arguments)

    & $cargo @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "cargo $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$metadataJson = & $cargo metadata --locked --offline --no-deps --format-version 1
if ($LASTEXITCODE -ne 0) {
    throw "cargo metadata failed with exit code $LASTEXITCODE"
}
$metadata = $metadataJson | ConvertFrom-Json
$workspaceMembers = @{}
foreach ($id in $metadata.workspace_members) {
    $workspaceMembers[$id] = $true
}

$workspacePackages = @(
    $metadata.packages |
        Where-Object { $workspaceMembers.ContainsKey($_.id) } |
        Sort-Object name
)
$publishablePackages = @(
    $workspacePackages | Where-Object { $null -eq $_.publish }
)
$repositoryOnlyPackages = @(
    $workspacePackages | Where-Object { $null -ne $_.publish }
)

if ($publishablePackages.Count -eq 0) {
    throw 'workspace contains no publishable packages'
}

if (-not $SkipPackaging) {
    $packageArguments = @(
        'package',
        '--locked',
        '--offline',
        '--workspace',
        '--no-verify'
    )
    foreach ($package in $repositoryOnlyPackages) {
        $packageArguments += @('--exclude', $package.name)
    }
    Invoke-Cargo $packageArguments
}

if (-not $ArchiveDirectory) {
    $ArchiveDirectory = Join-Path $targetDirectory 'package'
}
$ArchiveDirectory = [IO.Path]::GetFullPath($ArchiveDirectory)
if (-not (Test-Path -LiteralPath $ArchiveDirectory -PathType Container)) {
    throw "package archive directory does not exist: $ArchiveDirectory"
}

$artifacts = @()
foreach ($package in $publishablePackages) {
    $fileName = "$($package.name)-$($package.version).crate"
    $archivePath = Join-Path $ArchiveDirectory $fileName
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "missing package archive: $archivePath"
    }
    $artifacts += [PSCustomObject]@{
        Name = $package.name
        Version = $package.version
        Root = "$($package.name)-$($package.version)"
        Archive = $archivePath
        Sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$temporaryRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ('consema-package-verify-' + [Guid]::NewGuid().ToString('N'))
$temporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
$systemTemporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (
    -not $temporaryRoot.StartsWith($systemTemporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Split-Path -Leaf $temporaryRoot).StartsWith('consema-package-verify-')
) {
    throw "refusing unsafe verification directory: $temporaryRoot"
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

    foreach ($artifact in $artifacts) {
        $entries = @(& tar -tf $artifact.Archive)
        if ($LASTEXITCODE -ne 0) {
            throw "cannot list package archive: $($artifact.Archive)"
        }
        if ($entries.Count -eq 0) {
            throw "empty package archive: $($artifact.Archive)"
        }
        $rootPrefix = "$($artifact.Root)/"
        foreach ($entry in $entries) {
            if (
                -not $entry.StartsWith($rootPrefix, [StringComparison]::Ordinal) -or
                $entry.Split('/') -contains '..'
            ) {
                throw "unsafe or unexpected archive entry '$entry' in $($artifact.Archive)"
            }
        }

        & tar -xzf $artifact.Archive -C $temporaryRoot
        if ($LASTEXITCODE -ne 0) {
            throw "cannot extract package archive: $($artifact.Archive)"
        }
        $manifestPath = Join-Path $temporaryRoot "$($artifact.Root)\Cargo.toml"
        $lockPath = Join-Path $temporaryRoot "$($artifact.Root)\Cargo.lock"
        if (
            -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $lockPath -PathType Leaf)
        ) {
            throw "package archive lacks Cargo.toml or Cargo.lock: $($artifact.Archive)"
        }
    }

    foreach ($artifact in $artifacts) {
        $lockPath = Join-Path $temporaryRoot "$($artifact.Root)\Cargo.lock"
        $lockBlocks = [Regex]::Split(
            (Get-Content -LiteralPath $lockPath -Raw),
            '(?m)^\[\[package\]\]\s*$'
        )
        $localDependencies = @()
        foreach ($dependency in $artifacts) {
            if ($dependency.Name -eq $artifact.Name) { continue }
            $namePattern = '(?m)^name = "' + [Regex]::Escape($dependency.Name) + '"$'
            $versionPattern = '(?m)^version = "' + [Regex]::Escape($dependency.Version) + '"$'
            $block = @(
                $lockBlocks | Where-Object {
                    $_ -match $namePattern -and $_ -match $versionPattern
                }
            )
            if ($block.Count -eq 0) { continue }
            if ($block.Count -ne 1) {
                throw "ambiguous lock entry for $($dependency.Name) in $($artifact.Name)"
            }
            $checksumMatch = [Regex]::Match(
                $block[0],
                '(?m)^checksum = "([0-9a-f]{64})"$'
            )
            if (-not $checksumMatch.Success) {
                throw "missing checksum for $($dependency.Name) in $($artifact.Name)"
            }
            if ($checksumMatch.Groups[1].Value -ne $dependency.Sha256) {
                throw "checksum mismatch for $($dependency.Name) in $($artifact.Name)"
            }
            $localDependencies += $dependency
        }
        $artifact | Add-Member -NotePropertyName LocalDependencies -NotePropertyValue $localDependencies
    }

    foreach ($artifact in $artifacts) {
        $manifestPath = Join-Path $temporaryRoot "$($artifact.Root)\Cargo.toml"
        $checkArguments = @(
            'check',
            '--manifest-path',
            $manifestPath,
            '--offline',
            '--all-targets',
            '--all-features'
        )
        if ($artifact.LocalDependencies.Count -gt 0) {
            $patchConfig = Join-Path $temporaryRoot "$($artifact.Name)-patches.toml"
            $patchLines = @('[patch.crates-io]')
            foreach ($dependency in $artifact.LocalDependencies) {
                $sourcePath = (
                    Join-Path $temporaryRoot $dependency.Root
                ).Replace('\', '/')
                $patchLines += "$($dependency.Name) = { path = `"$sourcePath`" }"
            }
            Set-Content -LiteralPath $patchConfig -Value $patchLines -Encoding UTF8
            $checkArguments += @('--config', $patchConfig)
        }
        Invoke-Cargo $checkArguments
    }

    Write-Output "verified $($artifacts.Count) publishable package archives"
    foreach ($artifact in $artifacts) {
        Write-Output "$($artifact.Sha256)  $([IO.Path]::GetFileName($artifact.Archive))"
    }
    if ($repositoryOnlyPackages.Count -gt 0) {
        Write-Output (
            'repository-only packages: ' +
            (($repositoryOnlyPackages | ForEach-Object { $_.name }) -join ', ')
        )
    }
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
