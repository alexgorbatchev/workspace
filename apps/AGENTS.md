---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 14:05
status: current
---

# Apps

Standalone web dashboards, local-first applications, and full-stack software prototypes.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across apps: `just check`
- Run tests across apps: `just test`

## Member repositories
- `beads-dashboard/` -> Local-first issue tracker and Kanban interface for beads
- `commute-dashboard/` -> Personal commute transit times and route metrics dashboard
- `floor-plan-ai/` -> Commercial floor plan AI reconstruction prototype with Gemini and Three.js
- `google-photos-sync/` -> Local Google Photos media backup and incremental sync utility
- `monorepo/` -> Turborepo monorepo with Bun, React, Tailwind CSS, tRPC, and Cloudflare Workers
- `tools-to-try/` -> Daily categorized bookmarks and testing sandbox for emerging tools
