#!/usr/bin/env bash
# Shared by the root recipes; xargs owns the bounded pool and waits for workers.

catalog_label() {
    local repo="$1" url parent owner
    if ! url="$(git -C "$repo" remote get-url origin 2>/dev/null)"; then
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

catalog_operation() {
    local repo="$1" operation="$2"
    shift 2
    case "$operation" in
        git) git -C "$repo" "$@" ;;
        fetch) git -C "$repo" fetch --all --prune ;;
        update)
            git -C "$repo" fetch --all --prune &&
                git submodule update --remote --merge -- "$repo"
            ;;
        sync) git submodule update --remote --merge -- "$repo" ;;
        *) printf 'Unknown catalog operation: %s\n' "$operation" >&2; return 1 ;;
    esac
}

catalog_worker() {
    # xargs appends exactly one repository after the unchanged Git arguments.
    local repo="${!#}" label operation="$1" result
    set -- "${@:1:$#-1}"
    shift
    label="$(catalog_label "$repo")"
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

catalog_paths() {
    local entry repo
    # Git's NUL format separates each key and value with a newline.
    { git config --file .gitmodules --null --get-regexp '^submodule\..*\.path$' ||
        [ "$?" -eq 1 ]; } |
        while IFS= read -r -d '' entry; do
            repo="${entry#*$'\n'}"
            if [ -f "$repo/.git" ] || [ -d "$repo/.git" ]; then
                printf '%s\0' "$repo"
            fi
        done
}

catalog_run() (
    set -o pipefail
    jobs="${JOBS:-8}"
    if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
        printf 'JOBS must be a positive integer\n' >&2
        exit 1
    fi
    export -f catalog_label catalog_command catalog_operation catalog_worker
    catalog_paths | xargs -0 -r -n 1 -P "$jobs" bash -c 'catalog_worker "$@"' _ "$@"
)

catalog_save() {
    local entry repo metadata recorded current state
    local paths=()
    if ! git diff --cached --quiet; then
        printf 'Already staged changes; finish that commit before running just save.\n' >&2
        return 1
    fi
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
    done < <(git ls-files --stage -z)
    if [ "${#paths[@]}" -eq 0 ]; then
        printf 'Submodule pointers are already saved.\n'
    else
        # Commit only gitlinks; root file edits and untracked files stay untouched.
        git --literal-pathspecs commit --only -m 'chore: update submodule pointers' -- "${paths[@]}" || return
    fi
    catalog_command "$(catalog_label .)" git push --recurse-submodules=on-demand
}
