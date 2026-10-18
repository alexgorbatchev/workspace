---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# Terminal UI (TUI)

Terminal layout primitives, external TUI window wrapping, and icon engines.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across TUI tools: `just check`
- Run tests across TUI tools: `just test`

## Member repositories
- `gio-lucide`: Lucide icon bindings for Gio GUI framework
- `go-tui`: Terminal user interface component and layout primitives
- `go-tui-frame`: Go library for wrapping external TUIs with headers, footers, sidebars, and borders via libghostty
