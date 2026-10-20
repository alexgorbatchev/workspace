#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.tmp"
fixture="$(mktemp -d "$root/.tmp/catalog-test.XXXXXX")"
trap 'result=$?; if [ "$result" -ne 0 ] && [ -f "$fixture/output" ]; then cat "$fixture/output"; fi; rm -rf "$fixture"; exit "$result"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_ALLOW_PROTOCOL=file JOBS=2
mkdir -p "$fixture/workspace" "$fixture/org"
cp "$root/justfile" "$fixture/workspace/justfile"
if [ -d "$root/scripts" ]; then
    cp -R "$root/scripts" "$fixture/workspace/scripts"
fi
cd "$fixture/workspace"
git init -q -b main
for name in alpha beta; do
    git init -q -b main "$fixture/org/$name"
    git -C "$fixture/org/$name" commit -q --allow-empty -m initial
    git submodule add -q -b main "$fixture/org/$name" "members/$name"
done
git commit -qm catalog
git init -q --bare -b main "$fixture/org/workspace.git"
git remote add origin "$fixture/org/workspace.git"
git push -qu origin main

assert_output() {
    if ! rg -F -- "$1" "$fixture/output" >/dev/null; then
        cat "$fixture/output"
        printf 'Missing output: %s\n' "$1" >&2
        exit 1
    fi
}

just git status --short --branch > "$fixture/output" 2>&1
assert_output '[org/alpha] ## main'
assert_output '[org/beta] ## main'
printf 'PASS prefixes\n'

# Each real Git alias waits for the other repository to start. A sequential
# runner cannot pass this barrier, regardless of machine speed.
export CATALOG_BARRIER="$fixture/barrier"
mkdir "$CATALOG_BARRIER"
for name in alpha beta; do
    git -C "members/$name" config alias.barrier '!touch "$CATALOG_BARRIER/$(basename "$PWD")"; i=0; while [ ! -f "$CATALOG_BARRIER/alpha" ] || [ ! -f "$CATALOG_BARRIER/beta" ]; do i=$((i+1)); [ "$i" -lt 100 ] || exit 1; sleep 0.05; done; echo overlapped'
done
just git barrier > "$fixture/output" 2>&1
assert_output '[org/alpha] overlapped'
assert_output '[org/beta] overlapped'
printf 'PASS concurrent execution\n'

value='spaces "quotes" $(touch injected) ; *'
just git config test.literal "$value" > "$fixture/output" 2>&1
for name in alpha beta; do
    [ "$(git -C "members/$name" config test.literal)" = "$value" ]
done
[ ! -e injected ]
printf 'PASS literal arguments\n'

git -C members/alpha config alias.result '!echo failed >&2; exit 7'
git -C members/beta config alias.result '!sleep 0.1; printf finished'
if just git result > "$fixture/output" 2>&1; then
    printf 'Expected failure status\n' >&2
    exit 1
fi
assert_output '[org/alpha] failed'
assert_output '[org/beta] finished'
printf 'PASS stderr, partial lines, and failure propagation\n'

for operation in fetch update sync; do
    for name in alpha beta; do
        git -C "$fixture/org/$name" commit -q --allow-empty -m "$operation"
    done
    just "$operation" > "$fixture/output" 2>&1
    assert_output '[org/alpha]'
    assert_output '[org/beta]'
    for name in alpha beta; do
        expected="$(git -C "$fixture/org/$name" rev-parse HEAD)"
        [ "$(git -C "members/$name" rev-parse origin/main)" = "$expected" ]
        if [ "$operation" != fetch ]; then
            [ "$(git -C "members/$name" rev-parse HEAD)" = "$expected" ]
        fi
    done
    printf 'PASS %s\n' "$operation"
done

for name in alpha beta; do
    git -C "$fixture/org/$name" config receive.denyCurrentBranch updateInstead
    git -C "members/$name" commit -q --allow-empty -m push
done
just git push > "$fixture/output" 2>&1
for name in alpha beta; do
    [ "$(git -C "members/$name" rev-parse HEAD)" = "$(git -C "$fixture/org/$name" rev-parse HEAD)" ]
done
printf 'PASS local pushes\n'

