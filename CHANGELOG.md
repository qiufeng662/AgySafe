# Changelog

## 1.0.2 - 2026-08-31

Large-workspace safety update for code repositories that also contain research data, generated outputs, or other non-code artifacts.

### Snapshot slimming

- Added project-level `.agysafeignore` support with a deliberately small glob subset; blank lines and `#` comments are supported, while negation (`!`) is intentionally ignored in v1.0.2.
- Added default exclusions for common data/model/binary formats such as DTA, XLS/XLSX, Parquet, Feather/Arrow, SAV/SAS, R data, Pickle/Joblib, NumPy, HDF5, PyTorch and ONNX files.
- Small CSV files remain eligible by default so code fixtures and lightweight tabular configuration are not silently removed.
- Snapshot planning now reports candidate file count, total bytes/MB, whether `.agysafeignore` was used, and the largest top-level roots.

### Large-workspace guard

- Added a default 128 MB filtered-snapshot limit before official AGY is launched.
- Added `SNAPSHOT_TOO_LARGE`; oversized workspaces stop early instead of consuming a long AGY run that is likely to time out.
- Added `--max-snapshot-mb <MB>` for intentional overrides (1..2048 MB).
- Oversized-workspace guidance prioritizes `.agysafeignore` or a smaller `--workspace` over simply increasing timeout.

### Tests and docs

- Added hermetic tests for default data exclusions, CSV retention, `.agysafeignore`, size metrics, the large-workspace guard, and CLI snapshot-limit override.
- Updated OpenCode guidance to surface `SNAPSHOT_TOO_LARGE` and the heaviest snapshot roots instead of misdiagnosing the issue as a generic timeout.
- Updated README, architecture, quick start and troubleshooting documentation.

## 1.0.1 - 2026-08-30

Reliability update based on real long-running AGY review diagnostics.

### Routing

- Changed `Model=auto` to **Gemini-first** routing for sustained/high-frequency use.
- Automatic routing no longer selects Claude/GPT implicitly, even if those model names appear in the task text.
- Claude/GPT and other AGY-supported models remain available through explicit `--model` / `-m` overrides.

### Reliability and diagnostics

- Added `QUOTA_EXCEEDED` classification for AGY/service quota messages such as `Individual quota reached`.
- Added optional `quota_type` and `reset_hint` receipt fields.
- Added `recommended_fallback` for Claude/GPT `QUOTA_EXCEEDED`, `INCOMPLETE`, or `NETWORK_ERROR` results; AgySafe never silently reruns on another model.
- Improved `INCOMPLETE` detection for long reviews where official AGY exits 0 after research/tool work but ends with planning-only language instead of a final report.
- Added `workspace_source` and `workspace_note` receipt fields; prompt-embedded GitHub URLs are explicitly treated as context rather than repository selectors.
- CLI and OpenCode integration now surface the actual local `real_workspace` more clearly.

### Fixes and tests

- Fixed the PowerShell 5.1 `--doctor` variable-name collision (`$Doctor` vs `$doctor`).
- Hardened isolated-edit self-test assertions for Windows PowerShell array behavior.
- Expanded fake-AGY tests to cover `--doctor`, Gemini-first premium-model protection, quota parsing/fallback, and exit-0 incomplete reviews.
- Updated README/docs/agent guidance for local-workspace semantics and the new status fields.

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
