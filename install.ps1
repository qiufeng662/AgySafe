$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repo = $PSScriptRoot
$homeDir = $env:USERPROFILE
$installRoot = Join-Path $env:LOCALAPPDATA "AgySafe"
$binDir = Join-Path $installRoot "bin"
$skillDir = Join-Path $homeDir ".agents\skills\agysafe"
$opencodeCommandDir = Join-Path $homeDir ".config\opencode\commands"
$geminiCommandDir = Join-Path $homeDir ".gemini\commands"
$runRoot = Join-Path $homeDir "AgySafeWorkspaces"

function Add-UserPathEntry {
    param([string]$PathToAdd)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()

    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $parts = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $normalizedAdd = $PathToAdd.Trim().Trim('"').TrimEnd('\')
    $already = $false

    foreach ($part in $parts) {
        $normalizedPart = $part.Trim().Trim('"').TrimEnd('\')

        if ([string]::Equals(
            $normalizedPart,
            $normalizedAdd,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $already = $true
            break
        }
    }

    if (-not $already) {
        $newPath = if ($parts.Count -gt 0) {
            (($parts + $PathToAdd) -join ';')
        } else {
            $PathToAdd
        }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    if (($env:Path -split ';') -notcontains $PathToAdd) {
        $env:Path = $PathToAdd + ";" + $env:Path
    }
}

function Add-MarkedBlock {
    param(
        [string]$TargetPath,
        [string]$SnippetPath
    )

    $snippet = [System.IO.File]::ReadAllText($SnippetPath)
    $begin = "<!-- AGYSAFE:BEGIN -->"
    $end = "<!-- AGYSAFE:END -->"

    $dir = Split-Path -Parent $TargetPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    if (Test-Path -LiteralPath $TargetPath) {
        $current = [System.IO.File]::ReadAllText($TargetPath)
        if ($current.Contains($begin) -and $current.Contains($end)) {
            return
        }

        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $TargetPath -Destination ($TargetPath + ".agysafe-backup-" + $stamp) -Force
        $combined = $current.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $snippet.Trim() + [Environment]::NewLine
    }
    else {
        $combined = $snippet.Trim() + [Environment]::NewLine
    }

    [System.IO.File]::WriteAllText(
        $TargetPath,
        $combined,
        ([System.Text.UTF8Encoding]::new($false))
    )
}

Write-Host ""
$releaseVersion = ([System.IO.File]::ReadAllText((Join-Path $repo "VERSION"))).Trim()
Write-Host ("AgySafe v" + $releaseVersion)
Write-Host "---------------"

Write-Host "[1/5] Running local self-test..."
& (Join-Path $repo "tests\self-test.ps1")
Write-Host "[OK] local self-test"

Write-Host "[2/5] Checking official agy CLI..."
$agy = Get-Command agy -ErrorAction SilentlyContinue
if (-not $agy) {
    throw "Official agy CLI was not found in PATH."
}

$versionOutput = @(& $agy.Source --version 2>&1 | ForEach-Object { $_.ToString() })
if ($LASTEXITCODE -ne 0) {
    throw ("agy --version failed: " + (($versionOutput -join " ").Trim()))
}
Write-Host ("[OK] agy " + (($versionOutput -join " ").Trim()))

Write-Host "[3/5] Installing universal AgySafe CLI..."
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Copy-Item (Join-Path $repo "bin\agysafe-runtime.ps1") (Join-Path $binDir "agysafe-runtime.ps1") -Force
Copy-Item (Join-Path $repo "bin\agysafe-cli.ps1") (Join-Path $binDir "agysafe-cli.ps1") -Force
Copy-Item (Join-Path $repo "bin\agysafe.cmd") (Join-Path $binDir "agysafe.cmd") -Force
Add-UserPathEntry $binDir
Write-Host ("[OK] agysafe command: " + (Join-Path $binDir "agysafe.cmd"))

Write-Host "[4/5] Preparing isolated workspace..."
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$settingsPath = Join-Path $homeDir ".gemini\antigravity-cli\settings.json"
$settingsDir = Split-Path -Parent $settingsPath
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

try {
    if (Test-Path -LiteralPath $settingsPath) {
        $raw = [System.IO.File]::ReadAllText($settingsPath)
        $settings = if ([string]::IsNullOrWhiteSpace($raw)) { New-Object PSObject } else { $raw | ConvertFrom-Json }

        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $settingsPath -Destination ($settingsPath + ".agysafe-backup-" + $stamp) -Force
    }
    else {
        $settings = New-Object PSObject
    }

    if ($null -eq $settings.PSObject.Properties["trustedWorkspaces"]) {
        $settings | Add-Member -NotePropertyName trustedWorkspaces -NotePropertyValue @()
    }
    elseif ($null -eq $settings.trustedWorkspaces) {
        $settings.trustedWorkspaces = @()
    }

    $trusted = @(
        $settings.trustedWorkspaces |
        Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) }
    )

    $already = $false
    foreach ($item in $trusted) {
        if ([string]::Equals(
            [System.IO.Path]::GetFullPath([string]$item).TrimEnd('\'),
            [System.IO.Path]::GetFullPath($runRoot).TrimEnd('\'),
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $already = $true
            break
        }
    }

    if (-not $already) {
        $settings.trustedWorkspaces = @($trusted + $runRoot)
        $json = $settings | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText(
            $settingsPath,
            $json,
            ([System.Text.UTF8Encoding]::new($false))
        )
    }

    Write-Host "[OK] isolation root ready"
}
catch {
    Write-Host ("[WARN] Could not update AGY trustedWorkspaces: " + $_.Exception.Message)
    Write-Host "       AgySafe will still use cwd + absolute --add-dir."
}

Write-Host "[5/5] Installing agent integrations..."

# Remove legacy AgySafe-owned skill files from pre-1.0 releases so old
# scripts cannot be accidentally discovered by OpenCode or another host.
if (Test-Path -LiteralPath $skillDir) {
    Remove-Item -LiteralPath $skillDir -Recurse -Force -ErrorAction Stop
}
New-Item -ItemType Directory -Force -Path $skillDir | Out-Null

# Common Agent Skill: used by compatible agent hosts, including Codex-style skill discovery.
Copy-Item (Join-Path $repo "SKILL.md") (Join-Path $skillDir "SKILL.md") -Force

# OpenCode / OpenCode CLI
New-Item -ItemType Directory -Force -Path $opencodeCommandDir | Out-Null
Copy-Item (Join-Path $repo "integrations\opencode\commands\agy.md") (Join-Path $opencodeCommandDir "agy.md") -Force

# Gemini CLI native global slash command.
New-Item -ItemType Directory -Force -Path $geminiCommandDir | Out-Null
Copy-Item (Join-Path $repo "integrations\gemini-cli\agy.toml") (Join-Path $geminiCommandDir "agy.toml") -Force

# Codex / Codex CLI global instructions, only if Codex appears to be installed/configured.
$codexPresent = (Test-Path -LiteralPath (Join-Path $homeDir ".codex")) -or [bool](Get-Command codex -ErrorAction SilentlyContinue)
if ($codexPresent) {
    Add-MarkedBlock `
        -TargetPath (Join-Path $homeDir ".codex\AGENTS.md") `
        -SnippetPath (Join-Path $repo "integrations\codex\AGENTS.md.snippet")
    Write-Host "[OK] Codex instructions"
}

# Claude Code global instructions, only if Claude Code appears installed/configured.
$claudePresent = (Test-Path -LiteralPath (Join-Path $homeDir ".claude")) -or [bool](Get-Command claude -ErrorAction SilentlyContinue)
if ($claudePresent) {
    Add-MarkedBlock `
        -TargetPath (Join-Path $homeDir ".claude\CLAUDE.md") `
        -SnippetPath (Join-Path $repo "integrations\claude-code\CLAUDE.md.snippet")
    Write-Host "[OK] Claude Code instructions"
}

Write-Host "[OK] OpenCode integration"
Write-Host "[OK] Gemini CLI integration"
Write-Host "[OK] common Agent Skill"

Write-Host ""
Write-Host "Done."
Write-Host "Universal CLI:"
Write-Host '  agysafe "review the current project"'
Write-Host ""
Write-Host "OpenCode / OpenCode CLI:"
Write-Host "  /agy review the current project"
Write-Host ""
Write-Host "Gemini CLI:"
Write-Host "  /agy review the current project"
Write-Host ""
Write-Host "Restart already-open agent applications so they inherit the updated PATH."
