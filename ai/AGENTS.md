---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 14:05
status: current
---

# AI

AI coding agent harnesses, protocol implementations, transcript parsers, extensions, and AI policies.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across AI tools: `just check`
- Run tests across AI tools: `just test`

## Member repositories

### claude/
- `claude/claude-workspace/` -> Claude Code plugin for hierarchical out-of-tree workspaces

### pi/
- `pi/pi-env/` -> Pi extension for managing environment variables
- `pi/pi-file-change-reminder/` -> Pi extension injecting reminder notifications on file modifications
- `pi/pi-quick-answer/` -> Pi extension extracting questions and presenting interactive choice selectors
- `pi/pi-skill-library/` -> Reusable AI agent skill library packaging and distribution
- `pi/pi-workspace/` -> Pi extension for hierarchical out-of-tree workspaces

### standards/
- `standards/ai-registry/` -> Canonical AI skills, commands, and harness profiles
- `standards/ts-unused/` -> AI-first dead code, unused type, and unexported symbol audit tool
- `standards/typescript-ai-policy/` -> AI-first linting and formatting policies for TypeScript codebases

### tools/
- `tools/agent-parser/` -> Streaming log parsers, database readers, and harness specs
- `tools/agent-print-session-cli/` -> CLI utility for filtering, summarizing, and printing agent transcripts
- `tools/agent-status/` -> Agent session status reporting daemon and interface
- `tools/agent-watcher/` -> Real-time coding agent session discovery and transcript event streamer
- `tools/agent-wrap/` -> Terminal wrapper with deterministic project, branch, and worktree colors
- `tools/tiktoken-cli/` -> CLI for token counting with OpenAI tiktoken tokenizer
- `tools/workspace-overlay-cli/` -> Writable layered FUSE view of project directories and worktrees
- `tools/youtube-captions-dl/` -> CLI extracting YouTube captions as plain text for LLM context
