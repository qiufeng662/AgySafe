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

# Data/binary fixtures for v1.0.2 snapshot slimming.
Set-Content -LiteralPath (Join-Path $project "sample.dta") -Value 'binary-placeholder' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $project "sample.xlsx") -Value 'binary-placeholder' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $project "fixture.csv") -Value 'a,b`n1,2' -Encoding UTF8

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
    if (Test-Path -LiteralPath (Join-Path $review.delegated_workspace "sample.dta")) { throw ".dta should be excluded by default" }
    if (Test-Path -LiteralPath (Join-Path $review.delegated_workspace "sample.xlsx")) { throw ".xlsx should be excluded by default" }
    $csvExclusions = @($review.excluded_files | Where-Object { $_.path -eq "fixture.csv" })
    if ($csvExclusions.Count -gt 0) { throw ("small CSV should remain eligible by default: " + $csvExclusions[0].reason) }
    if ($review.snapshot_limit_mb -ne 128) { throw "default snapshot limit changed unexpectedly" }
    if ($review.snapshot_bytes -le 0) { throw "snapshot size metrics missing" }

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
    $changed = @($edit.changed_files)
    if ($changed.Count -lt 1) { throw "edit returned SUCCESS but changed_files was empty" }
    $isolatedEdit = Join-Path $edit.delegated_workspace "edited_by_fake.txt"
    if (-not (Test-Path -LiteralPath $isolatedEdit)) { throw "isolated edit file missing from delegated workspace" }
    if (Test-Path -LiteralPath (Join-Path $project "edited_by_fake.txt")) { throw "real project was modified" }

    # Universal GNU-style CLI path, including manual model override.
    Remove-Item Env:AGYSAFE_TEST_MODE -ErrorAction SilentlyContinue

    $cliJson = & $cli `
        --workspace $project `
        --model claude-sonnet-4-6 `
        --mode review `
        --max-snapshot-mb 64 `
        --json `
        "审查一下当前项目"

    $cliResult = ($cliJson -join "`n") | ConvertFrom-Json

    if ($cliResult.status -ne "SUCCESS") { throw "universal CLI status: $($cliResult.status)" }
    if ($cliResult.selected_model -ne "claude-sonnet-4-6") { throw "universal CLI model override failed" }
    if ($cliResult.mode -ne "review") { throw "universal CLI mode override failed" }
    if ($cliResult.snapshot_limit_mb -ne 64) { throw "universal CLI max snapshot override failed" }

    # Auto routing must remain Gemini-first even when the task text mentions Claude.
    $autoPremiumJson = & $runner `
        -Task "请用 Claude Opus 深度审查当前项目" `
        -Workspace $project `
        -Mode review `
        -Model auto `
        -Json
    $autoPremium = $autoPremiumJson | ConvertFrom-Json
    if ($autoPremium.selected_model -ne "gemini-3.7-flash-high") { throw "auto routing selected a premium model implicitly" }

    # Large-workspace guard must stop before AGY is called.
    $largeProject = Join-Path $temp "large-project"
    $largeData = Join-Path $largeProject "outputs"
    New-Item -ItemType Directory -Force -Path $largeData | Out-Null
    Set-Content -LiteralPath (Join-Path $largeProject "main.py") -Value 'print("large")' -Encoding UTF8
    $largeFile = Join-Path $largeData "payload.txt"
    $stream = [System.IO.File]::Open($largeFile, [System.IO.FileMode]::Create)
    try { $stream.SetLength(2MB) } finally { $stream.Dispose() }

    $largeJson = & $runner `
        -Task "审查当前项目" `
        -Workspace $largeProject `
        -Mode review `
        -Model auto `
        -MaxSnapshotMB 1 `
        -Json
    $large = $largeJson | ConvertFrom-Json
    if ($large.status -ne "SNAPSHOT_TOO_LARGE") { throw "large snapshot guard failed: $($large.status)" }
    if ($null -ne $large.agy_exit_code) { throw "AGY should not run for oversized snapshot" }
    if ($large.snapshot_mb -le $large.snapshot_limit_mb) { throw "oversized snapshot metrics invalid" }
    if (@($large.largest_snapshot_roots).Count -lt 1) { throw "largest snapshot roots missing" }

    # Test .agysafeignore matching independently from the snapshot-size threshold.
    # The large-workspace guard is already validated above. Keeping these assertions
    # separate makes CI failures identify parsing/matching rather than conflate both.
    $ignoreFixture = Join-Path $largeProject ".agysafeignore"
    [System.IO.File]::WriteAllText($ignoreFixture, "outputs/`r`n", (New-Object System.Text.UTF8Encoding($false)))

    $ignoredJson = & $runner `
        -Task "审查当前项目" `
        -Workspace $largeProject `
        -Mode review `
        -Model auto `
        -MaxSnapshotMB 8 `
        -Json
    $ignored = $ignoredJson | ConvertFrom-Json
    if ($ignored.status -ne "SUCCESS") { throw ".agysafeignore review failed: $($ignored.status)" }
    if (-not $ignored.agysafeignore_used) { throw ".agysafeignore file was not parsed" }

    $outputExclusion = @($ignored.excluded_files | Where-Object {
        $_.path -eq "outputs" -and $_.reason -like "matched .agysafeignore:*"
    })
    if ($outputExclusion.Count -ne 1) {
        $debugExcluded = (@($ignored.excluded_files | ForEach-Object { $_.path + " => " + $_.reason }) -join "; ")
        throw ".agysafeignore outputs/ rule was not applied. Excluded: $debugExcluded"
    }

    if (Test-Path -LiteralPath (Join-Path $ignored.delegated_workspace "outputs")) { throw ".agysafeignore directory leaked" }
    if ($ignored.snapshot_bytes -ge 1MB) { throw ".agysafeignore did not slim snapshot below 1 MB" }

    # Doctor path, including the PowerShell 5.1 $Doctor/$doctor collision regression.
    $doctorJson = & $cli --doctor --json
    $doctorResult = ($doctorJson -join "`n") | ConvertFrom-Json
    if ($doctorResult.status -ne "OK") { throw "doctor status: $($doctorResult.status)" }
    if ($doctorResult.agy_version -notmatch '1\.1\.22-test') { throw "doctor version check failed" }

    # Explicit quota classification and fallback recommendation.
    $env:AGYSAFE_TEST_MODE = "quota"
    $quotaJson = & $runner `
        -Task "审查当前项目" `
        -Workspace $project `
        -Mode review `
        -Model claude-opus-4-6-thinking `
        -Json
    $quota = $quotaJson | ConvertFrom-Json
    if ($quota.status -ne "QUOTA_EXCEEDED") { throw "quota classification failed: $($quota.status)" }
    if ($quota.quota_type -ne "individual") { throw "quota type parsing failed" }
    if ($quota.reset_hint -notmatch '4h5m0s') { throw "quota reset hint parsing failed" }
    if ($quota.recommended_fallback -ne "gemini-3.7-flash-high") { throw "quota fallback recommendation failed" }

    # Exit code 0 is not sufficient for SUCCESS when a review ends at a planning-only tail.
    $env:AGYSAFE_TEST_MODE = "incomplete"
    $incompleteJson = & $runner `
        -Task "审查当前项目" `
        -Workspace $project `
        -Mode review `
        -Model claude-opus-4-6-thinking `
        -Json
    $incomplete = $incompleteJson | ConvertFrom-Json
    if ($incomplete.agy_exit_code -ne 0) { throw "incomplete fixture should exit 0" }
    if ($incomplete.status -ne "INCOMPLETE") { throw "incomplete classification failed: $($incomplete.status)" }
    if ($incomplete.recommended_fallback -ne "gemini-3.7-flash-high") { throw "incomplete fallback recommendation failed" }

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
