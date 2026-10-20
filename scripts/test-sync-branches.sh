#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.tmp"
fixture="$(mktemp -d "$root/.tmp/sync-branches-test.XXXXXX")"
trap 'result=$?; if [ "$result" -ne 0 ] && [ -f "$fixture/output" ]; then cat "$fixture/output"; fi; rm -rf "$fixture"; exit "$result"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_ALLOW_PROTOCOL=file JOBS=2

git init -q -b main "$fixture/origin"
git -C "$fixture/origin" commit -q --allow-empty -m initial
git -C "$fixture/origin" branch topic/origin
git clone -q "$fixture/origin" "$fixture/secondary"
git -C "$fixture/secondary" branch topic/secondary

for scope in root bucket; do
    workspace="$fixture/$scope"
    mkdir -p "$workspace/utils"
    cp "$root/justfile" "$workspace/justfile"
    cp -R "$root/scripts" "$workspace/scripts"
    cp "$root/utils/justfile" "$workspace/utils/justfile"
    cd "$workspace"
    git init -q -b main
    git submodule add -q -b main "$fixture/origin" 'utils/member with spaces'
    git commit -qm catalog
    git clone -q --bare . "$fixture/$scope-root.git"
    git remote add origin "$fixture/$scope-root.git"
    git fetch -q origin
    git branch --set-upstream-to=origin/main main >/dev/null
    git -C "$fixture/$scope-root.git" branch topic/workspace
    git remote set-branches origin main
    git -C 'utils/member with spaces' remote set-branches origin main
    git -C 'utils/member with spaces' remote add -t main secondary "$fixture/secondary"
    # Explicit sync must fetch even a remote excluded from `fetch --all`.
    git -C 'utils/member with spaces' config remote.secondary.skipFetchAll true
    git -C 'utils/member with spaces' update-ref -d refs/remotes/origin/topic/origin
    git -C 'utils/member with spaces' update-ref refs/remotes/origin/deleted HEAD
    before="$(git -C 'utils/member with spaces' rev-parse HEAD)"

    if [ "$scope" = root ]; then
        just sync > "$fixture/output" 2>&1
        git switch -q topic/workspace
        [ "$(git rev-parse --abbrev-ref '@{upstream}')" = origin/topic/workspace ]
        git switch -q main
    else
        just utils sync > "$fixture/output" 2>&1
    fi
    [ "$(git -C 'utils/member with spaces' branch --show-current)" = main ]
    [ "$(git -C 'utils/member with spaces' rev-parse HEAD)" = "$before" ]
    git -C 'utils/member with spaces' switch -q topic/origin
    [ "$(git -C 'utils/member with spaces' rev-parse --abbrev-ref '@{upstream}')" = origin/topic/origin ]
    git -C 'utils/member with spaces' switch -q topic/secondary
    [ "$(git -C 'utils/member with spaces' rev-parse --abbrev-ref '@{upstream}')" = secondary/topic/secondary ]
    git -C 'utils/member with spaces' switch -q main
    if git -C 'utils/member with spaces' show-ref --verify --quiet refs/remotes/origin/deleted; then
        printf 'Deleted remote branch was not pruned\n' >&2
        exit 1
    fi

    # A later sync discovers branches created after the initial expansion.
    git -C "$fixture/origin" branch "later/$scope"
    if [ "$scope" = root ]; then
        just sync > "$fixture/output" 2>&1
    else
        just utils sync > "$fixture/output" 2>&1
    fi
    git -C 'utils/member with spaces' switch -q "later/$scope"
    [ "$(git -C 'utils/member with spaces' rev-parse --abbrev-ref '@{upstream}')" = "origin/later/$scope" ]
    printf 'PASS %s sync fetches all remote branches for checkout and prunes stale branches\n' "$scope"

    # A failed remote must not prevent fetching the other remotes or move HEAD.
    git -C 'utils/member with spaces' remote set-url origin "$fixture/missing"
    git -C "$fixture/secondary" branch "after-failure/$scope"
    if [ "$scope" = root ]; then
        if just sync > "$fixture/output" 2>&1; then
            printf 'Sync hid a remote fetch failure\n' >&2
            exit 1
        fi
    else
        if just utils sync > "$fixture/output" 2>&1; then
            printf 'Bucket sync hid a remote fetch failure\n' >&2
            exit 1
        fi
    fi
    [ "$(git -C 'utils/member with spaces' branch --show-current)" = "later/$scope" ]
    git -C 'utils/member with spaces' show-ref --verify --quiet "refs/remotes/secondary/after-failure/$scope"
    printf 'PASS %s sync finishes healthy remote fetches after a failure and preserves HEAD\n' "$scope"
done
