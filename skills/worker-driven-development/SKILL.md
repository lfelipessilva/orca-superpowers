---
name: worker-driven-development
description: Use when executing multi-step implementation plans in Orca using supervised workers, task DAGs, decision gates, and cross-agent review
---

# Worker-Driven Development (WDD)

Execute implementation plans in Orca by orchestrating supervised workers across an explicit Task DAG, enforcing TDD, triggering cross-agent reviews after each task, and using non-blocking decision gates for human alignment.

**Core principle:** Fresh worker per task + Cross-agent review (e.g. Codex implements, Claude reviews) + Non-blocking Decision Gates = fast, reliable, industrial-grade delivery.

**Coordinator CLI — use `wdd` for EVERY orchestration action.** Never call raw `orca orchestration` commands; the scripts compress output and save tokens.

After `install.sh --global`:

```bash
WDD=~/.agents/skills/worker-driven-development/scripts/wdd
# from this skill tree: bash scripts/wdd …
bash "$WDD" boot --plan <plan.md> --agent <id> [--model …] [--effort …]
bash "$WDD" status --run <run_id>         # compact run & worker summary (<6 lines)
bash "$WDD" check --run <run_id>          # 1-line event summary on wakeup
bash "$WDD" complete --run <run_id> --task <id> [--start-next]
bash "$WDD" review --run <run_id> --task <id>  # automated cross-agent review
bash "$WDD" send --run <run_id> --to dispatch:<id> --subject "…" --body "…"
bash "$WDD" reply --id <msg_id> --body "…"
bash "$WDD" gate create --task <id> --question "…" [--options '[…]']
bash "$WDD" show --dispatch <id>          # compact worker state (<5 lines)
bash "$WDD" read --dispatch <id>          # bounded worker output tail (<25 lines)
bash "$WDD" release --dispatch <id>       # release worker terminal
bash "$WDD" task-list --run <run_id>      # compact task listing
bash "$WDD" config set <agent>.model <id> [--global|--local]
bash "$WDD" models --agent antigravity --ids-only
bash "$WDD" agents [--ok-only]             # NOT raw account list --json
bash "$WDD" ready --run <run_id>
bash "$WDD" workers --run <run_id>
```

Smart defaults and flag sanitization (e.g. Antigravity requires `--model` with `--effort`; Cursor encodes effort in model IDs and strips `--effort`) are enforced automatically by `wdd`. Configure persistent defaults with `wdd config set <agent>.model <model>` or `.wddrc`.

---

## Lean coordinator

Your job is dispatch, not implementation. Minimize tokens every turn.

1. **Bootstrap once** with `wdd boot …`. Then **end turn**.
2. **On wakeup — one action, then end turn.** Map the event and stop:
   - Check the event: `wdd check --run <run_id>`
   - `ask` → `wdd reply --id <msg_id> --body "..."` (or `wdd gate create` if a real fork)
   - `worker_done` + tests green + class `wiring`/`scaffold` → `wdd complete --run <run_id> --task <id> --start-next`
   - `worker_done` + class `dense` → `wdd review --run <run_id> --task <id>`; do not also inspect the diff yourself
   - review `APPROVED` → `wdd complete --run <run_id> --task <id> --start-next`
   - review `CHANGES_REQUESTED` → `wdd send --run <run_id> --to dispatch:<impl_dispatch> --subject "Review findings" --body "..."`
   - failed/stopped → `wdd status --run <run_id>`. If diagnosing: `wdd read --dispatch <id>` (tail <25 lines) or `wdd show --dispatch <id>`, then unblock via `wdd send` or restart. Never dump raw transcripts, full worker-show, or load recovery reference docs.
3. **Inspect status?** When asked "is task X running?", run **one** `wdd status --run <run_id>` — never run python dumps, terminal greps, or git diff tours.
4. **Do not** re-read the whole plan, `orca skills get --full`, worker transcripts, or local `git diff` on the happy path. Trust `worker_done` evidence; open artifacts only on failure.
5. **Narration ≤ one short line** per turn (or silence). Specs are plan pointers — see [templates/worker-spec-template.md](templates/worker-spec-template.md).
6. **Need auth/models?** `wdd agents` / `wdd models` only — never raw `account list --json` or `agent-context`.

---

## Selective review

Tag each task with **WDD class** (`**WDD class:** wiring|scaffold|dense` in the plan, or let `wdd boot` infer):

| Class | Typical work | Effort hint | Cross-agent review |
| :--- | :--- | :--- | :--- |
| **wiring** | shared clients, thin adapters | low | **skip** (implementer self-check + tests) |
| **scaffold** | repo/auth/setup, medium APIs | medium | **skip** |
| **dense** | videos/carousels/web, pipe boundaries | high | **required** (`cross-agent-review`) |

Never skip review on `dense`. Never pay for heterogeneous review on `wiring`/`scaffold` unless your human partner asks.

---

## Dispatch without a discovery tour

When your human partner names `--agent` / `--model` / `--effort`, pass them straight into `wdd boot` / `worker-start`. Resolve unknown ids with `wdd models`. If the agent family itself is unknown, **one** `wdd agents` (not raw account list).

**Do not:** `agy models`, `agent models`, `claude models`, `find` for runtimes, `orca agent-context`, raw `account list --json`, or `--help` fishing before the first start.

Effort when unspecified: use class hints above / `defaults.effort` in the catalog.

---

## Why Orca Workers instead of Subagents

1. **Context Cleanliness:** Workers start with fresh context and only the exact task spec they need. They never inherit session debris or compaction errors.
2. **True Heterogeneity:** Dispatch different tasks to the agent best suited for them (see [agent-matrix.md](references/agent-matrix.md)).
3. **User Transparency:** Workers run in dedicated Orca tabs/terminals where your human partner can monitor progress in real time.
4. **Resilient Reactive Scheduling:** The coordinator sleeps while workers run; Orca wakes the coordinator when events occur.

---

## The WDD Coordinator Loop

```text
1. Boot DAG        → bash scripts/wdd boot --plan <plan> --agent <id> [--model] [--effort]
2. Sleep & End Turn → Wait for reactive Orca wakeups (NO polling)
3. On Wakeup        → One action (Lean coordinator) then end turn
4. Selective review → cross-agent only for WDD class dense
5. Repeat / Settle  → Until all tasks completed
```

Manual equivalent (avoid unless boot cannot run): `run-create` → `task-create` (plan-pointer specs + `--deps`) → `worker-start` ready.

*(Use `--worktree current` only when this session's worktree **is** the target repo. Prefer `--worktree path:/abs/target` or `id:…`, and always `--run <run_id>`.)*

### Decision Gates

Ambiguity / high-risk consent → `gate-create` on that task only; other ready tasks keep running:

```bash
wdd gate create --task <task_id> --question "Option A or B?" --options '["Option A", "Option B"]'
```

---

## Completion & Teardown

When `wdd task-list --run <run_id>` shows all tasks completed:
1. Run full verification with `superpowers:verification-before-completion`.
2. Release worker terminal allocations:
   ```bash
   wdd release --dispatch <dispatch_id>
   ```
3. Complete development branch with `superpowers:finishing-a-development-branch`.
