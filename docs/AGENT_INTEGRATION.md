# Agent Integration Strategy

AgySafe supports many agents by keeping one stable execution contract:

```text
agysafe
```

## Why not build a full plugin for every agent?

Because host plugin formats change independently.

If workspace isolation, model routing, authentication assumptions, and AGY execution were duplicated across every integration, AgySafe would quickly become difficult to maintain.

Instead:

```text
host adapter -> agysafe CLI -> core
```

## Integration tiers

### Tier 1 — native convenience

Hosts with stable, simple customization mechanisms can receive a dedicated entry point.

Examples in this repository:

- OpenCode `/agy`
- Gemini CLI `/agy`

### Tier 2 — persistent instruction integration

Hosts that read global/project instruction files can be taught to call `agysafe`.

Examples:

- Codex / Codex CLI via `AGENTS.md`
- Claude Code via `CLAUDE.md`
- Cursor via `AGENTS.md`

### Tier 3 — universal terminal compatibility

Any agent that can execute a local shell command can use:

```text
agysafe --workspace "." --json "<task>"
```

No dedicated plugin is required.

## Contract for agent authors

Agents should:

1. preserve the user task;
2. use the current project directory as `--workspace`;
3. default to automatic model/mode;
4. pass explicit model overrides through unchanged;
5. request `--json`;
6. return the real AgySafe result;
7. not pretend success on a non-success status;
8. not automatically retry long failures;
9. not bypass AgySafe isolation.

## Recommended generic instruction block

```markdown
## AgySafe

When the user explicitly asks to use AgySafe / AGY / Antigravity:

`agysafe --workspace "." --json "<exact task>"`

Defaults are automatic.
Respect explicit model/mode overrides.
Return the real result.
Do not repeatedly retry long failures.
```

A ready-to-copy template is available in:

```text
integrations/generic/AGENTS.md.snippet
```

## Adding another agent

A new integration should ideally require only:

- one instruction file, command file, or small adapter;
- documentation;
- no changes to `bin/agysafe-runtime.ps1`.

If a new host requires changing the execution core, first verify that the need is truly host-independent.
