---
created_on: 2026-10-18 09:53
last_modified: 2026-10-18 12:45
status: current
---

# dj-cli

Unified workspace orchestrator and management hub for the DJ toolchain ecosystem.

The **catalog** refers to the curated set of member repositories (applications, CLI utilities, and core libraries) tracked and managed as Git submodules within this workspace.

## Shared commands
- Status overview: `just status`
- Update all submodules: `just update`
- Fetch all submodules: `just fetch`
- Run checks across all submodules: `just check`
- Run tests across all submodules: `just test`
- Run Git command across submodules: `just git <args>`
- Run scoped submodule recipe: `just <tool> <recipe>` (e.g. `just engine vet`, `just tag_track test`)

## Workspace map (Catalog)
- `cobra-help-tree/` -> `cobra-help-tree/AGENTS.md` (CLI command hierarchy ASCII tree renderer for terminal help screens)
- `engine-cli/` -> `engine-cli/AGENTS.md` (Engine DJ database, playlist, and artwork manager)
- `engine-stem-cli/` -> `engine-stem-cli/AGENTS.md` (Engine DJ audio stem inspection, decryption, and extraction utility)
- `fetch-mix-cli/` -> `fetch-mix-cli/AGENTS.md` (DJ mix tracklist and audio fetcher)
- `fetch-track-cli/` -> `fetch-track-cli/AGENTS.md` (Audio downloader and quality verifier)
- `gochromaprint/` -> `gochromaprint/README.md` (Pure Go port of Chromaprint audio fingerprinting library)
- `godeps/` -> `godeps/AGENTS.md` (Zero-token external binary dependency manager and self-update library)
- `goshazam/` -> `goshazam/README.md` (Pure Go port of Shazam reverse-engineered API and audio fingerprinting)
- `tag-track-cli/` -> `tag-track-cli/AGENTS.md` (Audio metadata inspection and tagging utility)

## Shared gotchas
- **Submodule Detached HEAD:** `git submodule update` without `--merge` checks out detached HEADs. Always use `just update` (`git submodule update --remote --merge`) or checkout the appropriate branch before making changes inside a submodule.
- **Uncommitted Submodule Pointers:** Modifying code inside a submodule leaves the submodule dirty and generates uncommitted gitlink changes in `dj-cli`. Run `just status` before attempting updates or committing.
- **Fresh Clones Require Recursive Submodules:** Always clone with `git clone --recurse-submodules` or run `git submodule update --init --recursive` before running workspace recipes.
- **Working Directory Isolation:** Commands dispatched via `just <tool> <recipe>` execute inside that submodule's directory. Never assume the current working directory is the parent workspace root when writing child recipes.

## Shared boundaries
- Always: persist only standing project instructions that apply to future tasks; update the relevant rule in place when it changes
- Never: record task history, progress, handoffs, or dated user amendments in `AGENTS.md`
- Always (code-based projects only): any time code is changed such that results from running that code are changed, a test file must be changed as well; 90% code coverage is required (scripts/ folder is excluded from this rule)
- Always: verify submodules remain on clean tracking branches before updating pointers
- Ask first: adding new submodules, removing existing submodules, or changing upstream tracking URLs in `.gitmodules`
- Never: publish releases, tags, packages, or production deployments automatically without explicit user authorization
- Never: commit or push private internal domains or hostnames to repositories hosted on `github.com`

## References
- `.gitmodules`: Submodule tracking specifications and remote URLs
- `justfile`: Workspace automation recipes and modular submodule declarations
