[CmdletBinding()]
param(
    [string]$Task,
    [string]$Workspace = (Get-Location).Path,
    [ValidateSet("auto", "ask", "review", "edit")]
    [string]$Mode = "auto",
    [string]$Model = "auto",
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10,
    [string]$AgyPath,
    [switch]$Json,
    [switch]$Doctor
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-AgyExecutable {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "agy executable not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    if ($env:AGYSAFE_AGY_BIN) {
        if (-not (Test-Path -LiteralPath $env:AGYSAFE_AGY_BIN)) {
            throw "AGYSAFE_AGY_BIN does not exist: $env:AGYSAFE_AGY_BIN"
        }
        return (Resolve-Path -LiteralPath $env:AGYSAFE_AGY_BIN).Path
    }

    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "official agy CLI was not found in PATH"
    }
    return $cmd.Source
}

function Resolve-AgySafeMode {
    param([string]$Text, [string]$Requested)

    if ($Requested -ne "auto") { return $Requested }

    $t = $Text.ToLowerInvariant()

    if ($t -match '修改|修复|实现|重构|改一下|改成|写入|新增|删除|替换|edit|fix|implement|refactor|modify|change|create|delete') {
        return "edit"
    }

    if ($t -match '审查|检查|分析|评审|找问题|代码质量|当前项目|这个项目|项目代码|代码库|仓库|review|audit|inspect|analyse|analyze|current project|codebase|repository') {
        return "review"
    }

    return "ask"
}

function Resolve-AgySafeModel {
    param([string]$Text, [string]$ResolvedMode, [string]$Requested)

    if ($Requested -ne "auto") { return $Requested }

    $t = $Text.ToLowerInvariant()

    if ($t -match '极高复杂度|全面深度|重大架构|关键架构|高风险架构|critical architecture|high-stakes') {
        return "claude-opus-4-6-thinking"
    }

    if ($t -match '跨文件|复杂.?bug|架构|技术债|重构方案|系统设计|cross-file|architecture|complex bug|technical debt') {
        return "gemini-3.1-pro-high"
    }

    if ($t -match 'claude|sonnet') {
        return "claude-sonnet-4-6"
    }

    if ($ResolvedMode -eq "review") {
        return "gemini-3.7-flash-high"
    }

    if ($t -match '只回复|简单|一句话|翻译|格式化|quick|simple|one line') {
        return "gemini-3.7-flash-low"
    }

    return "gemini-3.7-flash-high"
}

function Test-WindowsReservedName {
    param([string]$Name)

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name).TrimEnd(' ', '.').ToUpperInvariant()

    if ($base -in @("CON", "PRN", "AUX", "NUL", "CLOCK$")) { return $true }
    if ($base -match '^(COM[1-9]|LPT[1-9])$') { return $true }

    return $false
}

function Test-SensitiveFileName {
    param([System.IO.FileInfo]$File)

    $n = $File.Name.ToLowerInvariant()

    if ($n -eq ".env" -or $n -like ".env.*") {
        if ($n -in @(".env.example", ".env.sample", ".env.template")) { return $false }
        return $true
    }

    foreach ($pattern in @(
        "*.pem", "*.key", "*.p12", "*.pfx", "*.kdbx",
        "id_rsa", "id_ed25519",
        "credentials.json", "secrets.*",
        "*.sqlite", "*.sqlite3", "*.db"
    )) {
        if ($n -like $pattern) { return $true }
    }

    return $false
}

function Test-HighConfidenceSecret {
    param([System.IO.FileInfo]$File)

    if ($File.Length -gt 1MB) { return $false }

    $allowedExtensions = @(
        ".py", ".js", ".ts", ".tsx", ".jsx", ".json", ".toml", ".yaml", ".yml",
        ".md", ".txt", ".html", ".css", ".scss", ".java", ".go", ".rs",
        ".c", ".h", ".cpp", ".hpp", ".cs", ".php", ".rb", ".sh", ".ps1",
        ".bat", ".cmd", ".sql", ".ini", ".cfg", ".conf", ".properties"
    )

    if (($allowedExtensions -notcontains $File.Extension.ToLowerInvariant()) -and
        ($File.Name -notin @("Dockerfile", "Makefile"))) {
        return $false
    }

    try {
        $text = [System.IO.File]::ReadAllText($File.FullName)
    }
    catch {
        return $false
    }

    foreach ($pattern in @(
        '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
        '\bsk-[A-Za-z0-9_-]{20,}\b',
        '\bgh[pousr]_[A-Za-z0-9]{20,}\b',
        '\bAIza[0-9A-Za-z_-]{30,}\b',
        '\bAKIA[0-9A-Z]{16}\b'
    )) {
        if ($text -match $pattern) { return $true }
    }

    return $false
}

