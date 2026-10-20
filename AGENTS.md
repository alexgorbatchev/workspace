---
created_on: 2026-10-18 09:53
last_modified: 2026-10-20 13:00
status: current
---

# workspace

Unified workspace orchestrator and management hub across project categories.

The **catalog** refers to the curated set of member repositories (applications, CLI utilities, and core libraries) tracked and managed as Git submodules within this workspace.

## Shared commands
- Initial workspace setup: `just setup`
- Full synchronization: `just sync`
- Save and publish changed submodule pointers: `just save` (fixed message: `chore: update submodule pointers`)
- Align all tracking branches: `just align [branch]`
- Add member repositories: `just add <paths...>` (GitHub SSH URLs inferred from repository names)
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
- Push committed changes across submodules: `just git push`
- Test workspace orchestration with local Git fixtures: `just test-catalog`

## Catalog operations
- Root `git`, `fetch`, `update`, and `sync` recipes run member operations concurrently, with `[org/repo]` output prefixes. Set `JOBS` to a positive integer to override the default of eight workers, for example `JOBS=16 just fetch`.
- `sync` fetches every branch from every configured remote for root and initialized members, including remotes excluded from `fetch --all`, and prunes stale remote branches. Run `just setup` to initialize missing members first.
- Status uses one row per catalog member with shared column widths and no worker lifecycle messages. The `column` utility is required for formatting.
- Preserve literal Git arguments when forwarding through `just git`; do not interpolate them into shell command text.
- Collect worker failures and return a nonzero exit after remaining jobs finish; do not suppress fetch or merge failures.
- Use `just save` for routine pointer updates. It commits only changed gitlinks, leaves other root edits untouched, and requires changed members to be clean and on tracking branches. Finish already staged root changes separately.
- Keep the pointer commit message fixed. `just save` pushes the root with `--recurse-submodules=on-demand`, publishing required member commits first. The root needs a configured push destination. A repeated invocation retries publication without creating an empty commit.

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
- **Uncommitted Submodule Pointers:** Commit member changes in their own repositories, then use `just save` to record and publish their updated commits from the root. `just status` distinguishes dirty member worktrees from ahead/behind branches.
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
- Never: add private client repositories to the public workspace catalog

## References
- `.gitmodules`: Submodule tracking specifications and remote URLs
- `justfile`: Workspace automation recipes and modular bucket declarations
- `scripts/catalog.sh`: Concurrent member operations and pointer publication
- `scripts/test-catalog.sh`: Offline integration tests for command forwarding, concurrency, failures, and publication
- `scripts/test-failures.sh`: Offline integration tests for root and bucket failure propagation and catalog mutations
- `scripts/test-sync-branches.sh`: Offline integration tests for branch discovery, pruning, and remote fetch failures
