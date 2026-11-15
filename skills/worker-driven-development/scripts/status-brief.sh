#!/usr/bin/env bash
# Ultra-compact status overview for an orchestration Run (<6 lines).
# Usage: status-brief.sh --run RUN_ID
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

python3 - "$ORCA_BIN" "$RUN" <<'PY'
import json, subprocess, sys

orca, run_id = sys.argv[1], sys.argv[2]

def run_json(cmd):
    try:
        out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
        d = json.loads(out)
        return d.get("result", d)
    except Exception:
        return {}

tasks_data = run_json([orca, "orchestration", "task-list", "--run", run_id, "--json"])
tasks = tasks_data.get("tasks") if isinstance(tasks_data, dict) else (tasks_data if isinstance(tasks_data, list) else [])

workers_data = run_json([orca, "orchestration", "worker-list", "--run", run_id, "--json"])
workers = workers_data.get("workers") if isinstance(workers_data, dict) else (workers_data if isinstance(workers_data, list) else [])

inbox_data = run_json([orca, "orchestration", "inbox", "--json"])
msgs = inbox_data.get("messages") if isinstance(inbox_data, dict) else (inbox_data if isinstance(inbox_data, list) else [])

# 1. Task progress
total_tasks = len(tasks)
completed_tasks = sum(1 for t in tasks if (t.get("status") or "").lower() == "completed")
task_map = {t.get("id") or t.get("taskId"): t for t in tasks}

print(f"Run: {run_id} [{completed_tasks}/{total_tasks} tasks completed]")

# 2. Active worker
active_workers = [
    w for w in workers
    if (w.get("state") or "").lower() in ("running", "dispatched", "ready")
    and not (w.get("outcome") or "")
]

if active_workers:
    w = active_workers[0]
    did = w.get("dispatchId", "unknown")
    tid = w.get("taskId", "")
    ag = w.get("agent", "")
    mod = w.get("model", "")
    st = w.get("state", "running")
    t_title = task_map.get(tid, {}).get("title", tid) if tid else "no task"
    agent_info = f"{ag}/{mod}" if mod else ag
    print(f"Active: {did} ({agent_info}) on {tid}: {t_title} ({st})")
else:
    print("Active: none")

# 3. Inbox messages (peeking, unhandled)
if msgs:
    first = msgs[0]
    subj = first.get("subject") or "message"
    pl = first.get("payload") or ""
    summary = f"{subj} {pl}".strip()[:60]
    print(f"Inbox: {len(msgs)} unread: {summary}")
else:
    print("Inbox: 0 unread")

# 4. Ready tasks
ready_tasks = [t for t in tasks if (t.get("status") or "").lower() == "ready"]
if ready_tasks:
    rt = ready_tasks[0]
    tid = rt.get("id") or rt.get("taskId") or ""
    title = rt.get("title") or ""
    more = f" (+{len(ready_tasks)-1} more)" if len(ready_tasks) > 1 else ""
    print(f"Ready: {tid} {title}{more}")
else:
    print("Ready: none")
PY
