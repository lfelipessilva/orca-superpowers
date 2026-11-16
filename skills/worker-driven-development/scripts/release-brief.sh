#!/usr/bin/env bash
# Low-token wrapper for orca orchestration worker-release.
# Usage: release-brief.sh (--dispatch ID | --terminal HANDLE)
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
DISPATCH="" TERMINAL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dispatch) DISPATCH="${2:?}"; shift 2 ;;
    --terminal) TERMINAL="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 (--dispatch ID | --terminal HANDLE)"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$DISPATCH" ]]; then
  "$ORCA_BIN" orchestration worker-release --dispatch "$DISPATCH" 2>&1 | head -5
elif [[ -n "$TERMINAL" ]]; then
  "$ORCA_BIN" orchestration worker-release --terminal "$TERMINAL" 2>&1 | head -5
else
  echo "--dispatch or --terminal required" >&2; exit 2
fi
