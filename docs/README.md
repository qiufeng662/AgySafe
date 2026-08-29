# AgySafe Documentation

Start here if the main README answered **what AgySafe is** and you now want the details.

| Document | Use it when... |
|---|---|
| [Quick Start](QUICKSTART.md) | you want to install and verify AgySafe quickly |
| [Agent-assisted Setup](AGENT_SETUP.md) | you want Codex/OpenCode/another agent to configure it for you |
| [Architecture](ARCHITECTURE.md) | you want to understand the project design and execution flow |
| [Agent Integration](AGENT_INTEGRATION.md) | you want to add or understand another coding agent |
| [Troubleshooting](TROUBLESHOOTING.md) | something failed and you want to locate the failing layer |
| [FAQ](FAQ.md) | you have a common usage/design question |
| [Security](../SECURITY.md) | you want to understand isolation, filtering, and limitations |
| [Contributing](../CONTRIBUTING.md) | you want to change or extend AgySafe |

## The shortest mental model

```text
Your agent
   ↓
agysafe
   ↓
safe isolated workspace + routing
   ↓
official agy
```

If a problem occurs, troubleshoot by layer rather than immediately changing source code.
