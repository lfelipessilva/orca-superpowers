#!/usr/bin/env bash
# Low-token wrapper for orca orchestration send.
# Usage: send-brief.sh --run RUN_ID --to DEST --subject SUBJ [--body TEXT] [--type TYPE] [--outcome OUTCOME] [--task-id TID] [--dispatch-id DID]
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
RUN="" TO="" SUBJECT="" BODY="" TYPE="" OUTCOME="" TASK_ID="" DISPATCH_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    --to) TO="${2:?}"; shift 2 ;;
    --subject) SUBJECT="${2:?}"; shift 2 ;;
    --body) BODY="${2:?}"; shift 2 ;;
    --type) TYPE="${2:?}"; shift 2 ;;
    --outcome) OUTCOME="${2:?}"; shift 2 ;;
    --task-id) TASK_ID="${2:?}"; shift 2 ;;
    --dispatch-id) DISPATCH_ID="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --run RUN_ID --to DEST --subject SUBJ [--body TEXT] [--type TYPE]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$SUBJECT" ]] || { echo "--subject required" >&2; exit 2; }

argv=("$ORCA_BIN" orchestration send --subject "$SUBJECT")
[[ -n "$RUN" ]]         && argv+=(--run "$RUN")
[[ -n "$TO" ]]          && argv+=(--to "$TO")
[[ -n "$BODY" ]]        && argv+=(--body "$BODY")
[[ -n "$TYPE" ]]        && argv+=(--type "$TYPE")
[[ -n "$OUTCOME" ]]     && argv+=(--outcome "$OUTCOME")
[[ -n "$TASK_ID" ]]     && argv+=(--task-id "$TASK_ID")
[[ -n "$DISPATCH_ID" ]] && argv+=(--dispatch-id "$DISPATCH_ID")

"${argv[@]}" 2>&1 | head -5
