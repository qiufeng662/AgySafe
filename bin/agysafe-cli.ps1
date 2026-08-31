$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Intentionally use PowerShell's automatic $args array instead of a param()
# block. This lets GNU-style options such as --model and --workspace pass
# through PowerShell 5.1 unchanged.
$CliArgs = @($args)

$runtime = Join-Path $PSScriptRoot "agysafe-runtime.ps1"

function Show-Help {
@"
AgySafe

Usage:
  agysafe [options] <task>

Options:
  --model, -m <slug>       Model override. Default: auto
  --mode <mode>            auto | ask | review | edit. Default: auto
  --workspace, -w <path>   Project workspace. Default: current directory
  --timeout <minutes>      1..60. Default: 10
  --max-snapshot-mb <MB>   1..2048. Default: 128
  --json                   Print structured JSON
  --doctor                 Check official agy CLI
  --help, -h               Show this help

Examples:
  agysafe "review the current project"
  agysafe -m gemini-3.1-pro-high --mode review "analyze the architecture"
  agysafe --model claude-sonnet-4-6 "review the current project"

Model policy:
  auto is Gemini-first. Claude/GPT models are used only when explicitly
  selected with --model / -m.
"@
}

$model = "auto"
$mode = "auto"
$workspace = (Get-Location).Path
$timeout = 10
$maxSnapshotMB = 128
$jsonRequested = $false
$doctor = $false
$taskParts = @()
$parseOptions = $true

$i = 0
while ($i -lt $CliArgs.Count) {
    $arg = $CliArgs[$i]

    if ($parseOptions -and $arg -eq "--") {
        $parseOptions = $false
        $i++
        continue
    }

    if ($parseOptions) {
        if ($arg -in @("--help", "-h")) {
            Show-Help
            return
        }

        if ($arg -eq "--doctor") {
            $doctor = $true
            $i++
            continue
        }

        if ($arg -eq "--json") {
            $jsonRequested = $true
            $i++
            continue
        }

        if ($arg -match '^--model=(.+)$') {
            $model = $Matches[1]
            $i++
            continue
        }

        if ($arg -in @("--model", "-m")) {
            if ($i + 1 -ge $CliArgs.Count) { throw "$arg requires a value" }
            $model = $CliArgs[$i + 1]
            $i += 2
            continue
        }

        if ($arg -match '^--mode=(.+)$') {
            $mode = $Matches[1]
            $i++
            continue
        }

        if ($arg -eq "--mode") {
            if ($i + 1 -ge $CliArgs.Count) { throw "--mode requires a value" }
            $mode = $CliArgs[$i + 1]
            $i += 2
            continue
        }

        if ($arg -match '^--workspace=(.+)$') {
            $workspace = $Matches[1]
            $i++
            continue
        }

        if ($arg -in @("--workspace", "-w")) {
            if ($i + 1 -ge $CliArgs.Count) { throw "$arg requires a value" }
            $workspace = $CliArgs[$i + 1]
            $i += 2
            continue
        }

        if ($arg -match '^--timeout=(\d+)$') {
            $timeout = [int]$Matches[1]
            $i++
            continue
        }

        if ($arg -eq "--timeout") {
            if ($i + 1 -ge $CliArgs.Count) { throw "--timeout requires a value" }
            $timeout = [int]$CliArgs[$i + 1]
            $i += 2
            continue
        }

        if ($arg -match '^--max-snapshot-mb=(\d+)$') {
            $maxSnapshotMB = [int]$Matches[1]
            $i++
            continue
        }

        if ($arg -eq "--max-snapshot-mb") {
            if ($i + 1 -ge $CliArgs.Count) { throw "--max-snapshot-mb requires a value" }
            $maxSnapshotMB = [int]$CliArgs[$i + 1]
            $i += 2
            continue
        }
    }

    $taskParts += $arg
    $i++
}

if ($mode -notin @("auto", "ask", "review", "edit")) {
    throw "Invalid --mode: $mode"
}

if ($timeout -lt 1 -or $timeout -gt 60) {
    throw "--timeout must be between 1 and 60"
}

if ($maxSnapshotMB -lt 1 -or $maxSnapshotMB -gt 2048) {
    throw "--max-snapshot-mb must be between 1 and 2048"
}

if ($doctor) {
    $raw = @(& $runtime -Doctor -Json)
    $text = ($raw -join "`n").Trim()
    if ($jsonRequested) {
        Write-Output $text
    } else {
        $obj = $text | ConvertFrom-Json
        Write-Host ("AgySafe doctor: " + $obj.status)
        if ($obj.agy_version) { Write-Host ("agy: " + $obj.agy_version) }
        if ($obj.error) { Write-Host ("error: " + $obj.error) }
    }
    try {
        $obj = $text | ConvertFrom-Json
        if ($obj.status -ne "OK") { exit 2 }
    } catch {
        exit 2
    }
    return
}

$task = ($taskParts -join " ").Trim()
if ([string]::IsNullOrWhiteSpace($task)) {
    Show-Help
    exit 2
}

$raw = @(
    & $runtime `
        -Task $task `
        -Workspace $workspace `
        -Mode $mode `
        -Model $model `
        -TimeoutMinutes $timeout `
        -MaxSnapshotMB $maxSnapshotMB `
        -Json
)

$text = ($raw -join "`n").Trim()

try {
    $result = $text | ConvertFrom-Json
}
catch {
    Write-Output $text
    exit 2
}

if ($jsonRequested) {
    Write-Output $text
}
else {
    Write-Host ("AgySafe workspace: " + $result.real_workspace)
    if ($result.workspace_note) { Write-Host ("Note: " + $result.workspace_note) }
    Write-Host ""

    if (-not [string]::IsNullOrWhiteSpace([string]$result.result)) {
        Write-Output $result.result
        Write-Host ""
    }
    Write-Host ("AgySafe · " + $result.selected_model + " · " + $result.status)
    if ($result.recommended_fallback) {
        Write-Host ("Recommended fallback: " + $result.recommended_fallback)
    }
    if ($result.status -eq "QUOTA_EXCEEDED" -and $result.reset_hint) {
        Write-Host ("Quota reset hint: " + $result.reset_hint)
    }
    if ($result.status -eq "SNAPSHOT_TOO_LARGE") {
        Write-Host ("Snapshot candidate: " + $result.snapshot_mb + " MB / limit " + $result.snapshot_limit_mb + " MB")
        Write-Host "Use .agysafeignore or a smaller --workspace before increasing the limit."
    }

    if ($result.mode -eq "edit" -and @($result.changed_files).Count -gt 0) {
        Write-Host ("Isolated changes: " + @($result.changed_files).Count)
        Write-Host ("Workspace: " + $result.delegated_workspace)
    }
}

if ($result.status -ne "SUCCESS") {
    exit 2
}
