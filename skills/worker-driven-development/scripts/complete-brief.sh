#!/usr/bin/env bash
# Atomically complete a task (normalizing --task / --id) and optionally start the next ready task.
# Usage: complete-brief.sh --run RUN_ID (--task ID | --id ID) [--result MSG] [--status completed] [--start-next] [--agent AGENT] [--worktree WT]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"

RUN=""
TASK_ID=""
STATUS="completed"
RESULT=""
START_NEXT=0
AGENT_OVERRIDE=""
WORKTREE="current"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    --task|--id) TASK_ID="${2:?}"; shift 2 ;;
    --status) STATUS="${2:?}"; shift 2 ;;
    --result) RESULT="${2:?}"; shift 2 ;;
    --start-next) START_NEXT=1; shift ;;
    --agent) AGENT_OVERRIDE="${2:?}"; shift 2 ;;
    --worktree) WORKTREE="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --run RUN_ID (--task ID | --id ID) [--result MSG] [--status completed] [--start-next] [--agent AGENT]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$RUN" ]] || { echo "--run required" >&2; exit 2; }
[[ -n "$TASK_ID" ]] || { echo "--task or --id required" >&2; exit 2; }

python3 - "$ORCA_BIN" "$SCRIPTS" "$RUN" "$TASK_ID" "$STATUS" "$RESULT" "$START_NEXT" "$AGENT_OVERRIDE" "$WORKTREE" <<'PY'
import json, re, shlex, subprocess, sys

orca, scripts, run_id, task_id, status, result, start_next_str, agent_override, worktree = sys.argv[1:10]
start_next = start_next_str == "1"

def run_cmd(argv):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        err_msg = p.stderr.strip() or p.stdout.strip()
        sys.exit(f"orca command failed ({' '.join(argv)}):\n{err_msg}")
    try:
        return json.loads(p.stdout)
    except Exception:
        return {"raw": p.stdout}

# 1. Update task status (using the correct --id flag)
update_argv = [orca, "orchestration", "task-update", "--run", run_id, "--id", task_id, "--status", status]
if result:
    update_argv.extend(["--result", result])
update_argv.append("--json")

run_cmd(update_argv)
print(f"Task {task_id} marked {status}")

if not start_next:
    sys.exit(0)

# 2. Check ready tasks
tasks_res = run_cmd([orca, "orchestration", "task-list", "--run", run_id, "--json"])
res_obj = tasks_res.get("result", tasks_res)
all_tasks = res_obj.get("tasks") if isinstance(res_obj, dict) else (res_obj if isinstance(res_obj, list) else [])
ready_tasks = [t for t in all_tasks if (t.get("status") or "").lower() == "ready"]

if not ready_tasks:
    print("start-next: no newly ready tasks.")
    sys.exit(0)

# Build map of task IDs to titles to distinguish reviews from implementation tasks
task_title_map = {t.get("id") or t.get("taskId"): (t.get("title") or "") for t in all_tasks}

# Determine agent to use:
# 1) explicit agent override
# 2) agent from previous non-review worker
# 3) default config
chosen_agent = agent_override
if not chosen_agent:
    workers_res = run_cmd([orca, "orchestration", "worker-list", "--run", run_id, "--json"])
    w_obj = workers_res.get("result", workers_res)
    workers = w_obj.get("workers") if isinstance(w_obj, dict) else (w_obj if isinstance(w_obj, list) else [])
    for w in reversed(workers):
        ag = w.get("agent")
        tid = w.get("taskId") or ""
        title = task_title_map.get(tid, "")
        # Skip review workers by checking title
        if ag and not title.lower().startswith("review"):
            chosen_agent = ag
            break
if not chosen_agent:
    chosen_agent = "antigravity"

# Launch the first ready task
target_task = ready_tasks[0]
tid = target_task.get("id") or target_task.get("taskId")
title = target_task.get("title") or ""

# Infer effort hint from class tag in title, e.g. T2 [dense]
class_m = re.search(r"\[(dense|wiring|scaffold)\]", title, re.I)
wdd_class = class_m.group(1).lower() if class_m else "scaffold"
effort_hint = {"wiring": "low", "scaffold": "medium", "dense": "high"}.get(wdd_class, "medium")

# Sanitize flags via wdd-config.sh
config_sh = f"{scripts}/wdd-config.sh"
sanitized = subprocess.check_output(
    ["bash", config_sh, "sanitize-flags", "--agent", chosen_agent, "--effort", effort_hint],
    text=True
).strip()

start_argv = [orca, "orchestration", "worker-start", "--run", run_id, "--task", tid, "--worktree", worktree]
start_argv.extend(shlex.split(sanitized))
start_argv.append("--json")

print(f"worker-start: launching {tid} ({title}) with {sanitized}")
run_cmd(start_argv)
PY
