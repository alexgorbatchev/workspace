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
git init -q -b main "$fixture/org/nested"
git -C "$fixture/org/nested" commit -q --allow-empty -m nested
for name in alpha beta; do
    git init -q -b main "$fixture/org/$name"
    git -C "$fixture/org/$name" commit -q --allow-empty -m initial
    if [ "$name" = alpha ]; then
        git -C "$fixture/org/$name" submodule add -q "$fixture/org/nested" nested
        git -C "$fixture/org/$name" commit -qm 'nested member'
    fi
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

git clone -q . "$fixture/sync-upstream"
git -C "$fixture/sync-upstream" commit -q --allow-empty -m 'remote root update'
for scenario in missing-upstream unreachable diverged fast-forward; do
    sync_workspace="$fixture/sync-$scenario"
    git clone -q --recurse-submodules . "$sync_workspace"
    cp "$root/justfile" "$sync_workspace/justfile"
    cp -R "$root/scripts" "$sync_workspace/scripts"
    git -C "$sync_workspace" remote set-url origin "$fixture/sync-upstream"
    case "$scenario" in
        missing-upstream) git -C "$sync_workspace" branch --unset-upstream ;;
        unreachable) git -C "$sync_workspace" remote set-url origin "$fixture/missing" ;;
        diverged) git -C "$sync_workspace" commit -q --allow-empty -m 'local root update' ;;
    esac
    before="$(git -C "$sync_workspace" rev-parse HEAD)"
    if (cd "$sync_workspace" && just sync) > "$fixture/output" 2>&1; then
        if [ "$scenario" != fast-forward ]; then
            printf 'Expected root pull failure: %s\n' "$scenario" >&2
            exit 1
        fi
        [ "$(git -C "$sync_workspace" rev-parse HEAD)" = "$(git -C "$fixture/sync-upstream" rev-parse HEAD)" ]
        assert_output '[org/alpha] starting sync'
        assert_output '[org/beta] done'
        assert_output 'Sync complete'
    else
        [ "$scenario" != fast-forward ]
        [ "$(git -C "$sync_workspace" rev-parse HEAD)" = "$before" ]
        if rg 'starting sync|Sync complete|Aligning branches' "$fixture/output"; then
            printf 'Sync continued after root pull failure: %s\n' "$scenario" >&2
            exit 1
        fi
    fi
    printf 'PASS sync root pull (%s)\n' "$scenario"
done

# Use real Git over a local SSH transport. Both upload-pack processes must
# start before either clone can finish, so serial setup fails deterministically.
mkdir "$fixture/bin"
export CATALOG_SETUP_BARRIER="$fixture/setup-barrier"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'command="${!#}"' \
    'case "$command" in' \
    '    *alpha*) name=alpha ;;' \
    '    *beta*) name=beta ;;' \
    '    *) exit 1 ;;' \
    'esac' \
    'touch "$CATALOG_SETUP_BARRIER/$name"' \
    'if [ "${CATALOG_SETUP_SERIAL:-0}" != 1 ]; then' \
    '    for ((i=0; i<100; i++)); do' \
    '        if [ -f "$CATALOG_SETUP_BARRIER/alpha" ] && [ -f "$CATALOG_SETUP_BARRIER/beta" ]; then break; fi' \
    '        sleep 0.05' \
    '    done' \
    '    if [ ! -f "$CATALOG_SETUP_BARRIER/alpha" ] || [ ! -f "$CATALOG_SETUP_BARRIER/beta" ]; then' \
    '        touch "$CATALOG_SETUP_BARRIER/serial-failure"; exit 1' \
    '    fi' \
    'fi' \
    'exec bash -c "$command"' > "$fixture/bin/setup-ssh"
chmod +x "$fixture/bin/setup-ssh"

