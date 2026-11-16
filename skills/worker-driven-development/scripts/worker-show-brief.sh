#!/usr/bin/env bash
# Compact worker inspection (<5 lines).
# Usage: worker-show-brief.sh --dispatch DISPATCH_ID
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
DISPATCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dispatch|--id) DISPATCH="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --dispatch DISPATCH_ID"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$DISPATCH" ]] || { echo "--dispatch required" >&2; exit 2; }

python3 - "$ORCA_BIN" "$DISPATCH" <<'PY'
import json, subprocess, sys

orca, did = sys.argv[1], sys.argv[2]

try:
    out = subprocess.check_output([orca, "orchestration", "worker-show", "--dispatch", did, "--json"], text=True)
    d = json.loads(out)
    res = d.get("result", d)
    tid = res.get("taskId", "")
    st = res.get("state", "")
    stage = res.get("stage", "")
    live = res.get("liveness", "")
    act = res.get("activity", "")
    last_act = res.get("lastActivity", "")
    ag = res.get("agent", "")
    mod = res.get("model", "")
    waiting = res.get("waitingOnHuman", "")
    print(f"dispatch={did} task={tid} state={st} stage={stage} liveness={live}")
    print(f"  activity={act} lastActivity=\"{last_act}\" agent={ag}/{mod} waitingOnHuman={waiting}")
except Exception as e:
    # Fallback to plain command output
    try:
        p = subprocess.run([orca, "orchestration", "worker-show", "--dispatch", did], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        lines = [l for l in p.stdout.splitlines() if l.strip()]
        for l in lines[:5]:
            print(l)
    except Exception:
        print(f"Error inspecting worker {did}: {e}")
PY
