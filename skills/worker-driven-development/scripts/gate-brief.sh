#!/usr/bin/env bash
# Low-token wrapper for orca orchestration gate-create / gate-resolve / gate-list.
# Usage:
#   gate-brief.sh create --task TASK_ID --question TEXT [--options JSON_ARRAY]
#   gate-brief.sh resolve --id GATE_ID --choice TEXT
#   gate-brief.sh list [--run RUN_ID]
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
CMD="${1:-}"; shift || true

case "$CMD" in
  create)
    TASK="" QUESTION="" OPTIONS=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --task) TASK="${2:?}"; shift 2 ;;
        --question) QUESTION="${2:?}"; shift 2 ;;
        --options) OPTIONS="${2:?}"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    [[ -n "$TASK" && -n "$QUESTION" ]] || { echo "--task and --question required" >&2; exit 2; }
    argv=("$ORCA_BIN" orchestration gate-create --task "$TASK" --question "$QUESTION")
    [[ -n "$OPTIONS" ]] && argv+=(--options "$OPTIONS")
    "${argv[@]}" 2>&1 | head -5
    ;;
  resolve)
    GATE_ID="" RESOLUTION=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --id|--gate) GATE_ID="${2:?}"; shift 2 ;;
        --resolution|--choice) RESOLUTION="${2:?}"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    [[ -n "$GATE_ID" && -n "$RESOLUTION" ]] || { echo "--id (or --gate) and --resolution (or --choice) required" >&2; exit 2; }
    "$ORCA_BIN" orchestration gate-resolve --id "$GATE_ID" --resolution "$RESOLUTION" 2>&1 | head -5
    ;;
  list)
    RUN=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --run) RUN="${2:?}"; shift 2 ;;
        *) shift ;;
      esac
    done
    argv=("$ORCA_BIN" orchestration gate-list)
    [[ -n "$RUN" ]] && argv+=(--run "$RUN")
    "${argv[@]}" 2>&1 | head -20
    ;;
  *)
    echo "Usage: $0 create|resolve|list [flags]" >&2; exit 2
    ;;
esac
