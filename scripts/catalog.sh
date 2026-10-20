#!/usr/bin/env bash
# Shared by the root recipes; xargs owns the bounded pool and waits for workers.

catalog_label() {
    local repo="$1" url parent owner result
    if [ ! -e "$repo/.git" ]; then
        printf '%s\n' "${repo#./}"
        return
    fi
    if url="$(git -C "$repo" config --get remote.origin.url)"; then
        :
    else
        result=$?
        [ "$result" -eq 1 ] || return "$result"
        printf '%s\n' "${repo#./}"
        return
    fi
    url="${url%/}"
    url="${url%.git}"
    parent="${url%/*}"
    owner="${parent##*/}"
    owner="${owner##*:}"
    printf '%s/%s\n' "$owner" "${url##*/}"
}

catalog_command() (
    set -o pipefail
    label="$1"
    shift
    "$@" 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
        printf '[%s] %s\n' "$label" "$line"
    done
)

catalog_branch() {
    local repo="$1" entry key branch
    while IFS= read -r -d '' entry; do
        [ "${entry#*$'\n'}" = "$repo" ] || continue
        key="${entry%%$'\n'*}"
        if branch="$(git config --file .gitmodules --get "${key%.path}.branch")"; then
            if [ "$branch" = . ]; then
                git symbolic-ref --short HEAD
            else
                printf '%s\n' "$branch"
            fi
        else
            [ "$?" -eq 1 ] || return 1
            branch="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD)" || return
            printf '%s\n' "${branch#origin/}"
        fi
        return
    done < <(git config --file .gitmodules --null --get-regexp '^submodule\..*\.path$')
    printf 'No catalog branch found for %s\n' "$repo" >&2
    return 1
}

catalog_fetch_all_branches() {
    local repo="$1" remotes remote result=0
    remotes="$(git -C "$repo" remote)" || return
    while IFS= read -r remote; do
        [ -n "$remote" ] || continue
        if git -C "$repo" remote set-branches "$remote" '*' &&
            git -C "$repo" fetch --prune -- "$remote"; then
            :
        else
            result=1
        fi
    done <<< "$remotes"
    return "$result"
}

catalog_operation() {
    local repo="$1" operation="$2" branch
    shift 2
    case "$operation" in
        git) git -C "$repo" "$@" ;;
        fetch) git -C "$repo" fetch --all --prune ;;
        update)
            catalog_operation "$repo" align "" &&
                git -C "$repo" fetch --all --prune &&
                git submodule update --remote --merge -- "$repo"
            ;;
        sync)
            catalog_fetch_all_branches "$repo" &&
                catalog_operation "$repo" align "" &&
                git submodule update --remote --no-fetch --merge -- "$repo"
            ;;
        align)
            branch="$1"
            if [ -z "$branch" ]; then
                branch="$(catalog_branch "$repo")" || return
            fi
            git -C "$repo" switch -- "$branch"
            ;;
        bucket-sync)
            catalog_fetch_all_branches "$repo" &&
                catalog_operation "$repo" align "" &&
                git -C "$repo" merge --ff-only '@{upstream}'
            ;;
        status) catalog_status "$repo" ;;
        check|test|clean) catalog_task "$repo" "$operation" ;;
        *) printf 'Unknown catalog operation: %s\n' "$operation" >&2; return 1 ;;
    esac
}

catalog_worker() {
    # xargs appends exactly one repository after the unchanged Git arguments.
    local repo="${!#}" label operation="$1" result
    set -- "${@:1:$#-1}"
    shift
    if [ "$operation" = status ]; then
        if catalog_status "$repo"; then
            return 0
        else
            result=$?
            printf '[%s] status failed (exit %s)\n' "$repo" "$result" >&2
            return 1
        fi
    fi
    label="$(catalog_label "$repo")" || return
    printf '[%s] starting %s\n' "$label" "$operation"
    if catalog_command "$label" catalog_operation "$repo" "$operation" "$@"; then
        printf '[%s] done\n' "$label"
    else
        result=$?
        printf '[%s] failed (exit %s)\n' "$label" "$result" >&2
        # xargs treats 255 as an instruction to stop scheduling other jobs.
        return 1
    fi
}

catalog_paths() (
    set -o pipefail
    local entry repo
    if [ ! -f .gitmodules ]; then
        printf 'Missing catalog: .gitmodules\n' >&2
        return 1
    fi
    # Git's NUL format separates each key and value with a newline.
    { git config --file .gitmodules --null --get-regexp '^submodule\..*\.path$' ||
        [ "$?" -eq 1 ]; } |
        while IFS= read -r -d '' entry; do
            repo="${entry#*$'\n'}"
            if [ -n "${CATALOG_BUCKET:-}" ] && [[ "$repo" != "$CATALOG_BUCKET/"* ]]; then
                continue
            fi
            if [ "${1:-}" = all ] || [ -f "$repo/.git" ] || [ -d "$repo/.git" ]; then
                printf '%s\0' "$repo"
            fi
        done
)

