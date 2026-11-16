#!/usr/bin/env bash
# Compact task listing: id, status, title — one line per task.
# Usage: task-list-brief.sh --run RUN_ID
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

"$ORCA_BIN" orchestration task-list --run "$RUN" --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
res = d.get("result", d)
tasks = res.get("tasks") if isinstance(res, dict) else (res if isinstance(res, list) else [])
done = sum(1 for t in tasks if (t.get("status") or "").lower() == "completed")
print(f"[{done}/{len(tasks)} completed]")
for t in tasks:
    tid = t.get("id") or t.get("taskId") or ""
    status = t.get("status") or ""
    title = t.get("title") or ""
    print(f"  {tid}\t{status}\t{title}")
'
