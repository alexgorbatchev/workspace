---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# reMarkable Ecosystem

Cloud sync gateways, binary vector stroke parsers, document search, and template rendering for the reMarkable paper tablet.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across reMarkable tools: `just check`
- Run tests across reMarkable tools: `just test`

## Member repositories
- `go-remarkable-cloud`: Go client library for the reMarkable Cloud Sync v3 API
- `go-remarkable-render`: Go library for compositing template PDFs and vector stroke layers to high-resolution PNGs
- `go-rmscene`: reMarkable tablet v6 binary stroke file (`.rm`) parser and layered SVG renderer
- `remarkable-cli`: CLI gateway for Cloud Sync v3, document search, vector decoding, and page rendering
- `remarkable-daily-planner-generator`: Customizable monospace daily planner generator in Python/Typst for e-paper
