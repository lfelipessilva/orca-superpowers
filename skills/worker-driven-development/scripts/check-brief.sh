#!/usr/bin/env bash
# Low-token parser for orca orchestration check.
# Extracts essential message payload into a clean 1-line event.
# Usage: check-brief.sh --run RUN_ID [--peek]
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
RUN=""
PEEK=0

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; args+=("--run" "$RUN"); shift 2 ;;
    --peek) PEEK=1; args+=("--peek"); shift ;;
    -h|--help) echo "Usage: $0 --run RUN_ID [--peek]"; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

[[ -n "$RUN" ]] || { echo "--run required" >&2; exit 2; }

python3 - "$ORCA_BIN" "${args[@]}" <<'PY'
import re, subprocess, sys

orca = sys.argv[1]
cmd_args = sys.argv[2:]

try:
    out = subprocess.check_output([orca, "orchestration", "check"] + cmd_args, text=True, stderr=subprocess.STDOUT)
except subprocess.CalledProcessError as e:
    out = e.output

if not out.strip() or "no unread" in out.lower():
    print("No unread messages.")
    sys.exit(0)

# Parse standard orca orchestration check output
# Example:
#   id: msg_123
#   subject: worker_done
#   from: dispatch:ctx_5cf5176e0772
#   payload: taskId=task_aa317c5f8980 dispatchId=ctx_5cf5176e0772 outcome=succeeded

subject_m = re.search(r"^\s*subject:\s*(\w+)", out, re.M)
from_m = re.search(r"^\s*from:\s*(\S+)", out, re.M)
id_m = re.search(r"^\s*id:\s*(\S+)", out, re.M)
payload_m = re.search(r"^\s*payload:\s*(.+)$", out, re.M)

subj = subject_m.group(1) if subject_m else "message"
sender = from_m.group(1) if from_m else ""
msg_id = id_m.group(1) if id_m else ""
payload = payload_m.group(1) if payload_m else ""

if subj == "worker_done":
    tid_m = re.search(r"taskId=(\S+)", payload)
    did_m = re.search(r"dispatchId=(\S+)", payload)
    out_m = re.search(r"outcome=(\S+)", payload)
    tid = tid_m.group(1) if tid_m else ""
    did = did_m.group(1) if did_m else sender.replace("dispatch:", "")
    outcome = out_m.group(1) if out_m else "done"
    print(f"[worker_done] task={tid} dispatch={did} outcome={outcome}")
elif subj == "ask":
    q_m = re.search(r"question=[\"']?([^\"'\n]+)[\"']?", payload)
    q = q_m.group(1) if q_m else payload
    print(f"[ask] id={msg_id} from={sender} question=\"{q}\"")
else:
    # generic fallback, 1 line
    clean_pl = payload[:80]
    print(f"[{subj}] id={msg_id} from={sender} payload={clean_pl}")
PY
