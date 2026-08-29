# Changelog

## 1.0.0 - 2026-08-29

First public release.

### Core

- Self-contained AgySafe runtime.
- Official `agy` CLI only; no reverse-proxy runtime.
- Automatic task mode and model routing.
- Optional manual model/mode overrides.
- Filtered isolated project snapshots.
- Common secret, credential, cache, dependency and large-file filtering.
- Windows reserved device-name handling (`NUL`, `CON`, `PRN`, `AUX`, `COM1..9`, `LPT1..9`).
- Per-file snapshot copy failures are skipped and recorded instead of aborting the whole run.
- Common secret-like environment variables are removed before AGY execution.
- Absolute `--add-dir` plus process working-directory workspace binding.
- Sandbox mode; no dangerous permission-bypass flag.
- Isolated edit change detection.
- Explicit network/region/workspace/error status classification.

### Agent compatibility

- Clean upgrades remove legacy pre-1.0 AgySafe-owned skill scripts before installing the v1 Agent Skill.
- OpenCode `/agy` invokes the universal `agysafe` CLI directly, eliminating legacy runner ambiguity.
- Added global `agysafe` CLI as the stable compatibility contract.
- OpenCode and OpenCode CLI: `/agy` command + Agent Skill.
- Codex and Codex CLI: `AGENTS.md` instruction integration + common Agent Skill.
- Gemini CLI: global `/agy` custom command.
- Claude Code: optional global `CLAUDE.md` instruction integration.
- Cursor and Cursor CLI: `AGENTS.md` template + universal CLI.
- Universal terminal integration for Windsurf, Cline, Roo Code, Continue, Aider, and other terminal-capable coding agents.
- All adapters call the same AgySafe core; no per-agent execution forks.

### Release quality

- Expanded GitHub documentation with architecture, quick start, agent-assisted setup, troubleshooting, FAQ, support, contribution, issue, and PR templates.
- Added Mermaid architecture/security diagrams and richer bilingual README navigation.

- Windows PowerShell 5.1 UTF-8/BOM compatibility.
- One-command installer and uninstaller.
- Hermetic fake-AGY self-test covering review, edit, isolation, secret filtering, automatic routing, and universal CLI manual override.
- Windows GitHub Actions self-test and PowerShell parser check.
