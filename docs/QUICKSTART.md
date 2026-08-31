# Quick Start

This guide is intentionally short. If you prefer, your coding agent can perform these steps for you; see [AGENT_SETUP.md](AGENT_SETUP.md).

## 1. Requirements

- Windows
- Windows PowerShell 5.1+
- official `agy` CLI installed
- working AGY authentication on the machine

Check:

```powershell
agy --version
```

## 2. Install AgySafe

From the repository root:

```powershell
.\install.ps1
```

The installer runs a local fake-AGY self-test before installing.

After installation, restart already-open coding agents so they inherit the updated user PATH.

## 3. Verify

```powershell
agysafe --doctor
```

Then perform a short smoke test:

```powershell
agysafe --workspace "." --json --timeout 2 "只回复 OK"
```

Expected essentials:

```json
{
  "status": "SUCCESS",
  "mode": "ask",
  "requested_model": "auto",
  "selected_model": "gemini-3.7-flash-low",
  "result": "OK"
}
```

The exact model may change if routing rules change in a later release.

## 4. Use it

Automatic (Gemini-first):

```text
agysafe "review the current project"
```

Automatic routing uses Gemini models only in v1.0.2. Claude/GPT are explicit-only.

Manual model:

```text
agysafe --model claude-sonnet-4-6 "review the current project"
```

Agent-friendly JSON:

```text
agysafe --workspace "." --json "review the current project"
```

For repositories that contain lots of data or generated outputs, add `.agysafeignore` at the project root:

```text
outputs/
临界实验/
外部校准/
*.zip
```

The default filtered-snapshot limit is 128 MB. If exceeded, AgySafe returns `SNAPSHOT_TOO_LARGE` before AGY runs. Only raise the limit when intentional:

```text
agysafe --max-snapshot-mb 256 --workspace "." --json "review the current project"
```

The task text does not change the local workspace. A GitHub URL inside the prompt is not automatically cloned; `real_workspace` in the receipt is the source of truth.

## 5. Host examples

### OpenCode

```text
/agy 审查一下当前项目
```

### Codex

```text
Use AgySafe to review the current project.
```

### Gemini CLI

```text
/agy review the current project
```

### Any terminal-capable agent

Ask it to run:

```text
agysafe --workspace "." --json "<your task>"
```

## Next

- [Let an agent configure AgySafe](AGENT_SETUP.md)
- [Understand the architecture](ARCHITECTURE.md)
- [Diagnose problems](TROUBLESHOOTING.md)
- [Understand agent compatibility](AGENT_INTEGRATION.md)
