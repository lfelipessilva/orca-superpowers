#!/usr/bin/env bash
# Bootstrap a WDD Run from a writing-plans markdown file: run-create → task-create → worker-start ready.
# Usage:
#   bash scripts/wdd-boot.sh --plan PATH --agent AGENT [--model ID] [--effort LEVEL] [--worktree current|new-child|path:…] [--deps sequential|none] [--dry-run] [--no-start]
set -euo pipefail

PLAN=""
AGENT=""
MODEL=""
EFFORT=""
WORKTREE="current"
DEPS_MODE="sequential"
DRY_RUN=0
NO_START=0
OBJECTIVE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) PLAN="${2:?}"; shift 2 ;;
    --agent) AGENT="${2:?}"; shift 2 ;;
    --model) MODEL="${2:?}"; shift 2 ;;
    --effort) EFFORT="${2:?}"; shift 2 ;;
    --worktree) WORKTREE="${2:?}"; shift 2 ;;
    --deps) DEPS_MODE="${2:?}"; shift 2 ;;
    --objective) OBJECTIVE="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-start) NO_START=1; shift ;;
    -h|--help)
      sed -n '2,5p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$PLAN" && -f "$PLAN" ]] || { echo "--plan file required" >&2; exit 2; }
[[ -n "$AGENT" ]] || { echo "--agent required" >&2; exit 2; }
PLAN="$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")"

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
if [[ "$DRY_RUN" -eq 0 ]] && ! command -v "$ORCA_BIN" >/dev/null 2>&1; then
  echo "orca CLI not found ($ORCA_BIN)" >&2
  exit 1
fi

export WDD_PLAN="$PLAN" WDD_AGENT="$AGENT" WDD_MODEL="$MODEL" WDD_EFFORT="$EFFORT"
export WDD_WORKTREE="$WORKTREE" WDD_DEPS_MODE="$DEPS_MODE" WDD_DRY_RUN="$DRY_RUN"
export WDD_NO_START="$NO_START" WDD_OBJECTIVE="${OBJECTIVE:-Implement plan $PLAN}" WDD_ORCA="$ORCA_BIN"

python3 <<'PY'
import json, os, re, subprocess, sys
from pathlib import Path

plan_path = Path(os.environ["WDD_PLAN"])
deps_mode = os.environ["WDD_DEPS_MODE"]
dry = os.environ["WDD_DRY_RUN"] == "1"
no_start = os.environ["WDD_NO_START"] == "1"
orca = os.environ["WDD_ORCA"]
agent = os.environ["WDD_AGENT"]
model = os.environ.get("WDD_MODEL") or ""
effort_override = os.environ.get("WDD_EFFORT") or ""
worktree = os.environ["WDD_WORKTREE"]
objective = os.environ["WDD_OBJECTIVE"]

text = plan_path.read_text()
pat = re.compile(r"^#{2,3}\s+Task\s+(\d+)\s*:\s*(.+?)\s*$", re.M)
matches = list(pat.finditer(text))
if not matches:
    sys.exit("no '### Task N: …' headings found in plan")

tasks = []
for i, m in enumerate(matches):
    n, title = int(m.group(1)), m.group(2).strip()
    start, end = m.end(), matches[i + 1].start() if i + 1 < len(matches) else len(text)
    body = text[start:end]
    class_m = re.search(r"\*\*WDD class:\*\*\s*(\w+)", body, re.I)
    wdd_class = (class_m.group(1).lower() if class_m else "")
    if not wdd_class:
        blob = (title + " " + body[:500]).lower()
        if re.search(r"\b(video|carousel|dashboard|web ui|pipeline|dense)\b", blob):
            wdd_class = "dense"
        elif re.search(r"\b(shared|client|wiring|telegram|tiktok)\b", blob):
            wdd_class = "wiring"
        elif re.search(r"\b(scaffold|auth|setup|repo)\b", blob):
            wdd_class = "scaffold"
        else:
            wdd_class = "scaffold"
    review = "cross" if wdd_class == "dense" else "skip"
    effort_hint = {"wiring": "low", "scaffold": "medium", "dense": "high"}[wdd_class]
    tasks.append({"n": n, "title": title, "class": wdd_class, "review": review, "effort_hint": effort_hint})

tasks.sort(key=lambda t: t["n"])
for i, t in enumerate(tasks):
    t["deps_ns"] = [] if deps_mode == "none" or i == 0 else [tasks[i - 1]["n"]]

def run(argv):
    if dry:
        print("[dry-run] " + " ".join(json.dumps(a) if " " in a or "\n" in a else a for a in argv))
        return {}
    out = subprocess.check_output(argv, text=True)
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        print(out)
        return {}

print(f"wdd-boot: plan={plan_path} agent={agent} model={model or 'default'} effort={effort_override or 'per-class'} deps={deps_mode}")

run_res = run([orca, "orchestration", "run-create", "--objective", objective, "--json"])
run_id = "run_dry" if dry else run_res["result"]["runId"]
if not dry:
    print(f"runId={run_id}")

id_map = {}
for t in tasks:
    spec = (
        f"Implement Plan Task {t['n']}: {t['title']}\n"
        f"Plan: {plan_path}\n"
        f"WDD class: {t['class']}\n"
        f"Review policy: {t['review']}\n"
        f"Read only that task section in the plan. TDD + commit. "
        f"On done: worker_done with verification evidence."
    )
    title = f"T{t['n']} [{t['class']}] {t['title']}"
    argv = [orca, "orchestration", "task-create", "--run", run_id, "--task-title", title, "--spec", spec, "--json"]
    if t["deps_ns"]:
        dep_ids = []
        for dn in t["deps_ns"]:
            if dry:
                dep_ids.append(f"task_T{dn}")
            else:
                dep_ids.append(id_map[dn])
        argv.extend(["--deps", json.dumps(dep_ids)])
    print(f"task T{t['n']} class={t['class']} review={t['review']} effort_hint={t['effort_hint']}")
    created = run(argv)
    tid = f"task_T{t['n']}" if dry else (created["result"].get("taskId") or created["result"].get("id"))
    id_map[t["n"]] = tid
    if not dry:
        print(f"  id={tid}")

if no_start:
    print("wdd-boot: --no-start; tasks created only")
    sys.exit(0)

start_ns = [t["n"] for t in tasks] if deps_mode == "none" else ([tasks[0]["n"]] if tasks else [])
by_n = {t["n"]: t for t in tasks}
for n in start_ns:
    t = by_n[n]
    tid = id_map[n]
    use_effort = effort_override or t["effort_hint"]
    argv = [orca, "orchestration", "worker-start", "--run", run_id, "--task", tid,
            "--worktree", worktree, "--agent", agent]
    if model:
        argv.extend(["--model", model])
    if use_effort:
        argv.extend(["--effort", use_effort])
    argv.append("--json")
    print(f"worker-start task={tid} class={t['class']}")
    run(argv)

print(f"wdd-boot: done run={run_id} — end turn; Orca wakes on worker_done")
PY
