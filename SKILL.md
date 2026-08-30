---
name: agysafe
description: Delegate an explicit user-requested task to official Antigravity through AgySafe.
---

# AgySafe

Use AgySafe only when the user explicitly asks to use AgySafe, AGY, Antigravity, or invokes a host-specific AgySafe command.

## Universal invocation

Prefer the installed universal CLI:

```text
agysafe --workspace "<current project directory>" --json "<task>"
```

Defaults:

```text
--model auto
--mode auto
```

Optional overrides:

```text
--model <slug>
-m <slug>
--mode <auto|ask|review|edit>
--timeout <minutes>
```

Examples:

```text
agysafe --workspace "." --json "review the current project"
agysafe --workspace "." --model claude-sonnet-4-6 --json "review the current project"
agysafe --workspace "." -m gemini-3.1-pro-high --mode review --json "analyze the architecture"
```

Rules:

- Preserve the user's task after removing only recognized AgySafe host options.
- Use the current project directory as the workspace.
- Treat GitHub URLs inside the task as context only. Do not claim that a URL was reviewed unless it matches `real_workspace`; v1.0.1 does not auto-clone prompt URLs.
- Surface `real_workspace` from the receipt when reporting what project was actually reviewed.
- Default to automatic model and mode selection. `Model=auto` is Gemini-first; Claude/GPT require an explicit `--model` / `-m`.
- Respect an explicitly requested `--model` / `-m` exactly. Do not infer a premium model solely from words such as Claude/GPT inside the task.
- Never add dangerous permission-bypass flags.
- Do not disable snapshot isolation.
- On `SUCCESS`, return the actual delegated result and selected model.
- On non-success, report the actual status briefly and do not pretend completion. Surface `recommended_fallback` / `reset_hint` when present.
- Do not repeatedly retry failed long tasks automatically.
- Edit mode changes only the isolated copy; do not silently copy edits into the real project.
