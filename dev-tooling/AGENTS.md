---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# Developer Tooling

Core developer environment managers, scaffolding generators, dotfiles, and local HTTPS proxies.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across dev tooling: `just check`
- Run tests across dev tooling: `just test`

## Member repositories
- `devhost`: Zero-configuration local HTTPS proxy replacing localhost port juggling
- `dotfiles`: Automated local dotfiles management CLI
- `dotfiles-catalog`: Searchable tool definition catalog for dotfiles installer
- `go-scaffold-cli`: Scaffolding CLI for standardized Go CLI and library repositories