function New-SafeSnapshot {
    param([string]$Source, [string]$Destination)

    $excludedDirNames = @(
        ".git", ".svn", ".hg", ".idea",
        "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache",
        ".venv", "venv", "dist", "build", "target",
        ".ssh", ".aws", ".azure", ".kube"
    )

    $included = @()
    $excluded = @()

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    $pending = New-Object System.Collections.ArrayList
    [void]$pending.Add((Get-Item -LiteralPath $Source))

    while ($pending.Count -gt 0) {
        $index = $pending.Count - 1
        $dir = $pending[$index]
        $pending.RemoveAt($index)

        foreach ($childDir in @(Get-ChildItem -LiteralPath $dir.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
            $relative = $childDir.FullName.Substring($Source.Length).TrimStart('\')

            if (Test-WindowsReservedName $childDir.Name) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "Windows reserved device name" }
                continue
            }

            if ($excludedDirNames -contains $childDir.Name) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "excluded directory" }
                continue
            }

            if (($childDir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "reparse point" }
                continue
            }

            [void]$pending.Add($childDir)
        }

        foreach ($file in @(Get-ChildItem -LiteralPath $dir.FullName -File -Force -ErrorAction SilentlyContinue)) {
            $relative = $file.FullName.Substring($Source.Length).TrimStart('\')

            if (Test-WindowsReservedName $file.Name) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "Windows reserved device name" }
                continue
            }

            if (Test-SensitiveFileName $file) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "sensitive filename" }
                continue
            }

            if ($file.Length -gt 10MB) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "file larger than 10 MB" }
                continue
            }

            if (Test-HighConfidenceSecret $file) {
                $excluded += [pscustomobject]@{ path = $relative; reason = "high-confidence secret pattern" }
                continue
            }

            $target = Join-Path $Destination $relative
            $targetDir = Split-Path -Parent $target

            try {
                New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
                Copy-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
                $included += $relative
            }
            catch {
                $excluded += [pscustomobject]@{
                    path = $relative
                    reason = ("copy skipped: " + $_.Exception.Message)
                }
            }
        }
    }

    return [pscustomobject]@{
        included = @($included)
        excluded = @($excluded)
    }
}

