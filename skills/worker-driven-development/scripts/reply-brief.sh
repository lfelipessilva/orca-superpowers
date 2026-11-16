#!/usr/bin/env bash
# Low-token wrapper for orca orchestration reply.
# Usage: reply-brief.sh --id MSG_ID --body TEXT
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
MSG_ID="" BODY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) MSG_ID="${2:?}"; shift 2 ;;
    --body) BODY="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --id MSG_ID --body TEXT"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$MSG_ID" ]] || { echo "--id required" >&2; exit 2; }
[[ -n "$BODY" ]]   || { echo "--body required" >&2; exit 2; }

"$ORCA_BIN" orchestration reply --id "$MSG_ID" --body "$BODY" 2>&1 | head -5
