---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 14:05
status: current
---

# Go Libraries

Core reusable Go libraries and packages consumed across CLI applications and services.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across Go libraries: `just check`
- Run tests across Go libraries: `just test`

## Member repositories
- `cobra-help-tree/` -> Go library rendering Cobra CLI command hierarchies as aligned ASCII trees in terminal help screens
- `godeps/` -> Embeddable zero-token external binary dependency manager and self-update library for Go CLIs
