`monorepo` is a unified multi-category workspace orchestrator and management hub, coordinating projects across AI agents, applications, audio/voice, developer tooling, DJ tools, Go libraries, hardware firmware, e-paper, terminal interfaces, design systems, and utilities.

# What It Does

- **Category-Based Organization**: Groups repositories into clean domain buckets (`ai/`, `apps/`, `audio-voice/`, `dev-tooling/`, `dj/`, `go-libs/`, `hardware-firmware/`, `remarkable/`, `tui/`, `ui-design/`, and `utils/`).
- **Parallel Remote Synchronization**: Concurrently fetches upstream changes across member repositories to minimize network wait times.
- **Conflict-Free Updates**: Fast-forwards submodules tracking their remote `main` branches while protecting uncommitted working tree changes.
- **Two-Tier Lifecycle Orchestration**: Runs checks, tests, and status reports either workspace-wide (`just check`) or scoped to specific categories (`just dj check`, `just go_libs status`).
- **Dynamic Submodule Discovery**: Discovers submodules dynamically from `.gitmodules` without manual array duplication in task files.

# How It Works

- Aggregates member repositories through standard Git submodules configured to follow upstream tracking branches.
- Routes execution requests down through category `justfile` definitions while executing inside the appropriate bucket folder.
- Inspects local branch state, uncommitted changes, and remote divergence for each submodule in the workspace.

# Prerequisites

- [Git](https://git-scm.com/) (version 2.30 or newer)
- [Just](https://github.com/casey/just) command runner
- `column` (util-linux) for status table formatting
- SSH access to the catalog repositories on GitHub

# Installation & Setup

Clone the repository and run `just setup` to initialize, clone, and align all submodules in one command:

```bash
git clone git@github.com:alexgorbatchev/workspace.git workspace
cd workspace
just setup
```

# Quick Start

Inspect the current status of all submodules across the workspace:

```bash
just status
```

Synchronize the workspace (fetches every branch from each remote, pulls root updates, aligns initialized members to their configured branches, and merges their upstream changes):

```bash
just sync
```

Inspect status or run checks for a specific category:

```bash
just dj status
just go_libs status
just dj check
```

Add a new repository to a category bucket:

```bash
just add utils/better-fonts-cli
```

Status prints one row per catalog member, with columns sized to the displayed paths and branch names. Bucket status uses the same table format.

Sample output (`just status`):
```text
SUBMODULE                        BRANCH         STATUS     UPSTREAM
dj/engine-cli                    main           clean      +0/-0
dj/engine-stem-cli               main           clean      +0/-0
dj/fetch-mix-cli                 main           clean      +0/-0
dj/fetch-track-cli               main           clean      +0/-0
dj/gochromaprint                 main           clean      +0/-0
dj/goshazam                      main           clean      +0/-0
dj/tag-track-cli                 main           clean      +0/-0
go-libs/cobra-help-tree          main           clean      +0/-0
go-libs/godeps                   main           clean      +0/-0
```

Run checks across all categories or a single bucket:

```bash
# Across all buckets
just check

# Scoped to one bucket
just dj check
just go_libs check
```

# Commands

| Command | Description |
| :--- | :--- |
| `just setup` | One-shot workspace setup: recursively initializes submodules, aligns tracking branches, and displays status |
| `just sync` | Fetches all remote branches for root and initialized members, pulls root updates, aligns members, and merges their tracking branches |
| `just status` | Displays current branch, clean/dirty working tree status, and upstream ahead/behind counts for all submodules |
| `just <bucket> status` | Displays status scoped to a specific category bucket (e.g. `just dj status`, `just go_libs status`) |
| `just align [branch]` | Aligns all submodules to checkout their tracking branch (defaults to `main`), preventing detached HEADs |
| `just add <paths...>` | Adds repositories as submodules using `git@github.com:alexgorbatchev/<name>.git` |
| `just remove <path>` | Safely unregisters and removes a submodule from `.gitmodules` and Git index |
| `just fetch` | Concurrently fetches remote updates across all submodules without modifying working directories |
| `just update` | Fetches remotes and merges upstream tracking changes into each submodule |
| `just check` | Runs linters, static analysis, and code quality checks across all submodules |
| `just <bucket> check` | Runs checks scoped to a specific category bucket |
| `just test` | Executes unit test suites across all submodules |
| `just <bucket> test` | Executes unit test suites scoped to a specific category bucket |
| `just clean` | Cleans build binaries, coverage profiles, and temporary artifacts across all submodules |
| `just git <args>` | Runs an arbitrary Git command across every submodule via `git submodule foreach` |

# Categories

| Category | Description |
| :--- | :--- |
| `ai/` | AI coding agent harnesses, extensions, protocols, standards, and tools |
| `apps/` | Standalone web applications, dashboards, and prototypes |
| `audio-voice/` | Audio recording, speech-to-text, transcription, and dictation tools |
| `dev-tooling/` | Developer environment, dotfiles, scaffolding, and local HTTPS proxies |
| `dj/` | DJ library database, audio acquisition, stems, and tagging toolchain |
| `go-libs/` | Core reusable Go libraries and CLI packages |
| `hardware-firmware/` | Physical devices, keyboard firmware, and posture monitors |
| `remarkable/` | reMarkable paper tablet cloud sync, vector stroke renderers, and planners |
| `tui/` | Terminal user interface layout primitives, icons, and libghostty wrappers |
| `ui-design/` | Monospace design systems, React component libraries, and canvas editors |
| `utils/` | General system utilities, font patchers, and scrapers |

# License

[MIT License](LICENSE) (c) 2026 Alex Gorbatchev
