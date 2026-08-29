# FAQ

## Is AgySafe an OpenCode plugin?

No.

OpenCode is one supported entry point. The core is the universal `agysafe` CLI.

## Does AgySafe replace `agy`?

No.

AgySafe wraps the official AGY CLI with routing, isolation, filtering and agent integration.

## Does it use a reverse proxy?

No. AgySafe's intended architecture delegates to the official local `agy` CLI.

## Do I have to specify a model?

No.

The default is `Model=auto`.

You can override it at any time with:

```text
--model <slug>
```

or:

```text
-m <slug>
```

## Can Codex use it?

Yes.

Codex can invoke the universal CLI, and the repository includes Agent Skill / `AGENTS.md` integration guidance.

## Can an unsupported agent use it?

If the agent can run terminal commands, usually yes:

```text
agysafe --workspace "." --json "<task>"
```

## Why are project files copied?

For review/edit tasks, AgySafe uses a filtered isolated workspace so AGY does not need the real project directory by default.

## Does edit mode change my real project?

Not automatically.

AgySafe detects changes inside the isolated workspace. Applying those changes to the real project is a separate decision/workflow.

## Why are databases excluded?

Local DBs can be sensitive, large, noisy, or unnecessary for source review. Common DB file extensions are excluded by default.

## Why did my model file disappear from the snapshot?

Large files are skipped. Source-code review generally does not need multi-hundred-MB model weights.

## Why does `NETWORK_ERROR` not trigger a retry?

Automatic repeated retries can waste time and quota and can hide the true cause.

AgySafe prefers explicit failure over pretending progress.

## Can ChatGPT or another LLM help diagnose AgySafe?

Yes.

Use the prompt in [TROUBLESHOOTING.md](TROUBLESHOOTING.md). The structured receipt is designed to make this easier.

## Does AgySafe guarantee my account cannot be restricted?

No.

It uses the official AGY CLI, but service rules, eligibility, quota, region behavior, and abuse prevention remain controlled by Google/Antigravity.
