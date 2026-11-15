#!/usr/bin/env bash
# Automated cross-agent review dispatcher for WDD class dense tasks.
# Usage: review-brief.sh --run RUN_ID --task TASK_ID [--reviewer AGENT] [--worktree WT]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"

RUN=""
TASK_ID=""
REVIEWER=""
WORKTREE="current"
BASE_REF=""
HEAD_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN="${2:?}"; shift 2 ;;
    --task|--id) TASK_ID="${2:?}"; shift 2 ;;
    --reviewer) REVIEWER="${2:?}"; shift 2 ;;
    --worktree) WORKTREE="${2:?}"; shift 2 ;;
    --base) BASE_REF="${2:?}"; shift 2 ;;
    --head) HEAD_REF="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --run RUN_ID --task TASK_ID [--reviewer AGENT] [--worktree WT]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$RUN" ]] || { echo "--run required" >&2; exit 2; }
[[ -n "$TASK_ID" ]] || { echo "--task required" >&2; exit 2; }

python3 - "$ORCA_BIN" "$SCRIPTS" "$RUN" "$TASK_ID" "$REVIEWER" "$WORKTREE" "$BASE_REF" "$HEAD_REF" <<'PY'
import json, os, re, shlex, subprocess, sys

orca, scripts, run_id, task_id, reviewer_override, worktree, base_ref, head_ref = sys.argv[1:9]

def run_cmd(argv):
    try:
        out = subprocess.check_output(argv, text=True, stderr=subprocess.DEVNULL)
        try:
            return json.loads(out)
        except Exception:
            return {"raw": out}
    except subprocess.CalledProcessError as e:
        sys.exit(f"orca command failed: {' '.join(argv)}\n{e}")

# 1. Inspect task title
tasks_res = run_cmd([orca, "orchestration", "task-list", "--run", run_id, "--json"])
res_obj = tasks_res.get("result", tasks_res)
all_tasks = res_obj.get("tasks") if isinstance(res_obj, dict) else (res_obj if isinstance(res_obj, list) else [])
task_map = {t.get("id") or t.get("taskId"): t for t in all_tasks}
parent_task = task_map.get(task_id, {})
parent_title = parent_task.get("title") or task_id

# 2. Inspect implementer agent
workers_res = run_cmd([orca, "orchestration", "worker-list", "--run", run_id, "--json"])
w_obj = workers_res.get("result", workers_res)
all_workers = w_obj.get("workers") if isinstance(w_obj, dict) else (w_obj if isinstance(w_obj, list) else [])

impl_agent = "antigravity"
for w in reversed(all_workers):
    if w.get("taskId") == task_id and w.get("agent"):
        impl_agent = w.get("agent")
        break

# 3. Choose heterogeneous reviewer agent
chosen_reviewer = reviewer_override
if not chosen_reviewer:
    # Query available agents
    try:
        agents_out = subprocess.check_output(
            ["bash", f"{scripts}/agents-brief.sh", "--ok-only"],
            text=True, stderr=subprocess.DEVNULL
        )
        ok_agents = [line.split()[0] for line in agents_out.splitlines() if line.strip()]
    except Exception:
        ok_agents = []

    # Pick an agent from a different family
    candidates = [a for a in ok_agents if a != impl_agent]
    if candidates:
        # Prefer cursor, claude, codex, antigravity in that order
        pref = ["cursor", "claude", "codex", "antigravity"]
        sorted_cands = sorted(candidates, key=lambda x: pref.index(x) if x in pref else 99)
        chosen_reviewer = sorted_cands[0]
    else:
        chosen_reviewer = "cursor" if impl_agent != "cursor" else "antigravity"

# 4. Resolve git range
if not head_ref:
    try:
        head_ref = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
    except Exception:
        head_ref = "HEAD"
if not base_ref:
    try:
        base_ref = subprocess.check_output(["git", "rev-parse", "--short", "HEAD~1"], text=True).strip()
    except Exception:
        base_ref = "HEAD~1"

# 5. Build review spec
spec = f"""## Reviewer Mission
You are a Senior Staff Engineer conducting a rigorous, read-only code review.
Your goal is to inspect the completed changes for spec compliance, code quality, edge cases, and test coverage before work merges.

## Implemented Work Summary
Review Task {task_id}: {parent_title}

## Git Inspection Range
**Base:** {base_ref}
**Head:** {head_ref}

Review commands to run:
```bash
git diff --stat {base_ref}..{head_ref}
git diff {base_ref}..{head_ref}
```

## Constraints
1. Read-Only Review: do NOT edit files, commit, or alter git branch state.
2. Evidence-Based Feedback: cite exact file and line numbers.

## Deliverable & Verdict
Conclude your review with one of:
- `VERDICT: APPROVED` (if changes are correct, clean, and fully tested)
- `VERDICT: CHANGES_REQUESTED` (with prioritized actionable items)

Report findings via `worker_done`.
"""

# 6. Create review task with --parent
rev_title = f"Review: {parent_title}"
create_argv = [
    orca, "orchestration", "task-create",
    "--run", run_id,
    "--task-title", rev_title,
    "--spec", spec,
    "--parent", task_id,
    "--json"
]
create_res = run_cmd(create_argv)
c_obj = create_res.get("result", create_res)
rev_task_id = c_obj.get("taskId") or c_obj.get("id") or "task_rev"

# 7. Sanitize reviewer flags (strips effort for cursor, defaults model, etc.)
config_sh = f"{scripts}/wdd-config.sh"
sanitized = subprocess.check_output(
    ["bash", config_sh, "sanitize-flags", "--agent", chosen_reviewer, "--effort", "high"],
    text=True
).strip()

start_argv = [
    orca, "orchestration", "worker-start",
    "--run", run_id,
    "--task", rev_task_id,
    "--worktree", worktree
]
start_argv.extend(shlex.split(sanitized))
start_argv.append("--json")

start_res = run_cmd(start_argv)
s_obj = start_res.get("result", start_res)
dispatch_id = s_obj.get("dispatchId", "ctx_rev")

print(f"Review dispatched: {rev_task_id} ({sanitized}) dispatch={dispatch_id} for {task_id}. End turn; Orca wakes on VERDICT.")
PY
