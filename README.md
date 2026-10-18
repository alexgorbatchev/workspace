`dj-cli` is a unified workspace manager and CLI hub for the DJ toolchain, coordinating database inspection, stem generation, track fetching, and metadata tagging tools from a single repository.

# What It Does

- **Centralized Project Management**: Tracks and coordinates the nine specialized DJ toolchain projects and libraries (`cobra-help-tree`, `engine-cli`, `engine-stem-cli`, `fetch-mix-cli`, `fetch-track-cli`, `gochromaprint`, `godeps`, `goshazam`, and `tag-track-cli`) as Git submodules.
- **Parallel Remote Synchronization**: Fetches upstream changes across all tools concurrently to minimize network wait times.
- **Conflict-Free Updates**: Fast-forwards submodules tracking their remote `main` branches and avoids clobbering uncommitted working tree changes.
- **Cross-Project Verification**: Executes static analysis, linting, and unit test suites across all member repositories with single workspace commands.
- **Targeted Submodule Delegation**: Dispatches lifecycle recipes directly to individual tools without changing working directories.

# How It Works

- Aggregates member repositories through standard Git submodules configured to follow upstream tracking branches.
- Inspects the local status, current branch, and remote divergence for each tool in the workspace.
- Fetches all remotes in parallel and applies fast-forward merge updates to keep local checkouts aligned with upstream releases.
- Routes execution requests down to individual project `justfile` definitions while executing inside the appropriate submodule folder.

# How it Really Works

- Remote references and tracking branches are stored in `.gitmodules`, allowing clones on new machines to replicate the full development tree in one step.
- Update operations run `git submodule update --remote --merge`, pulling remote changes into the tracked branch rather than leaving submodules in a detached `HEAD` state.
- Parallel network fetches invoke background Git processes simultaneously and block at a single synchronization barrier before executing merge operations.
- Recipes dispatched to member tools run with their working directory scoped directly to the target submodule directory, ensuring tool-local file paths and configuration files resolve correctly.
- Any project containing unstaged modifications or uncommitted changes is detected before destructive operations are attempted, preventing accidental overwrite of active work.

# Prerequisites

- [Git](https://git-scm.com/) (version 2.30 or newer)
- [Just](https://github.com/casey/just) command runner

# Installation

Clone `dj-cli` recursively to fetch the parent repository and all member submodules in a single step:

```bash
git clone --recurse-submodules https://github.com/alexgorbatchev/dj-cli.git
cd dj-cli
```

If you previously cloned without submodules, initialize and fetch them:

```bash
git submodule update --init --recursive
```

# Quick Start

Inspect the current status of all member tools across the workspace:

```bash
just status
```

Sample Output:
```
SUBMODULE              BRANCH         STATUS     UPSTREAM
cobra-help-tree        main           clean      +0/-0
engine-cli             main           clean      +0/-0
engine-stem-cli        main           clean      +0/-0
fetch-mix-cli          main           clean      +0/-0
fetch-track-cli        main           clean      +0/-0
gochromaprint          main           clean      +0/-0
godeps                 main           clean      +0/-0
goshazam               main           clean      +0/-0
tag-track-cli          main           clean      +0/-0
```

Pull the latest updates across all tools:

```bash
just update
```

Sample Output:
```
All submodules fetched.
```

# Commands

| Command | Description |
| :--- | :--- |
| `just status` | Displays current branch, clean/dirty working tree status, and upstream ahead/behind counts for all submodules |
| `just fetch` | Concurrently fetches remote updates across all submodules without modifying working directories |
| `just update` | Fetches remotes and merges upstream tracking changes into each submodule |
| `just check` | Runs linters, static analysis, and code quality checks across all submodules |
| `just test` | Executes unit test suites across all submodules |
| `just git <args>` | Runs an arbitrary Git command across every submodule via `git submodule foreach` |
| `just <tool> <recipe>` | Delegates directly to a specific submodule's recipe (e.g. `just engine check`, `just tag_track test`) |

# License

[MIT License](LICENSE) (c) 2026 Alex Gorbatchev