catalog_run() (
    set -o pipefail
    jobs="${JOBS:-8}"
    if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
        printf 'JOBS must be a positive integer\n' >&2
        exit 1
    fi
    paths_mode=initialized
    case "$1" in status|check|test|clean) paths_mode=all ;; esac
    export -f catalog_label catalog_command catalog_branch catalog_fetch_all_branches catalog_operation catalog_worker catalog_status catalog_task
    if [ "$1" = status ]; then
        {
            printf 'SUBMODULE\tBRANCH\tSTATUS\tUPSTREAM\n'
            catalog_paths "$paths_mode" | xargs -0 -r -n 1 -P "$jobs" bash -c 'catalog_worker "$@"' _ "$@"
        } | column -t -s $'\t'
    else
        catalog_paths "$paths_mode" | xargs -0 -r -n 1 -P "$jobs" bash -c 'catalog_worker "$@"' _ "$@"
    fi
)

catalog_status() {
    local repo="$1" branch state upstream counts ahead behind remote_info
    if [ ! -e "$repo/.git" ]; then
        printf '%s\t%s\t%s\t%s\n' "$repo" - missing -
        return
    fi
    branch="$(git -C "$repo" branch --show-current)" || return
    state="$(git -C "$repo" status --porcelain)" || return
    upstream=""
    if [ -n "$branch" ]; then
        upstream="$(git -C "$repo" for-each-ref --format='%(upstream:short)' "refs/heads/$branch")" || return
    fi
    remote_info=no-upstream
    if [ -n "$upstream" ]; then
        counts="$(git -C "$repo" rev-list --left-right --count "HEAD...$upstream")" || return
        read -r ahead behind <<< "$counts"
        remote_info="+$ahead/-$behind"
    fi
    if [ -n "$state" ]; then state=dirty; else state=clean; fi
    printf '%s\t%s\t%s\t%s\n' "$repo" "${branch:-detached}" "$state" "$remote_info"
}

catalog_task() {
    local repo="$1" operation="$2" jf summary task
    jf="$repo/justfile"
    [ -f "$jf" ] || jf="$repo/Justfile"
    [ -f "$jf" ] || return 0
    summary="$(just -f "$jf" --summary)" || return
    case "$operation" in
        check)
            for task in check lint vet; do
                if [[ " $summary " =~ [[:space:]]$task[[:space:]] ]]; then
                    just -f "$jf" "$task"
                    return
                fi
            done
            ;;
        clean)
            if [[ " $summary " =~ [[:space:]]clean[[:space:]] ]]; then
                just -f "$jf" clean
                return
            fi
            ;;
        test) just -f "$jf" test; return ;;
    esac
    return 0
}

catalog_remove() {
    local repo="$1"
    # Validate the exact gitlink before passing a path to destructive commands.
    if ! git --literal-pathspecs ls-files --stage -z -- "$repo" |
        (IFS= read -r -d '' entry &&
            [ "${entry%% *}" = 160000 ] && [ "${entry#*$'\t'}" = "$repo" ]); then
        printf 'Not a catalog submodule: %s\n' "$repo" >&2
        return 1
    fi
    if [ -e "$repo/.git" ]; then
        git -C "$repo" rev-parse --git-dir >/dev/null || return
    fi
    git --literal-pathspecs submodule deinit -f -- "$repo" || return
    git --literal-pathspecs rm -f -- "$repo"
}

catalog_commit_preflight() (
    local repo="$1" message="$2" index remote url snapshot urls result
    shift 2
    git -C "$repo" diff --cached --quiet || {
        printf '[%s] already has staged changes; finish that commit first.\n' "$repo" >&2
        return 1
    }
    index="$(git -C "$repo" rev-parse --path-format=absolute --git-path index)" || return
    if [ -e "$index.lock" ]; then
        printf '[%s] index is locked; leave the owning Git operation to finish.\n' "$repo" >&2
        return 1
    fi
    # Build the prospective index separately. Preflight never stages real files.
    snapshot="$(mktemp "$PWD/.tmp/commit-index.XXXXXX")" || return
    rm "$snapshot" || return
    trap 'rm -f "$snapshot" "$snapshot.lock" "$snapshot.diff" "$snapshot.scan"' EXIT
    export GIT_INDEX_FILE="$snapshot"
    git -C "$repo" read-tree HEAD || return
    if [ "$#" -eq 0 ]; then
        git -C "$repo" add --all || return
    else
        git --literal-pathspecs -C "$repo" add -- "$@" || return
    fi
    printf '%s\n' "$message" > "$snapshot.scan" || return
    git -C "$repo" diff --cached --text --no-ext-diff --no-textconv --unified=0 HEAD -- > "$snapshot.diff" || return
    sed -n '/^+++ /d; /^+/p' "$snapshot.diff" >> "$snapshot.scan" || return
    remote="$(git -C "$repo" remote)" || return
    while IFS= read -r remote; do
        [ -n "$remote" ] || continue
        urls="$(git -C "$repo" remote get-url --all "$remote")" || return
        urls+=$'\n'"$(git -C "$repo" remote get-url --push --all "$remote")" || return
        while IFS= read -r url; do
        case "$url" in
            git@github.com:*|ssh://git@github.com/*|https://github.com/*|http://github.com/*)
                if LC_ALL=C grep -Ei '(^|[^[:alnum:]_-])([[:alnum:]_-]+\.)+(cvb|zxc)\.lol([^[:alnum:]_-]|$)' "$snapshot.scan" >/dev/null; then
                    printf '[%s] prospective GitHub commit contains a private internal domain.\n' "$repo" >&2
                    return 1
                else
                    result=$?
                    [ "$result" -eq 1 ] || return "$result"
                fi
                ;;
        esac
        done <<< "$urls"
    done <<< "$remote"
)

