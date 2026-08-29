$ErrorActionPreference = "Stop"

$homeDir = $env:USERPROFILE
$binDir = Join-Path $env:LOCALAPPDATA "AgySafe\bin"

function Remove-MarkedBlock {
    param([string]$TargetPath)

    if (-not (Test-Path -LiteralPath $TargetPath)) { return }

    $text = [System.IO.File]::ReadAllText($TargetPath)
    $pattern = '(?s)\s*<!-- AGYSAFE:BEGIN -->.*?<!-- AGYSAFE:END -->\s*'
    $updated = [regex]::Replace($text, $pattern, [Environment]::NewLine).Trim()

    if ([string]::IsNullOrWhiteSpace($updated)) {
        Remove-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue
    }
    else {
        [System.IO.File]::WriteAllText(
            $TargetPath,
            $updated + [Environment]::NewLine,
            ([System.Text.UTF8Encoding]::new($false))
        )
    }
}

Remove-Item (Join-Path $homeDir ".agents\skills\agysafe") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $homeDir ".config\opencode\commands\agy.md") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $homeDir ".gemini\commands\agy.toml") -Force -ErrorAction SilentlyContinue

Remove-MarkedBlock (Join-Path $homeDir ".codex\AGENTS.md")
Remove-MarkedBlock (Join-Path $homeDir ".claude\CLAUDE.md")

Remove-Item (Join-Path $env:LOCALAPPDATA "AgySafe") -Recurse -Force -ErrorAction SilentlyContinue

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $remaining = @(
        $userPath -split ';' |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and
            -not [string]::Equals(
                $_.Trim(),
                $binDir,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
    )
    [Environment]::SetEnvironmentVariable("Path", ($remaining -join ';'), "User")
}

Write-Host "AgySafe removed."
Write-Host "AgySafeWorkspaces and AGY settings backups are intentionally kept."