for jobs in default 2 1; do
    setup_workspace="$fixture/setup-$jobs"
    git clone -q . "$setup_workspace"
    cp "$root/justfile" "$setup_workspace/justfile"
    cp -R "$root/scripts" "$setup_workspace/scripts"
    for name in alpha beta; do
        git -C "$setup_workspace" config "submodule.members/$name.url" "ssh://fixture$fixture/org/$name"
    done
    mkdir "$CATALOG_SETUP_BARRIER"
    (
        cd "$setup_workspace"
        export GIT_ALLOW_PROTOCOL=file:ssh GIT_SSH_COMMAND="$fixture/bin/setup-ssh" GIT_SSH_VARIANT=ssh
        if [ "$jobs" = default ]; then
            unset JOBS
        else
            export JOBS="$jobs"
        fi
        if [ "$jobs" = 1 ]; then export CATALOG_SETUP_SERIAL=1; fi
        just setup
    ) > "$fixture/output" 2>&1
    if [ -f "$CATALOG_SETUP_BARRIER/serial-failure" ]; then
        printf 'Setup clones did not overlap (JOBS=%s)\n' "$jobs" >&2
        exit 1
    fi
    for name in alpha beta; do
        [ -f "$CATALOG_SETUP_BARRIER/$name" ]
        [ "$(git -C "$setup_workspace/members/$name" rev-parse HEAD)" = "$(git rev-parse "HEAD:members/$name")" ]
        [ "$(git -C "$setup_workspace/members/$name" symbolic-ref --short HEAD)" = main ]
        [ "$(git -C "$setup_workspace/members/$name" rev-parse --abbrev-ref '@{upstream}')" = origin/main ]
    done
    [ "$(git -C "$setup_workspace/members/alpha/nested" rev-parse HEAD)" = "$(git -C "$fixture/org/nested" rev-parse HEAD)" ]
    rm -r "$CATALOG_SETUP_BARRIER"
    printf 'PASS setup cloning and tracking branches (JOBS=%s)\n' "$jobs"
done

for jobs in 0 -1 invalid; do
    if (cd "$fixture/setup-default" && JOBS="$jobs" just setup) > "$fixture/output" 2>&1; then
        printf 'Expected invalid setup concurrency failure: %s\n' "$jobs" >&2
        exit 1
    fi
    assert_output 'JOBS must be a positive integer'
done
printf 'PASS setup invalid concurrency\n'

git clone -q . "$fixture/setup-failure"
cp "$root/justfile" "$fixture/setup-failure/justfile"
git -C "$fixture/setup-failure" config submodule.members/alpha.url "$fixture/missing"
if (cd "$fixture/setup-failure" && just setup) > "$fixture/output" 2>&1; then
    printf 'Expected setup clone failure\n' >&2
    exit 1
fi
if rg -F 'Setup complete' "$fixture/output"; then
    printf 'Failed setup reported completion\n' >&2
    exit 1
fi
printf 'PASS setup clone failure propagation\n'

