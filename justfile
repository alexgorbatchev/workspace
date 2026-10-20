set dotenv-load := false

# Modular bucket justfiles
mod? ai 'ai/justfile'
mod? apps 'apps/justfile'
mod? audio_voice 'audio-voice/justfile'
mod? dev_tooling 'dev-tooling/justfile'
mod? dj 'dj/justfile'
mod? go_libs 'go-libs/justfile'
mod? hardware_firmware 'hardware-firmware/justfile'
mod? remarkable 'remarkable/justfile'
mod? tui 'tui/justfile'
mod? ui_design 'ui-design/justfile'
mod? utils 'utils/justfile'

default:
    @just --list

# Initialize submodules with concurrent cloning (JOBS=8 by default)
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    jobs="${JOBS:-8}"
    if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
        echo "JOBS must be a positive integer" >&2
        exit 1
    fi
    echo "==> Initializing and cloning submodules recursively ($jobs workers)..."
    git submodule update --init --recursive --jobs "$jobs"
    echo "==> Aligning submodules to tracking branches..."
    just align
    echo "==> Setup complete. Current workspace status:"
    just status

# Pull root, sync submodules concurrently with org/repo prefixes, and show status (JOBS=8)
sync:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    echo "==> Pulling root monorepo updates..."
    catalog_command "$(catalog_label .)" git pull --ff-only
    echo "==> Concurrently fetching and merging submodule tracking branches..."
    catalog_run sync
    echo "==> Sync complete. Current workspace status:"
    just status

# Align submodules concurrently to configured branches, or an explicit override
[positional-arguments]
align branch="":
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run align "$1"
    echo "All active submodules aligned."

# Add one or more repositories to the monorepo catalog (e.g. `just add utils/better-fonts-cli` or `just add tui/gio-lucide tui/go-tui`)
[positional-arguments]
add *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    for target_path in "$@"; do
        repo_name="$(basename "$target_path")"
        target_url="https://github.com/alexgorbatchev/${repo_name}.git"
        target_branch="main"
        if [ "$repo_name" = "commute-dashboard" ]; then
            target_branch="ccr-91413bd0-wc5mq4"
        fi
        echo "==> Adding submodule $target_path from $target_url ($target_branch)..."
        git submodule add -b "$target_branch" "$target_url" "$target_path"
        git -C "$target_path" switch -- "$target_branch"
    done
    just status

# Safely unregister and delete a submodule without manual Git surgery
[positional-arguments]
remove path:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    target_path="$1"
    echo "==> De-registering submodule $target_path..."
    catalog_remove "$target_path"
    echo "==> Removed $target_path."
    just status

# Show status across all submodules in all buckets
status:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    printf "%-32s %-14s %-10s %s\n" "SUBMODULE" "BRANCH" "STATUS" "UPSTREAM"
    catalog_run status

# Fetch all submodules concurrently with org/repo prefixes (JOBS=8 by default)
fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run fetch
    echo "All submodules fetched."

# Update submodules concurrently from their tracking branches (JOBS=8 by default)
update:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run update

# Run checks across all buckets
check:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run check

# Run unit tests across all buckets
test: test-catalog
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run test

# Clean build artifacts and temporary files across all submodules
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run clean
    echo "All submodules cleaned."

# Run Git concurrently across submodules with org/repo prefixes (JOBS=8 by default)
[positional-arguments]
git *args:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_run git "$@"

# Test workspace orchestration against isolated local Git repositories
test-catalog:
    bash scripts/test-catalog.sh
    bash scripts/test-failures.sh

# Save submodule pointers with a fixed message and push root plus required member commits
save:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_save
