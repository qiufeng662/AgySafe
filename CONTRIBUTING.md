# Contributing to AgySafe

Thanks for helping improve AgySafe.

The project is intentionally small at the core. The most important contribution rule is:

> **Prefer a thin adapter over a new execution path.**

## Before opening a pull request

Please read:

- [Architecture](docs/ARCHITECTURE.md)
- [Agent integration strategy](docs/AGENT_INTEGRATION.md)
- [Security model](SECURITY.md)

## Development principles

### Keep one core

Do not create separate AGY execution engines for OpenCode, Codex, Claude Code, Cursor, etc.

All host integrations should converge on:

```text
agysafe
```

### Do not hide failures

If AGY reports a network/service/workspace/permission failure, surface it.

Do not turn a failed task into `SUCCESS`.

### Do not add automatic retry loops for long tasks

Retries can waste time and quota and can obscure the actual failure.

### Preserve isolation

Do not expose the real project workspace to AGY by default.

### Preserve official-runtime design

Do not add unofficial AGY protocol emulation or credential extraction to the core.

## Testing

Run:

```powershell
.\tests\self-test.ps1
```

The self-test is hermetic and uses `tests/fake-agy.cmd`.

It should not consume Google/Antigravity quota.

## Adding a new agent integration

A good agent integration usually consists of:

1. a small host instruction/command file;
2. documentation;
3. a call to `agysafe --workspace "." --json ...`.

Avoid changing `bin/agysafe-runtime.ps1` unless the change is actually host-independent.

## Bug reports

A useful report includes:

- Windows / PowerShell version;
- AgySafe version;
- `agy --version`;
- AgySafe status;
- whether the universal CLI works;
- whether the problem is host-specific;
- sanitized receipt/error output.

Do **not** post secrets, authentication material, cookies, private keys, or sensitive project data.

## Pull requests

Keep PRs focused.

If a PR changes security, snapshot filtering, AGY invocation, or workspace handling, explain:

- the concrete failure being fixed;
- why it belongs in the core;
- how the behavior was tested.
