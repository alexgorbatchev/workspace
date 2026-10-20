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

# All catalog submodules dynamically discovered from .gitmodules

repos := `git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' | sort | tr '\n' ' '`

default:
    @just --list

# One-shot workspace initialization for fresh or existing clones
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Initializing and cloning submodules recursively..."
    git submodule update --init --recursive
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
    catalog_command "$(catalog_label .)" git pull --ff-only || echo "Root has no upstream or cannot fast-forward; continuing..."
    echo "==> Concurrently fetching and merging submodule tracking branches..."
    catalog_run sync
    echo "==> Aligning branches..."
    just align
    echo "==> Sync complete. Current workspace status:"
    just status

# Align all submodules to checkout their tracking branch (avoids detached HEAD)
align branch="main":
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        [ -z "$r" ] && continue
        if [ -d "$r/.git" ] || [ -f "$r/.git" ]; then
            git -C "$r" checkout "{{ branch }}" -q 2>/dev/null || true
        fi
    done
    echo "All active submodules aligned to '{{ branch }}'."

# Add one or more repositories to the monorepo catalog (e.g. `just add utils/better-fonts-cli` or `just add tui/gio-lucide tui/go-tui`)
add *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    for target_path in {{ paths }}; do
        repo_name="$(basename "$target_path")"
        target_url="https://github.com/alexgorbatchev/${repo_name}.git"
        target_branch="main"
        if [ "$repo_name" = "commute-dashboard" ]; then
            target_branch="ccr-91413bd0-wc5mq4"
        fi
        echo "==> Adding submodule $target_path from $target_url ($target_branch)..."
        git submodule add -b "$target_branch" "$target_url" "$target_path"
        git -C "$target_path" checkout "$target_branch" -q 2>/dev/null || true
    done
    just status

# Safely unregister and delete a submodule without manual Git surgery
remove path:
    #!/usr/bin/env bash
    set -euo pipefail
    target_path="{{ path }}"
    echo "==> De-registering submodule $target_path..."
    git submodule deinit -f "$target_path" 2>/dev/null || true
    git rm -f "$target_path"
    rm -rf ".git/modules/$target_path"
    echo "==> Removed $target_path."
    just status

# Show status across all submodules in all buckets
status:
    #!/usr/bin/env bash
    set -euo pipefail
    printf "%-32s %-14s %-10s %s\n" "SUBMODULE" "BRANCH" "STATUS" "UPSTREAM"
    for r in {{ repos }}; do
        [ -z "$r" ] && continue
        if [ ! -d "$r/.git" ] && [ ! -f "$r/.git" ]; then
            printf "%-32s %-14s %-10s %s\n" "$r" "-" "missing" "-"
            continue
        fi
        branch=$(git -C "$r" branch --show-current 2>/dev/null || echo "detached")
        [ -n "$(git -C "$r" status --porcelain 2>/dev/null)" ] && status="dirty" || status="clean"
        upstream=$(git -C "$r" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
        if [ -n "$upstream" ]; then
            counts=$(git -C "$r" rev-list --left-right --count HEAD..."$upstream" 2>/dev/null || echo "0 0")
            ahead=$(echo "$counts" | awk '{print $1}')
            behind=$(echo "$counts" | awk '{print $2}')
            remote_info="+${ahead}/-${behind}"
        else
            remote_info="no-upstream"
        fi
        printf "%-32s %-14s %-10s %s\n" "$r" "$branch" "$status" "$remote_info"
    done

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
    just align

# Run checks across all buckets
check:
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        [ -z "$r" ] && continue
        jf="$r/justfile"
        [ -f "$jf" ] || jf="$r/Justfile"
        if [ -f "$jf" ]; then
            echo "==> Checking $r..."
            if just -f "$jf" --summary | grep -qw "check"; then
                just -f "$jf" check
            elif just -f "$jf" --summary | grep -qw "lint"; then
                just -f "$jf" lint
            elif just -f "$jf" --summary | grep -qw "vet"; then
                just -f "$jf" vet
            fi
        fi
    done

# Run unit tests across all buckets
test: test-catalog
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        [ -z "$r" ] && continue
        jf="$r/justfile"
        [ -f "$jf" ] || jf="$r/Justfile"
        if [ -f "$jf" ]; then
            echo "==> Testing $r..."
            just -f "$jf" test
        fi
    done

# Clean build artifacts and temporary files across all submodules
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        [ -z "$r" ] && continue
        jf="$r/justfile"
        [ -f "$jf" ] || jf="$r/Justfile"
        if [ -f "$jf" ]; then
            if just -f "$jf" --summary | grep -qw "clean"; then
                echo "==> Cleaning $r..."
                just -f "$jf" clean
            fi
        fi
    done
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
    bash tests/catalog.sh

# Save submodule pointers with a fixed message and push root plus required member commits
save:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/catalog.sh
    catalog_save
