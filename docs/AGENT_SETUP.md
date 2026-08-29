# Agent-assisted Setup

AgySafe is designed so a terminal-capable coding agent can configure it for a user.

This is useful when the user does not want to manually inspect PowerShell, PATH, agent instructions, or smoke-test output.

## Recommended setup prompt

Paste this into your coding agent:

```text
Help me set up the AgySafe repository on this Windows machine.

Before doing anything:
- read README.md / README_CN.md;
- read docs/QUICKSTART.md and docs/AGENT_SETUP.md.

Then:
1. confirm official `agy` exists with `agy --version`;
2. run `.\install.ps1` from the AgySafe repository;
3. do not install a reverse proxy;
4. do not replace or extract AGY authentication credentials;
5. do not modify unrelated system settings;
6. verify `agysafe --doctor`;
7. run the documented short smoke test only;
8. if a step fails, classify the failing layer before editing AgySafe;
9. do not repeatedly run long AGY reviews while diagnosing;
10. summarize exactly what was changed.

If the host agent has a native AgySafe integration, verify it after the universal CLI works.
```

## Minimal verification prompt

```text
Verify this AgySafe installation without changing source code.

Run:
1. `Get-Command agysafe`
2. `agysafe --doctor`
3. `agy --version`
4. `agysafe --workspace "." --json --timeout 2 "只回复 OK"`

Tell me which layer passed or failed:
- PATH / installation
- AgySafe
- official AGY
- network/service
- host-agent integration
```

## OpenCode verification prompt

```text
Verify the OpenCode AgySafe integration.

First confirm the universal `agysafe` CLI works.
Then run one short `/agy` task with automatic model selection.
Do not perform a long project review until the short task succeeds.
Report the actual selected_model and status.
```

## Codex verification prompt

```text
Verify AgySafe from Codex.

Do not start with a full repository review.
Use the terminal to run:
`agysafe --workspace "." --json --timeout 2 "只回复 OK"`

Confirm:
- status is SUCCESS;
- requested_model is auto;
- selected_model is populated;
- result is OK.

Only after this succeeds should we test a real project task.
```

## When an agent should stop

The agent should stop changing AgySafe if the evidence shows:

- official AGY reports a network failure;
- the service reports region/eligibility restrictions;
- authentication is unavailable;
- the host kills a long-running terminal process;
- AGY itself times out while AgySafe has already launched it correctly.

These are not automatically AgySafe source-code defects.

## When a source patch is justified

A source patch is appropriate when evidence shows:

- command-line parsing is wrong;
- workspace/snapshot construction is wrong;
- sensitive files are copied incorrectly;
- the official AGY executable is invoked with the wrong arguments;
- receipt/status parsing is incorrect;
- a supported host adapter invokes the wrong AgySafe command.

Always explain the root cause before modifying source.
