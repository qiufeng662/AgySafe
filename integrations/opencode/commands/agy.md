---
description: 通过 AgySafe 使用 Antigravity
---

将 `$ARGUMENTS` 解析为 AgySafe 请求，并直接通过终端执行已安装的全局 `agysafe` 命令。
不要调用旧版 Python AgySafe、旧版 `scripts\agysafe.ps1`，也不要绕到其他 AgySafe runner。

默认：
- Model=auto（Gemini-first；不会自动选择 Claude/GPT）
- Mode=auto
- Workspace=当前 OpenCode 项目目录

重要：
- `$ARGUMENTS` 里的 GitHub URL 只是任务文本，不会改变 workspace，也不会自动 clone 仓库。
- 执行完成后，以 JSON receipt 的 `real_workspace` 为实际审查目标，不要根据提示词里的 URL 猜测仓库。
- 向用户汇报时明确显示实际 `real_workspace`。

可选参数：
- `--model <slug>` 或 `-m <slug>`
- `--mode <auto|ask|review|edit>`

把这些可选参数从 Task 中移除后，剩余文本保持为用户原始任务。

执行形态：

```text
agysafe --workspace "<current project directory>" --json [optional AgySafe options] "<task>"
```

示例：

`/agy 审查一下当前项目`

执行：

```text
agysafe --workspace "<current project directory>" --json "审查一下当前项目"
```

`/agy --model claude-sonnet-4-6 审查一下当前项目`

执行：

```text
agysafe --workspace "<current project directory>" --model claude-sonnet-4-6 --json "审查一下当前项目"
```

`/agy -m gemini-3.1-pro-high 分析整个项目架构`

执行：

```text
agysafe --workspace "<current project directory>" -m gemini-3.1-pro-high --json "分析整个项目架构"
```

成功时直接返回实际 AGY 结果、实际 `selected_model` 和 `real_workspace`。
非 SUCCESS 时只简洁报告真实状态，不假装完成，不自行连续重试；若 receipt 包含 `recommended_fallback` 或 `reset_hint`，一并提示。
