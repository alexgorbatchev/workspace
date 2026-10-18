---
created_on: 2026-10-18 09:53
last_modified: 2026-10-18 13:55
status: current
---

# monorepo

Unified workspace orchestrator and management hub across project categories.

The **catalog** refers to the curated set of member repositories (applications, CLI utilities, and core libraries) tracked and managed as Git submodules within this workspace.

## Shared commands
- Initial workspace setup: `just setup`
- Full synchronization: `just sync`
- Align all tracking branches: `just align [branch]`
- Add member repository: `just add <path> [url] [branch]`
- Remove member repository: `just remove <path>`
- Clean build artifacts across submodules: `just clean`
- Status overview across all buckets: `just status`
- Scoped bucket status: `just <bucket> status` (e.g. `just dj status`, `just go_libs status`)
- Update all submodules: `just update`
- Fetch all submodules: `just fetch`
- Run checks across all buckets: `just check`
- Run checks within a bucket: `just <bucket> check`
- Run tests across all buckets: `just test`
- Run tests within a bucket: `just <bucket> test`
- Run Git command across submodules: `just git <args>`

## Category map (Buckets)
- `ai/` -> `ai/AGENTS.md` (AI coding agent harnesses, extensions, protocols, standards, and tools)
  - `ai/claude/` (Claude Code plugins)
  - `ai/pi/` (Pi Coding Agent extensions and packages)
  - `ai/standards/` (Canonical skills, policies, and static analysis)
  - `ai/tools/` (Streaming parsers, session CLIs, and observability tools)
- `apps/` -> `apps/AGENTS.md` (Standalone web applications, dashboards, and prototypes)
- `audio-voice/` -> `audio-voice/AGENTS.md` (Audio capture, speech-to-text, and dictation tools)
- `dev-tooling/` -> `dev-tooling/AGENTS.md` (Developer environment, dotfiles, scaffolding, and proxies)
- `dj/` -> `dj/AGENTS.md` (DJ library database, audio acquisition, stems, and tagging toolchain)
- `go-libs/` -> `go-libs/AGENTS.md` (Core reusable Go libraries and CLI packages)
- `hardware-firmware/` -> `hardware-firmware/AGENTS.md` (Physical devices, keyboard firmware, and vision monitors)
- `remarkable/` -> `remarkable/AGENTS.md` (reMarkable cloud sync gateways, vector stroke renderers, and planners)
- `tui/` -> `tui/AGENTS.md` (Terminal UI layout primitives, icons, and libghostty wrappers)
- `ui-design/` -> `ui-design/AGENTS.md` (Monospace design systems, React component libraries, and canvas editors)
- `utils/` -> `utils/AGENTS.md` (General system utilities, font patchers, and scrapers)

## Shared gotchas
- **Submodule Detached HEAD:** `git submodule update` without `--merge` checks out detached HEADs. Always use `just update` (`git submodule update --remote --merge`) or checkout the appropriate branch before making changes inside a submodule.
- **Uncommitted Submodule Pointers:** Modifying code inside a submodule leaves the submodule dirty and generates uncommitted gitlink changes in the root. Run `just status` before attempting updates or committing.
- **Fresh Clones Require Recursive Submodules:** Always clone with `git clone --recurse-submodules` or run `git submodule update --init --recursive` before running workspace recipes.
- **Working Directory Isolation:** Commands dispatched via `just <bucket> <recipe>` execute inside that bucket's directory. Never assume the current working directory is the parent workspace root when writing child recipes.

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
- `justfile`: Workspace automation recipes and modular bucket declarations
