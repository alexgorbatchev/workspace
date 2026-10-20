#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.tmp"
fixture="$(mktemp -d "$root/.tmp/commit-test.XXXXXX")"
trap 'result=$?; if [ "$result" -ne 0 ] && [ -f "$fixture/output" ]; then cat "$fixture/output"; fi; rm -rf "$fixture"; exit "$result"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_ALLOW_PROTOCOL=file

git init -q -b main "$fixture/origin"
printf 'initial\n' > "$fixture/origin/file"
git -C "$fixture/origin" add file
git -C "$fixture/origin" commit -qm initial
mkdir -p "$fixture/workspace/scripts"
cp "$root/justfile" "$fixture/workspace/justfile"
cp "$root/scripts/catalog.sh" "$fixture/workspace/scripts/catalog.sh"
cd "$fixture/workspace"
git init -q -b main
git submodule add -q -b main "$fixture/origin" 'first member'
git submodule add -q -b main "$fixture/origin" second
printf '.tmp/\n' > .gitignore
printf 'root original\n' > root-file
git add .
git commit -qm catalog
before="$(git rev-parse HEAD)"
member_before="$(git -C 'first member' rev-parse HEAD)"
printf 'changed\n' >> 'first member/file'
printf 'new\n' > 'first member/new file'
printf 'second\n' >> second/file
printf 'root edit stays local\n' >> root-file
git -C second switch -q --detach
if just --justfile ./justfile commit 'chore: bulk change' > "$fixture/output" 2>&1; then
    echo 'Detached member should fail preflight' >&2; exit 1
fi
[ "$(git rev-parse HEAD)" = "$before" ]
[ "$(git -C 'first member' rev-parse HEAD)" = "$member_before" ]
git -C second switch -q main
git -C second add file
if just --justfile ./justfile commit 'chore: bulk change' > "$fixture/output" 2>&1; then
    echo 'Existing staged work should fail preflight' >&2; exit 1
fi
[ "$(git -C 'first member' rev-parse HEAD)" = "$member_before" ]
git -C second restore --staged file
git add root-file
if just --justfile ./justfile commit 'chore: bulk change' > "$fixture/output" 2>&1; then
    echo 'Root staged work should fail preflight' >&2; exit 1
fi
[ "$(git -C 'first member' rev-parse HEAD)" = "$member_before" ]
git restore --staged root-file
message='chore: literal $(touch should-not-exist) `touch also-not`'
just --justfile ./justfile commit "$message" > "$fixture/output" 2>&1
[ ! -e should-not-exist ] && [ ! -e also-not ]
for member in 'first member' second; do
    [ -z "$(git -C "$member" status --porcelain)" ]
    [ "$(git -C "$member" log -1 --format=%B)" = "$message" ]
    [ "$(git rev-parse "HEAD:$member")" = "$(git -C "$member" rev-parse HEAD)" ]
    [ "$(git -C "$member" rev-parse origin/main)" = "$member_before" ]
done
[ "$(git show HEAD:root-file)" = 'root original' ]
[ "$(git status --porcelain -- root-file)" = ' M root-file' ]
git -C 'first member' cat-file -e 'HEAD:new file'
after="$(git rev-parse HEAD)"
just --justfile ./justfile commit "$message" > "$fixture/output" 2>&1
[ "$(git rev-parse HEAD)" = "$after" ]
printf 'PASS bulk commit records member changes and root pointers locally, preserves root edits, and is idempotent\n'

# A later commit failure preserves successful commits and withholds the root pointer commit.
printf 'next\n' >> 'first member/file'
printf 'next\n' >> second/file
hook="$(git -C second rev-parse --path-format=absolute --git-path hooks/pre-commit)"
printf '#!/bin/sh\nexit 1\n' > "$hook"
chmod +x "$hook"
if just --justfile ./justfile commit 'chore: retryable' > "$fixture/output" 2>&1; then
    echo 'Member hook failure was hidden' >&2; exit 1
fi
[ "$(git rev-parse HEAD)" = "$after" ]
[ "$(git -C 'first member' log -1 --format=%s)" = 'chore: retryable' ]
rm "$hook"
# The failed commit leaves its staged changes intact for the user to finish.
git -C second commit -qm 'chore: retryable'
just --justfile ./justfile commit 'chore: retryable' > "$fixture/output" 2>&1
[ "$(git rev-parse HEAD:second)" = "$(git -C second rev-parse HEAD)" ]
printf 'PASS failed commits preserve completed member work and withhold root pointers until retry\n'

# Prospective GitHub commits must be checked before any member is committed.
before="$(git -C 'first member' rev-parse HEAD)"
printf 'safe\n' >> 'first member/file'
git -C second remote set-url origin git@github.com:example/member.git
printf 'private host: service.%s.%s\n' cvb lol > second/private-file
if just --justfile ./justfile commit 'chore: private check' > "$fixture/output" 2>&1; then
    echo 'Private domain was accepted for GitHub' >&2; exit 1
fi
[ "$(git -C 'first member' rev-parse HEAD)" = "$before" ]
[ -z "$(git -C second diff --cached --name-only)" ]
printf 'PASS private-domain preflight protects GitHub commits without changing member indexes\n'

rm second/private-file
git -C second remote set-url origin "$fixture/origin"
git -C second remote set-url --push origin git@github.com:example/member.git
printf 'private host: service.%s.%s\n' cvb lol > second/private-file
if just --justfile ./justfile commit 'chore: push destination check' > "$fixture/output" 2>&1; then
    echo 'Private domain was accepted for a GitHub push destination' >&2; exit 1
fi
[ "$(git -C 'first member' rev-parse HEAD)" = "$before" ]
rm second/private-file
git -C second config --unset-all remote.origin.pushurl
git remote add origin git@github.com:example/workspace.git
private_message="$(printf 'chore: service.%s.%s' zxc lol)"
if just --justfile ./justfile commit "$private_message" > "$fixture/output" 2>&1; then
    echo 'Root private commit message was accepted for GitHub' >&2; exit 1
fi
[ "$(git -C 'first member' rev-parse HEAD)" = "$before" ]
if just --justfile ./justfile commit '   ' > "$fixture/output" 2>&1; then
    echo 'Empty commit message was accepted' >&2; exit 1
fi
printf 'PASS root preflight protects private commit messages and rejects blank messages\n'