# Default alignment follows each catalog entry, including detached checkouts
# and entries whose configured name differs from their filesystem path.
(
git clone -q --recurse-submodules . "$fixture/align-workspace"
cp "$root/justfile" "$fixture/align-workspace/justfile"
cp -R "$root/scripts" "$fixture/align-workspace/scripts"
cd "$fixture/align-workspace"
git config --file .gitmodules --rename-section submodule.members/alpha submodule.custom-alpha
git config --file .gitmodules submodule.custom-alpha.branch release
git -C members/alpha branch release
for name in alpha beta; do
    git -C "members/$name" switch --detach -q
done
just align > "$fixture/output" 2>&1
[ "$(git -C members/alpha symbolic-ref --short HEAD)" = release ]
[ "$(git -C members/beta symbolic-ref --short HEAD)" = main ]
printf 'PASS align configured branches and detached checkouts\n'

just align main > "$fixture/output" 2>&1
for name in alpha beta; do
    [ "$(git -C "members/$name" symbolic-ref --short HEAD)" = main ]
done
printf 'PASS align explicit branch override\n'

export CATALOG_ALIGN_BARRIER="$fixture/align-barrier"
mkdir "$CATALOG_ALIGN_BARRIER" "$fixture/align-hooks"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'touch "$CATALOG_ALIGN_BARRIER/$(basename "$PWD")"' \
    'for ((i=0; i<100; i++)); do' \
    '    if [ -f "$CATALOG_ALIGN_BARRIER/alpha" ] && [ -f "$CATALOG_ALIGN_BARRIER/beta" ]; then exit 0; fi' \
    '    sleep 0.05' \
    'done' \
    'exit 1' > "$fixture/align-hooks/post-checkout"
chmod +x "$fixture/align-hooks/post-checkout"
for name in alpha beta; do
    git -C "members/$name" config core.hooksPath "$fixture/align-hooks"
done
just align main > "$fixture/output" 2>&1
for name in alpha beta; do
    [ -f "$CATALOG_ALIGN_BARRIER/$name" ]
    git -C "members/$name" config --unset core.hooksPath
done
printf 'PASS align operations overlap\n'

git config --file .gitmodules submodule.custom-alpha.branch .
just align > "$fixture/output" 2>&1
[ "$(git -C members/alpha symbolic-ref --short HEAD)" = main ]
git config --file .gitmodules --unset submodule.custom-alpha.branch
git -C members/alpha switch --detach -q
just align > "$fixture/output" 2>&1
[ "$(git -C members/alpha symbolic-ref --short HEAD)" = main ]
printf 'PASS align inherited branch and remote default\n'

# A missing branch must fail without restoring a same-named tracked file.
printf 'committed\n' > members/alpha/missing-branch
git -C members/alpha add missing-branch
git -C members/alpha commit -qm 'file sharing a branch argument'
printf 'keep this edit\n' > members/alpha/missing-branch
if just align missing-branch > "$fixture/output" 2>&1; then
    printf 'Expected missing alignment branch failure\n' >&2
    exit 1
fi
[ "$(cat members/alpha/missing-branch)" = 'keep this edit' ]
assert_output '[org/alpha] failed'
assert_output '[org/beta] failed'
if rg -F 'All active submodules aligned' "$fixture/output"; then
    printf 'Failed alignment reported success\n' >&2
    exit 1
fi
printf 'PASS align failure reporting and file preservation\n'

# Failure in one member must still allow another member to align.
git config --file .gitmodules submodule.custom-alpha.branch missing-branch
git -C members/beta switch --detach -q
if just align > "$fixture/output" 2>&1; then
    printf 'Expected partial alignment failure\n' >&2
    exit 1
fi
assert_output '[org/beta] done'
[ "$(git -C members/beta symbolic-ref --short HEAD)" = main ]

printf 'committed\n' > members/alpha/missing-branch
if just setup > "$fixture/output" 2>&1; then
    printf 'Expected setup alignment failure\n' >&2
    exit 1
fi
assert_output '[org/alpha] failed'
if rg -F 'Setup complete' "$fixture/output"; then
    printf 'Setup hid alignment failure\n' >&2
    exit 1
fi
printf 'PASS align continues other members and setup propagates failure\n'

git config --file .gitmodules --rename-section submodule.custom-alpha submodule.members/alpha
git config --file .gitmodules submodule.members/alpha.branch main
just align > "$fixture/output" 2>&1
)

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
    if [ "$operation" != fetch ]; then
        for name in alpha beta; do
            git -C "members/$name" switch -qc "work-$operation"
            git -C "members/$name" rev-parse HEAD > "$fixture/$operation-$name-head"
        done
    fi
    for name in alpha beta; do
        git -C "$fixture/org/$name" commit -q --allow-empty -m "$operation"
    done
    just "$operation" > "$fixture/output" 2>&1
    if [ "$operation" != fetch ]; then
        for name in alpha beta; do
            [ "$(git -C "members/$name" branch --show-current)" = main ]
            [ "$(git -C "members/$name" rev-parse "work-$operation")" = "$(cat "$fixture/$operation-$name-head")" ]
        done
    fi
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
just align > "$fixture/output" 2>&1
assert_output '[org/beta] done'
[ "$(git -C 'members/beta space' symbolic-ref --short HEAD)" = main ]
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
