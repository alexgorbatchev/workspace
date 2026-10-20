#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.tmp"
fixture="$(mktemp -d "$root/.tmp/failure-test.XXXXXX")"
trap 'result=$?; if [ "$result" -ne 0 ] && [ -f "$fixture/output" ]; then cat "$fixture/output"; fi; rm -rf "$fixture"; exit "$result"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_ALLOW_PROTOCOL=file JOBS=2
failures=0
checks=0

expect_failure() {
    checks=$((checks + 1))
    if "$@" > "$fixture/output" 2>&1; then
        printf 'FAIL expected nonzero: %s\n' "$*" >&2
        failures=$((failures + 1))
    fi
}

git init -q -b main "$fixture/origin"
printf 'base\n' > "$fixture/origin/state"
git -C "$fixture/origin" add state
git -C "$fixture/origin" commit -qm initial

for bucket in ai apps audio-voice dev-tooling dj go-libs hardware-firmware remarkable tui ui-design utils; do
    workspace="$fixture/$bucket"
    mkdir -p "$workspace/$bucket"
    cp "$root/justfile" "$workspace/justfile"
    cp -R "$root/scripts" "$workspace/scripts"
    cp "$root/$bucket/justfile" "$workspace/$bucket/justfile"
    cd "$workspace"
    git init -q -b main
    git submodule add -q -b main "$fixture/origin" "$bucket/alpha"
    git submodule add -q -b main "$fixture/origin" "$bucket/beta"
    git commit -qm catalog
    module="${bucket//-/_}"
    just "$module" sync > "$fixture/output" 2>&1
    just "$module" status > "$fixture/output" 2>&1

    expect_failure just "$module" align nonexistent
    git -C "$bucket/alpha" remote set-url origin "$fixture/missing"
    expect_failure just "$module" sync
    git -C "$bucket/alpha" remote set-url origin "$fixture/origin"

    # A remote update conflicts with an uncommitted local edit.
    printf 'dirty\n' > "$bucket/alpha/state"
    printf '%s\n' "$bucket" > "$fixture/origin/state"
    git -C "$fixture/origin" commit -qam "$bucket update"
    expect_failure just "$module" sync
    [ "$(cat "$bucket/alpha/state")" = dirty ]
    # Restore the exact base version for this disposable member.
    git -C "$bucket/alpha" show HEAD:state > "$bucket/alpha/state"

    printf 'not a valid justfile !!!\n' > "$bucket/alpha/justfile"
    for operation in check clean; do
        expect_failure just "$module" "$operation"
        expect_failure just "$operation"
    done
    expect_failure just --no-deps test
    rm "$bucket/alpha/justfile"

    # A real failing recipe must not prevent healthy members from finishing.
    for operation in check test clean; do
        printf '%s:\n    exit 7\n' "$operation" > "$bucket/alpha/justfile"
        printf '%s:\n    @echo healthy-member-finished\n' "$operation" > "$bucket/beta/justfile"
        expect_failure just "$module" "$operation"
        rg -F healthy-member-finished "$fixture/output" >/dev/null
        expect_failure just --no-deps "$operation"
        rg -F healthy-member-finished "$fixture/output" >/dev/null
    done
    rm "$bucket/alpha/justfile" "$bucket/beta/justfile"

    # Corrupt Git metadata must never be presented as a clean member.
    printf 'broken gitfile\n' > "$bucket/alpha/.git"
    expect_failure just "$module" status
    expect_failure just status

    printf '[invalid\n' > .gitmodules
    for operation in status align sync check test clean; do
        expect_failure just "$module" "$operation"
    done
    for operation in status align fetch update check clean; do
        expect_failure just "$operation"
    done
    expect_failure just --no-deps test
    printf 'PASS %s bucket and root failure paths\n' "$bucket"
done

# Test catalog mutations with real local clones and Git hooks.
workspace="$fixture/mutations"
mkdir -p "$workspace" "$fixture/org" "$fixture/hooks"
cp "$root/justfile" "$workspace/justfile"
cp -R "$root/scripts" "$workspace/scripts"
git clone -q --bare "$fixture/origin" "$fixture/org/new.git"
cd "$workspace"
git init -q -b main
git config "url.$fixture/org/.insteadOf" https://github.com/alexgorbatchev/
git commit -q --allow-empty -m initial
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.$fixture/org/.insteadOf"
export GIT_CONFIG_VALUE_0=https://github.com/alexgorbatchev/
just add 'members with spaces/new' > "$fixture/output" 2>&1
[ "$(git -C 'members with spaces/new' symbolic-ref --short HEAD)" = main ]
just remove 'members with spaces/new' > "$fixture/output" 2>&1
[ ! -e 'members with spaces/new/.git' ]
[ -d '.git/modules/members with spaces/new' ]

# The second checkout fails: cloning and registration succeeded, but add must
# propagate its own branch-switch failure instead of printing a success status.
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'if [ -e "$CATALOG_ADD_CHECKOUT" ]; then echo checkout-denied >&2; exit 7; fi' \
    'touch "$CATALOG_ADD_CHECKOUT"' > "$fixture/hooks/post-checkout"
chmod +x "$fixture/hooks/post-checkout"
export CATALOG_ADD_CHECKOUT="$fixture/add-checkout"
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1="$fixture/hooks"
expect_failure just add members/new
rg -F checkout-denied "$fixture/output" >/dev/null
export GIT_CONFIG_COUNT=1

# Remove must refuse ordinary files and preserve retained module metadata.
printf 'preserve\n' > ordinary.txt
git add ordinary.txt
git commit -qm ordinary
expect_failure just remove ordinary.txt
[ "$(cat ordinary.txt)" = preserve ]
expect_failure just remove nonexistent
git config --file .gitmodules submodule.members/new.path members/new
printf 'broken gitfile\n' > members/new/.git
expect_failure just remove members/new
git ls-files --error-unmatch members/new >/dev/null
printf 'PASS add/remove errors, literal paths, and file preservation\n'

if [ "$failures" -ne 0 ]; then
    printf '%s failure paths incorrectly returned success\n' "$failures" >&2
    exit 1
fi
printf 'PASS %s expected failure checks\n' "$checks"
