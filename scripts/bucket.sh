#!/usr/bin/env bash
set -euo pipefail

CATALOG_BUCKET="${PWD##*/}"
export CATALOG_BUCKET
cd ..
source scripts/catalog.sh

operation="$1"
shift
case "$operation" in
    sync)
        catalog_run bucket-sync
        catalog_run status
        ;;
    align)
        catalog_run align "$1"
        printf 'Submodules in %s aligned.\n' "$CATALOG_BUCKET"
        ;;
    status|check|test|clean) catalog_run "$operation" ;;
    *) printf 'Unknown bucket operation: %s\n' "$operation" >&2; exit 1 ;;
esac
