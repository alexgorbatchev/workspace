---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 14:05
status: current
---

# Utilities

General system utilities, specialized converters, font patchers, and scrapers.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across utilities: `just check`
- Run tests across utilities: `just test`

## Member repositories
- `better-fonts-cli/` -> macOS CLI for patching Electron and native applications to use custom monospace fonts
- `cron-person-cli/` -> Per-directory crontab manager with direnv shell integration
- `einstar-vega-cli/` -> Asset fetcher for Einstar Vega 3D scanner without mandatory cloud accounts
- `firecrawl-cli/` -> Single-binary Firecrawl CLI for web scraping and content extraction
- `gws-cache-cli/` -> Local SQLite cache for Google Workspace CLI (`gws`) threads and calendar events
- `pge-cost-cli/` -> California PG&E 24/7 device running cost estimator
- `porter/` -> Linux CLI listing listening TCP ports for processes matching the current repository
- `toon-cli/` -> Go CLI converting JSON, JSONC, and NDJSON input to TOON format
