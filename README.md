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

# Installation

Clone recursively to fetch the parent repository and all member submodules in a single step:

```bash
git clone --recurse-submodules https://github.com/alexgorbatchev/dj-cli.git monorepo
cd monorepo
```

If you previously cloned without submodules, initialize and fetch them:

```bash
git submodule update --init --recursive
```

# Quick Start

Inspect the current status of all submodules across the workspace:

```bash
just status
```

Inspect status for a specific category:

```bash
just dj status
just go_libs status
```

Sample Output (`just status`):
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
| `just status` | Displays current branch, clean/dirty working tree status, and upstream ahead/behind counts for all submodules |
| `just <bucket> status` | Displays status scoped to a specific category bucket (e.g. `just dj status`, `just go_libs status`) |
| `just fetch` | Concurrently fetches remote updates across all submodules without modifying working directories |
| `just update` | Fetches remotes and merges upstream tracking changes into each submodule |
| `just check` | Runs linters, static analysis, and code quality checks across all submodules |
| `just <bucket> check` | Runs checks scoped to a specific category bucket |
| `just test` | Executes unit test suites across all submodules |
| `just <bucket> test` | Executes unit test suites scoped to a specific category bucket |
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
