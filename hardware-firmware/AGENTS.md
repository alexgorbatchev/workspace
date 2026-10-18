---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 14:05
status: current
---

# Hardware & Firmware

Physical input hardware, custom keyboard firmware patches, diagnostics, and computer vision monitors.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across hardware tools: `just check`
- Run tests across hardware tools: `just test`

## Member repositories
- `cyboard-imprint/` -> Diagnostics, tooling, and firmware patches for Cyboard Imprint split mechanical keyboard with dual trackballs
- `posture-guard/` -> Real-time posture tracking and ergonomics monitoring in Go using local computer vision
