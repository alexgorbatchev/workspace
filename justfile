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
repos := `git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | sort | tr '\n' ' '`

default:
    @just --list

# Show status across all submodules in all buckets
status:
    #!/usr/bin/env bash
    set -euo pipefail
    printf "%-32s %-14s %-10s %s\n" "SUBMODULE" "BRANCH" "STATUS" "UPSTREAM"
    for r in {{ repos }}; do
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

# Fetch updates for all submodules in parallel
fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        if [ -d "$r" ]; then
            git -C "$r" fetch --all --prune -q 2>/dev/null &
        fi
    done
    wait
    echo "All submodules fetched."

# Update all submodules from their tracking branches
update: fetch
    #!/usr/bin/env bash
    set -euo pipefail
    git submodule update --remote --merge

# Run checks across all buckets
check:
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
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
test:
    #!/usr/bin/env bash
    set -euo pipefail
    for r in {{ repos }}; do
        jf="$r/justfile"
        [ -f "$jf" ] || jf="$r/Justfile"
        if [ -f "$jf" ]; then
            echo "==> Testing $r..."
            just -f "$jf" test
        fi
    done

# Run arbitrary git command across all submodules
git *args:
    git submodule foreach 'git {{ args }}'