function Get-Manifest {
    param([string]$Root)

    $manifest = @{}

    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force -ErrorAction SilentlyContinue)) {
        try {
            $relative = $file.FullName.Substring($Root.Length).TrimStart('\')
            $manifest[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        }
        catch {}
    }

    return $manifest
}

function Compare-Manifest {
    param($Before, $After)

    $all = @{}
    foreach ($key in $Before.Keys) { $all[$key] = $true }
    foreach ($key in $After.Keys)  { $all[$key] = $true }

    $changed = @()

    foreach ($key in $all.Keys) {
        if (-not $Before.ContainsKey($key) -or
            -not $After.ContainsKey($key) -or
            $Before[$key] -ne $After[$key]) {
            $changed += $key
        }
    }

    return @($changed | Sort-Object)
}

function Get-SafePrompt {
    param([string]$Text, [string]$ResolvedMode)

    if ($ResolvedMode -eq "review") {
        return @"
$Text

[AgySafe]
Review the active project workspace.
Do not modify files.
Do not use command, shell, terminal, PowerShell, cmd, bash, or unsandboxed tools.
Use workspace file browsing/reading tools only.
Return the actual review, not a plan to review.
Keep the final answer concise: at most 10 material findings, with file/path, issue, risk, and recommended fix when available.
"@
    }

    if ($ResolvedMode -eq "edit") {
        return @"
$Text

[AgySafe]
You are editing an isolated project copy.
Make the requested changes only inside the active workspace.
Do not access paths outside the workspace.
Do not use command, shell, terminal, PowerShell, cmd, bash, or unsandboxed tools.
Use workspace file reading/editing/writing tools only.
Finish with a concise summary of the changes.
"@
    }

    return $Text
}

function Invoke-OfficialAgy {
    param(
        [string]$Executable,
        [string]$Prompt,
        [string]$ActiveWorkspace,
        [string]$SelectedModel,
        [int]$Timeout
    )

    $savedEnv = @{}
    $removedNames = @()
    $allow = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")

    foreach ($item in @(Get-ChildItem Env:)) {
        if (($item.Name -match 'KEY|TOKEN|SECRET|PASSWORD|PASSWD|COOKIE|CREDENTIAL|PRIVATE') -and
            ($allow -notcontains $item.Name)) {
            $savedEnv[$item.Name] = $item.Value
            Remove-Item ("Env:" + $item.Name) -ErrorAction SilentlyContinue
            $removedNames += $item.Name
        }
    }

    try {
        Push-Location -LiteralPath $ActiveWorkspace

        $args = @(
            "-p", $Prompt,
            "--add-dir", (Resolve-Path -LiteralPath $ActiveWorkspace).Path,
            "--model", $SelectedModel,
            "--sandbox",
            "--print-timeout", ($Timeout.ToString() + "m")
        )

        $lines = @(& $Executable @args 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
        $text = ($lines -join "`n").TrimEnd()

        return [pscustomobject]@{
            exit_code = $exitCode
            output = $text
            removed_environment_names = @($removedNames)
        }
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue

        foreach ($name in $savedEnv.Keys) {
            Set-Item -Path ("Env:" + $name) -Value $savedEnv[$name]
        }
    }
}

function Resolve-Status {
    param([int]$ExitCode, [string]$Output, [string]$ResolvedMode, [object[]]$ChangedFiles)

    $text = $Output.ToLowerInvariant()

    if ($text -match 'user location is not supported|location is not supported for the api use') {
        return "REGION_UNSUPPORTED"
    }

    if ($text -match 'network issue connecting|connection reset|connection aborted|proxyconnect|connectex|timed out connecting') {
        return "NETWORK_ERROR"
    }

    if ($text -match 'headless mode cannot prompt|auto-denied|required the "command" permission|permission denied') {
        return "PERMISSION_DENIED"
    }

    if ($text -match '未设置活跃工作区|没有任何项目文件|工作区为空|no active workspace|no active project|workspace is empty|no project files') {
        return "WORKSPACE_ERROR"
    }

    if ($ExitCode -ne 0) {
        return "ERROR"
    }

    if ($ResolvedMode -eq "edit" -and $ChangedFiles.Count -eq 0) {
        return "NO_CHANGES"
    }

    if ([string]::IsNullOrWhiteSpace($Output)) {
        return "NO_OUTPUT"
    }

    $trimmed = $Output.Trim()

    if ($ResolvedMode -eq "review" -and
        $trimmed.Length -lt 300 -and
        $trimmed -match '让我先|我先|我将先|先让我|let me first|i will first|i''ll first') {
        return "INCOMPLETE"
    }

    return "SUCCESS"
}

function Write-JsonUtf8 {
    param([string]$Path, $Object)

    $jsonText = $Object | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $jsonText, ([System.Text.UTF8Encoding]::new($false)))
}

function Get-RunRoot {
    $path = Join-Path $env:USERPROFILE "AgySafeWorkspaces"
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    return $path
}

function Clean-OldRuns {
    param([string]$Root)

    try {
        $runs = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        $cutoff = (Get-Date).AddDays(-7)

        for ($i = 0; $i -lt $runs.Count; $i++) {
            if ($i -ge 20 -or $runs[$i].LastWriteTime -lt $cutoff) {
                Remove-Item -LiteralPath $runs[$i].FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {}
}

if ($Doctor) {
    $doctorStatus = "OK"
    $doctorError = $null
    $agyExe = $null
    $version = $null

    try {
        $agyExe = Get-AgyExecutable $AgyPath
        $versionLines = @(& $agyExe --version 2>&1 | ForEach-Object { $_.ToString() })
        if ($LASTEXITCODE -ne 0) {
            throw (($versionLines -join "`n").Trim())
        }
        $version = ($versionLines -join "`n").Trim()
    }
    catch {
        $doctorStatus = "ERROR"
        $doctorError = $_.Exception.Message
    }

    $doctor = [ordered]@{
        status = $doctorStatus
        agy_found = [bool]$agyExe
        agy_path = $agyExe
        agy_version = $version
        error = $doctorError
    }

    if ($Json) {
        $doctor | ConvertTo-Json -Depth 5
    }
    else {
        Write-Host ""
        Write-Host "AgySafe"
        Write-Host "-------"
        Write-Host ("agy: " + $(if ($agyExe) { "OK" } else { "NOT FOUND" }))
        if ($version) { Write-Host ("version: " + $version) }
        if ($doctorError) { Write-Host ("error: " + $doctorError) }
    }

    return
}

if ([string]::IsNullOrWhiteSpace($Task)) {
    throw "Task is required"
}

$agy = Get-AgyExecutable $AgyPath
$realWorkspace = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path

if (-not (Test-Path -LiteralPath $realWorkspace -PathType Container)) {
    throw "Workspace must be a directory"
}

$driveRoot = [System.IO.Path]::GetPathRoot($realWorkspace)
if ($realWorkspace.TrimEnd('\') -eq $driveRoot.TrimEnd('\')) {
    throw "Refusing to use a drive root as workspace"
}

$resolvedMode = Resolve-AgySafeMode $Task $Mode
$selectedModel = Resolve-AgySafeModel $Task $resolvedMode $Model

$runRoot = Get-RunRoot
Clean-OldRuns $runRoot

$runId = (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 10))
$runDir = Join-Path $runRoot $runId
$delegatedWorkspace = Join-Path $runDir "workspace"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$snapshot = $null

if ($resolvedMode -eq "ask") {
    New-Item -ItemType Directory -Force -Path $delegatedWorkspace | Out-Null
}
else {
    $snapshot = New-SafeSnapshot $realWorkspace $delegatedWorkspace
}

if ($resolvedMode -ne "ask" -and $snapshot.included.Count -eq 0) {
    $emptyResult = [ordered]@{
        schema = "agysafe.receipt.v1"
        status = "SNAPSHOT_EMPTY"
        mode = $resolvedMode
        selected_model = $selectedModel
        real_workspace = $realWorkspace
        delegated_workspace = $delegatedWorkspace
        included_file_count = 0
        excluded_file_count = $snapshot.excluded.Count
        excluded_files = $snapshot.excluded
        result = ""
        run_dir = $runDir
    }

    Write-JsonUtf8 (Join-Path $runDir "receipt.json") $emptyResult

    if ($Json) { $emptyResult | ConvertTo-Json -Depth 12 }
    else { Write-Host "AgySafe · SNAPSHOT_EMPTY" }

    return
}

$before = Get-Manifest $delegatedWorkspace
$prompt = Get-SafePrompt $Task $resolvedMode
$started = Get-Date

try {
    $agyResult = Invoke-OfficialAgy $agy $prompt $delegatedWorkspace $selectedModel $TimeoutMinutes
}
catch {
    $agyResult = [pscustomobject]@{
        exit_code = 1
        output = $_.Exception.Message
        removed_environment_names = @()
    }
}

$ended = Get-Date
$after = Get-Manifest $delegatedWorkspace
$changedFiles = @(Compare-Manifest $before $after)
$status = Resolve-Status $agyResult.exit_code $agyResult.output $resolvedMode $changedFiles

$handoffPath = Join-Path $runDir "handoff.md"
[System.IO.File]::WriteAllText($handoffPath, $agyResult.output, ([System.Text.UTF8Encoding]::new($true)))

$receipt = [ordered]@{
    schema = "agysafe.receipt.v1"
    status = $status
    run_id = $runId
    mode = $resolvedMode
    requested_model = $Model
    selected_model = $selectedModel
    real_workspace = $realWorkspace
    delegated_workspace = $delegatedWorkspace
    snapshot_used = ($resolvedMode -ne "ask")
    real_workspace_exposed_to_agy = $false
    included_file_count = $(if ($snapshot) { $snapshot.included.Count } else { 0 })
    excluded_file_count = $(if ($snapshot) { $snapshot.excluded.Count } else { 0 })
    excluded_files = $(if ($snapshot) { $snapshot.excluded } else { @() })
    changed_files = $changedFiles
    removed_environment_names = $agyResult.removed_environment_names
    agy_exit_code = $agyResult.exit_code
    handoff_path = $handoffPath
    result = $agyResult.output
    run_dir = $runDir
    sandbox = $true
    dangerous_permission_bypass = $false
    started_at = $started.ToUniversalTime().ToString("o")
    ended_at = $ended.ToUniversalTime().ToString("o")
    elapsed_seconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
}

Write-JsonUtf8 (Join-Path $runDir "receipt.json") $receipt

if ($Json) {
    $receipt | ConvertTo-Json -Depth 12
    return
}

if (-not [string]::IsNullOrWhiteSpace($agyResult.output)) {
    Write-Output $agyResult.output
    Write-Host ""
}

Write-Host ("AgySafe · " + $selectedModel + " · " + $status)

if ($resolvedMode -eq "edit" -and $changedFiles.Count -gt 0) {
    Write-Host ("Isolated changes: " + $changedFiles.Count)
    Write-Host ("Workspace: " + $delegatedWorkspace)
}
