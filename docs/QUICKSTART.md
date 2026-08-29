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

Automatic:

```text
agysafe "review the current project"
```

Manual model:

```text
agysafe --model claude-sonnet-4-6 "review the current project"
```

Agent-friendly JSON:

```text
agysafe --workspace "." --json "review the current project"
```

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
