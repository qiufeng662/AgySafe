# Agent Integrations

AgySafe has **one execution core** and multiple thin entry points.

```text
Agent UX
   ↓
agysafe CLI
   ↓
AgySafe core
   ↓
official agy
```

## Integration matrix

| Host | Adapter type | Installed automatically? | Notes |
|---|---|---:|---|
| OpenCode / OpenCode CLI | `/agy` command + Agent Skill | Yes | Native convenience entry point |
| Codex / Codex CLI | Agent Skill + `AGENTS.md` guidance | When detected | Universal CLI remains the fallback |
| Gemini CLI | global `/agy` command | Yes | Uses Gemini CLI custom command |
| Claude Code | `CLAUDE.md` guidance | When detected | Preserves existing content |
| Cursor / Cursor CLI | `AGENTS.md` snippet | Manual template | Universal CLI works without the snippet |
| Other terminal-capable agents | universal CLI | N/A | `agysafe --workspace "." --json ...` |

## Stable compatibility contract

The host-specific files in this directory may evolve.

The stable contract is:

```text
agysafe --workspace "." --json "<task>"
```

This is important: a host update should normally require changing only a thin adapter, not the AgySafe execution core.

Hosts must treat `real_workspace` in the JSON receipt as the source of truth. A GitHub URL written in task text does not select or clone a repository in v1.0.2.

Hosts should also treat `SNAPSHOT_TOO_LARGE` as a workspace-slimming signal, not a generic AGY timeout: surface the snapshot size and heaviest roots and recommend `.agysafeignore` or a narrower workspace.

## Files

```text
integrations/
├─ opencode/
├─ codex/
├─ gemini-cli/
├─ claude-code/
├─ cursor/
└─ generic/
```

## Adding another agent

Before changing the core, try to implement the new host with:

1. a command/instruction template;
2. the universal `agysafe` CLI;
3. documentation.

See [Agent Integration Strategy](../docs/AGENT_INTEGRATION.md).
