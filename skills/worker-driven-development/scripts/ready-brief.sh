#!/usr/bin/env bash
# Ready tasks for a Run — ids + titles only.
# Usage: ready-brief.sh --run RUN_ID
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
RUN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --run RUN_ID"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RUN" ]] || { echo "--run required" >&2; exit 2; }

"$ORCA_BIN" orchestration task-list --run "$RUN" --ready --brief 2>/dev/null \
  || "$ORCA_BIN" orchestration task-list --run "$RUN" --ready --json | python3 -c '
import json,sys
d=json.load(sys.stdin)
rows=d.get("result",d)
if isinstance(rows, dict):
  rows=rows.get("tasks") or rows.get("items") or []
for t in rows or []:
  tid=t.get("taskId") or t.get("id") or ""
  title=t.get("title") or t.get("taskTitle") or ""
  print(f"{tid}\t{title}")
'
