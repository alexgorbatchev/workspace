---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# AI

AI coding agent harnesses, protocol implementations, transcript parsers, extensions, and AI policies.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across AI tools: `just check`
- Run tests across AI tools: `just test`

## Sub-groups
- `claude/`: Claude Code plugins and extensions (`claude-workspace`)
- `pi/`: Pi Coding Agent extensions and runtime packages (`pi-env`, `pi-file-change-reminder`, `pi-quick-answer`, `pi-skill-library`, `pi-workspace`)
- `standards/`: Canonical AI skills, AI code-style policies, and dead code detection (`ai-registry`, `ts-unused`, `typescript-ai-policy`)
- `tools/`: Streaming agent parsers, session visualizers, tokenizers, and observability CLIs (`agent-parser`, `agent-print-session-cli`, `agent-status`, `agent-watcher`, `agent-wrap`, `tiktoken-cli`, `workspace-overlay-cli`, `youtube-captions-dl`)
