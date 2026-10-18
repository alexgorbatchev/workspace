---
created_on: 2026-10-18 13:40
last_modified: 2026-10-18 13:40
status: current
---

# DJ Toolchain

Audio acquisition, library database management, stem separation, acoustic fingerprinting, and metadata tagging for DJ workflows.

Inherits all standing workspace boundaries, code coverage requirements (90%), and Git conventions from the [parent monorepo AGENTS.md](../AGENTS.md).

## Local commands
- Status overview: `just status`
- Run checks across DJ tools: `just check`
- Run tests across DJ tools: `just test`

## Member repositories
- `dmx-lights`: DMX lighting control fixtures and stage automation
- `engine-cli`: Engine DJ collection database (`m.db`) inspection, playlist sync, and artwork caching
- `engine-dj-app`: Engine DJ desktop application inspection and binary bridge
- `engine-stem-cli`: Engine DJ stem container inspection, decryption, and multi-channel stem extraction
- `fetch-mix-cli`: DJ mix tracklist parser and set-level batch audio acquisition orchestrator
- `fetch-track-cli`: Single-track acquisition engine with Goertzel spectral frequency analysis and verifier
- `gochromaprint`: Pure Go port of Chromaprint audio fingerprinting library (AcoustID)
- `goshazam`: Pure Go port of Shazam reverse-engineered API and audio fingerprinting algorithm
- `shazam-cli`: Standalone CLI audio recognition utility powered by goshazam
- `tag-track-cli`: Audio file metadata tagger and square cover art normalization engine
