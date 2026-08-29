$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $repo "bin\agysafe-runtime.ps1"
$cli = Join-Path $repo "bin\agysafe-cli.ps1"
$fakeAgy = Join-Path $PSScriptRoot "fake-agy.cmd"

$temp = Join-Path $env:TEMP ("agysafe-selftest-" + [guid]::NewGuid().ToString("N"))
$project = Join-Path $temp "project"

New-Item -ItemType Directory -Force -Path $project | Out-Null

Set-Content -LiteralPath (Join-Path $project "main.py") -Value 'print("ok")' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $project ".env") -Value 'API_KEY=DO_NOT_COPY' -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Join-Path $project "node_modules") | Out-Null
Set-Content -LiteralPath (Join-Path $project "node_modules\ignore.js") -Value 'ignored' -Encoding UTF8

$oldRoot = $env:USERPROFILE
$oldMode = $env:AGYSAFE_TEST_MODE
$oldAgyBin = $env:AGYSAFE_AGY_BIN

$testHome = Join-Path $temp "home"
New-Item -ItemType Directory -Force -Path $testHome | Out-Null
$env:USERPROFILE = $testHome
$env:AGYSAFE_AGY_BIN = $fakeAgy

try {
    # Core review path.
    $reviewJson = & $runner `
        -Task "审查一下当前项目" `
        -Workspace $project `
        -Mode auto `
        -Model auto `
        -Json

    $review = $reviewJson | ConvertFrom-Json

    if ($review.status -ne "SUCCESS") { throw "review status: $($review.status)" }
    if ($review.mode -ne "review") { throw "review mode routing failed" }
    if ($review.selected_model -ne "gemini-3.7-flash-high") { throw "review model routing failed" }
    if (-not $review.snapshot_used) { throw "review did not use snapshot" }
    if ($review.real_workspace_exposed_to_agy) { throw "real project exposed" }
    if (Test-Path -LiteralPath (Join-Path $review.delegated_workspace ".env")) { throw ".env leaked" }
    if (Test-Path -LiteralPath (Join-Path $review.delegated_workspace "node_modules")) { throw "node_modules leaked" }

    # Core isolated edit path.
    $env:AGYSAFE_TEST_MODE = "edit"

    $editJson = & $runner `
        -Task "修复这个测试文件" `
        -Workspace $project `
        -Mode edit `
        -Model gemini-3.7-flash-high `
        -Json

    $edit = $editJson | ConvertFrom-Json

    if ($edit.status -ne "SUCCESS") { throw "edit status: $($edit.status)" }
    if ($edit.changed_files -notcontains "edited_by_fake.txt") { throw "isolated edit not detected" }
    if (Test-Path -LiteralPath (Join-Path $project "edited_by_fake.txt")) { throw "real project was modified" }

    # Universal GNU-style CLI path, including manual model override.
    Remove-Item Env:AGYSAFE_TEST_MODE -ErrorAction SilentlyContinue

    $cliJson = & $cli `
        --workspace $project `
        --model claude-sonnet-4-6 `
        --mode review `
        --json `
        "审查一下当前项目"

    $cliResult = ($cliJson -join "`n") | ConvertFrom-Json

    if ($cliResult.status -ne "SUCCESS") { throw "universal CLI status: $($cliResult.status)" }
    if ($cliResult.selected_model -ne "claude-sonnet-4-6") { throw "universal CLI model override failed" }
    if ($cliResult.mode -ne "review") { throw "universal CLI mode override failed" }

    Write-Host "AgySafe self-test: PASS"
}
finally {
    $env:USERPROFILE = $oldRoot

    if ($null -eq $oldMode) {
        Remove-Item Env:AGYSAFE_TEST_MODE -ErrorAction SilentlyContinue
    }
    else {
        $env:AGYSAFE_TEST_MODE = $oldMode
    }

    if ($null -eq $oldAgyBin) {
        Remove-Item Env:AGYSAFE_AGY_BIN -ErrorAction SilentlyContinue
    }
    else {
        $env:AGYSAFE_AGY_BIN = $oldAgyBin
    }

    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