printf 'original\n' > unrelated.txt
git add unrelated.txt
git commit -qm 'test fixture file'
printf 'edited\n' > unrelated.txt
before="$(git rev-parse HEAD)"
touch members/alpha/unfinished
if just save > "$fixture/output" 2>&1; then
    printf 'Expected dirty member rejection\n' >&2
    exit 1
fi
[ "$(git rev-parse HEAD)" = "$before" ]
rm members/alpha/unfinished
git add unrelated.txt
staged="$(git diff --cached)"
if just save > "$fixture/output" 2>&1; then
    printf 'Expected staged changes rejection\n' >&2
    exit 1
fi
[ "$(git diff --cached)" = "$staged" ]
git restore --staged unrelated.txt
for name in alpha beta; do
    git -C "members/$name" commit -q --allow-empty -m 'publish through save'
done
just save > "$fixture/output" 2>&1
[ "$(git log -1 --format=%s)" = 'chore: update submodule pointers' ]
[ "$(git diff-tree --no-commit-id --name-only -r HEAD)" = "$(printf 'members/alpha\nmembers/beta')" ]
for name in alpha beta; do
    [ "$(git rev-parse "HEAD:members/$name")" = "$(git -C "members/$name" rev-parse HEAD)" ]
    [ "$(git -C "$fixture/org/$name" rev-parse HEAD)" = "$(git -C "members/$name" rev-parse HEAD)" ]
done
[ "$(git -C "$fixture/org/workspace.git" rev-parse main)" = "$(git rev-parse HEAD)" ]
[ "$(git show HEAD:unrelated.txt)" = original ]
[ "$(cat unrelated.txt)" = edited ]
before="$(git rev-parse HEAD)"
just save > "$fixture/output" 2>&1
[ "$(git rev-parse HEAD)" = "$before" ]
printf 'PASS save pointers, fixed message, unrelated changes, dirty/staged rejection, and no-op\n'

git commit -q --allow-empty -m 'retry publication'
before="$(git rev-parse HEAD)"
git remote set-url --push origin "$fixture/missing"
if just save > "$fixture/output" 2>&1; then
    printf 'Expected save push failure\n' >&2
    exit 1
fi
[ "$(git rev-parse HEAD)" = "$before" ]
git remote set-url --push origin "$fixture/org/workspace.git"
just save > "$fixture/output" 2>&1
[ "$(git -C "$fixture/org/workspace.git" rev-parse main)" = "$before" ]
[ "$(git rev-parse HEAD)" = "$before" ]
printf 'PASS save publishes members and root, reports push failures, and retries without another commit\n'

git -C members/alpha remote set-url origin "$fixture/missing"
if just fetch > "$fixture/output" 2>&1; then
    printf 'Expected fetch failure\n' >&2
    exit 1
fi
assert_output '[org/beta]'
printf 'PASS fetch failure propagation\n'

for operation in update sync; do
    if just "$operation" > "$fixture/output" 2>&1; then
        printf 'Expected %s failure\n' "$operation" >&2
        exit 1
    fi
    assert_output '[org/beta] done'
    printf 'PASS %s failure propagation\n' "$operation"
done

for url in https://example.com/org/alpha.git git@example.com:org/alpha.git ssh://git@example.com:2222/org/alpha.git; do
    git -C members/alpha remote set-url origin "$url"
    just git status --short --branch > "$fixture/output" 2>&1
    assert_output '[org/alpha] ## main'
done
printf 'PASS HTTPS and SSH labels\n'

git mv members/beta 'members/beta space'
just git status --short --branch > "$fixture/output" 2>&1
assert_output '[org/beta] ## main'
printf 'PASS repository paths with spaces\n'

if JOBS=0 just git config test.should-not-run yes > "$fixture/output" 2>&1; then
    printf 'Expected invalid concurrency failure\n' >&2
    exit 1
fi
if git -C members/alpha config test.should-not-run; then
    printf 'Invalid concurrency executed a command\n' >&2
    exit 1
fi
printf 'PASS invalid concurrency\n'

mkdir "$fixture/empty"
cp justfile "$fixture/empty/justfile"
cp -R scripts "$fixture/empty/scripts"
cd "$fixture/empty"
git init -q -b main
touch .gitmodules
just git config test.should-not-run yes > "$fixture/output" 2>&1
if git config test.should-not-run; then
    printf 'Empty catalog executed a command in the root\n' >&2
    exit 1
fi
printf 'PASS empty catalog\n'
