#!/usr/bin/env bash
# Low-token bounded tail from worker output (default 25 lines).
# Usage: worker-read-brief.sh --dispatch DISPATCH_ID [--limit N]
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
DISPATCH=""
LIMIT=25

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dispatch|--id) DISPATCH="${2:?}"; shift 2 ;;
    --limit|-n) LIMIT="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --dispatch DISPATCH_ID [--limit 25]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$DISPATCH" ]] || { echo "--dispatch required" >&2; exit 2; }

# worker-read with limit and tail output to keep tokens minimal
"$ORCA_BIN" orchestration worker-read --dispatch "$DISPATCH" --limit "$LIMIT" 2>&1 | tail -n "$LIMIT"
