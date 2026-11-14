#!/usr/bin/env bash
# Compact worker rows for a Run (dispatch, task, state, next) — no full transcripts.
# Usage: workers-brief.sh --run RUN_ID
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

"$ORCA_BIN" orchestration worker-list --run "$RUN" --json | python3 -c '
import json,sys
d=json.load(sys.stdin)
res=d.get("result",d)
workers=res.get("workers") if isinstance(res, dict) else res
if not workers:
  print("(none)")
  sys.exit(0)
for w in workers:
  did=w.get("dispatchId") or ""
  tid=w.get("taskId") or ""
  state=w.get("state") or ""
  outcome=w.get("outcome") or ""
  nxt=w.get("next") or ""
  if isinstance(nxt, list):
    nxt="; ".join(nxt)
  print(f"{did}\t{tid}\t{state}/{outcome}\t{nxt}")
'