catalog_commit() (
    set -euo pipefail
    local message="$1" entry repo metadata recorded current state snapshot
    local paths=() dirty=()
    if [[ ! "$message" =~ [^[:space:]] ]]; then
        printf 'Commit message must not be empty.\n' >&2
        return 1
    fi
    if ! git diff --cached --quiet; then
        printf 'Root already has staged changes; finish that commit first.\n' >&2
        return 1
    fi
    mkdir -p .tmp
    snapshot="$(mktemp .tmp/commit-members.XXXXXX)"
    trap 'rm -f "$snapshot"' EXIT
    git ls-files --stage -z > "$snapshot"
    # Validate every affected member before committing any of them.
    while IFS= read -r -d '' entry; do
        [ "${entry%% *}" = 160000 ] || continue
        repo="${entry#*$'\t'}"
        [ -e "$repo/.git" ] || continue
        metadata="${entry%%$'\t'*}"
        recorded="${metadata#* }"
        recorded="${recorded%% *}"
        current="$(git -C "$repo" rev-parse HEAD)"
        state="$(git -C "$repo" status --porcelain --untracked-files=normal)"
        if [ "$current" = "$recorded" ] && [ -z "$state" ]; then
            continue
        fi
        if ! git -C "$repo" symbolic-ref -q HEAD >/dev/null ||
            ! git -C "$repo" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
            printf '[%s] must be on a tracking branch before bulk commit.\n' "$repo" >&2
            return 1
        fi
        catalog_commit_preflight "$repo" "$message"
        paths+=("$repo")
        [ -z "$state" ] || dirty+=("$repo")
    done < "$snapshot"
    if [ "${#paths[@]}" -eq 0 ]; then
        printf 'No member changes or pointers to commit.\n'
        return
    fi
    catalog_commit_preflight . "$message" "${paths[@]}"
    for repo in "${dirty[@]}"; do
        catalog_command "$(catalog_label "$repo")" git -C "$repo" add --all
        catalog_command "$(catalog_label "$repo")" git -C "$repo" commit -m "$message"
        if [ -n "$(git -C "$repo" status --porcelain)" ]; then
            printf '[%s] still has changes after committing; root pointers were not committed.\n' "$repo" >&2
            return 1
        fi
    done
    # Root source edits remain untouched; this commit records only member gitlinks.
    git --literal-pathspecs commit --only -m "$message" -- "${paths[@]}"
)

catalog_save() (
    local entry repo metadata recorded current state snapshot result label
    local paths=()
    if git diff --cached --quiet; then
        :
    else
        result=$?
        [ "$result" -eq 1 ] || return "$result"
        printf 'Already staged changes; finish that commit before running just save.\n' >&2
        return 1
    fi
    mkdir -p .tmp || return
    snapshot="$(mktemp .tmp/catalog-index.XXXXXX)" || return
    trap 'rm -f "$snapshot"' EXIT
    git ls-files --stage -z > "$snapshot" || return
    while IFS= read -r -d '' entry; do
        [ "${entry%% *}" = 160000 ] || continue
        repo="${entry#*$'\t'}"
        [ -e "$repo/.git" ] || continue
        metadata="${entry%%$'\t'*}"
        recorded="${metadata#* }"
        recorded="${recorded%% *}"
        current="$(git -C "$repo" rev-parse HEAD)" || return
        [ "$current" != "$recorded" ] || continue
        state="$(git -C "$repo" status --porcelain)" || return
        if [ -n "$state" ]; then
            printf '[%s] has uncommitted changes; finish them before saving pointers.\n' "$repo" >&2
            return 1
        fi
        if ! git -C "$repo" symbolic-ref -q HEAD >/dev/null ||
            ! git -C "$repo" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
            printf '[%s] must be on a tracking branch before saving its pointer.\n' "$repo" >&2
            return 1
        fi
        paths+=("$repo")
    done < "$snapshot"
    if [ "${#paths[@]}" -eq 0 ]; then
        printf 'Submodule pointers are already saved.\n'
    else
        # Commit only gitlinks; root file edits and untracked files stay untouched.
        git --literal-pathspecs commit --only -m 'chore: update submodule pointers' -- "${paths[@]}" || return
    fi
    label="$(catalog_label .)" || return
    catalog_command "$label" git push --recurse-submodules=on-demand
)
