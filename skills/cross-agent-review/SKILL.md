---
name: cross-agent-review
description: Use when completing tasks or before merging to dispatch a review worker from a different agent family (heterogeneous review)
---

# Cross-Agent Code Review

Dispatch independent code review workers using heterogeneous agent pairing (e.g. Codex implements, Claude reviews) to eliminate model family blind spots and catch defects before code merges.

---

## Selective review (when to dispatch)

Only run this skill when the parent task is **WDD class `dense`** (or your human partner explicitly asks for review).

| WDD class | Action |
| :--- | :--- |
| **wiring** / **scaffold** | **Skip** cross-agent review. Coordinator marks the task completed from implementer `worker_done` + tests. |
| **dense** | **Required** — continue below with a different agent family. |

Do not burn a reviewer worker on scaffold/wiring unless asked.

---

## The Heterogeneous Review Principle

> **Never allow an agent model to review code written by the same model family when an alternative agent is available.**

Language models from the same provider often share identical training biases, tokenization artifacts, and blind spots regarding API subtleties or concurrency races.

By enforcing **heterogeneous review**:
- **Codex implementation → Claude review**: Combines Codex's fast code generation with Claude's nuanced architectural scrutiny and edge-case detection.
- **Claude implementation → Codex/Antigravity review**: Combines Claude's design with Codex's precision in test boundary checking and API contract conformance.

---

## Step 1: Capture Diff Boundaries

Before dispatching the reviewer worker, record the exact commit range:

```bash
BASE_SHA=$(git rev-parse HEAD~1) # or base branch SHA
HEAD_SHA=$(git rev-parse HEAD)
```

---

## Step 2: Dispatch Reviewer Worker

Dispatch the review using the `wdd review` script, which handles agent selection, spec building, and worker start automatically:

```bash
wdd review --run <run_id> --task <task_id>
```

The script picks a heterogeneous reviewer (different agent family from the implementer), creates a review sub-task with `--parent`, and starts the worker. To override the reviewer agent:

```bash
wdd review --run <run_id> --task <task_id> --reviewer claude
```

---

## Step 3: Read-Only Review Constraint

The reviewer worker is strictly constrained to a **read-only** role:
- It inspects history with `git show`, `git diff`, and `git log`.
- It executes tests in place if needed to verify failures.
- It MUST NOT edit files, amend commits, or mutate branch pointers.

---

## Step 4: Act on Review Findings

When Orca wakes you with the reviewer's `worker_done`:

### If `VERDICT: APPROVED`
1. Settle the review task.
2. Mark the parent task completed in the DAG:
   ```bash
   wdd complete --run <run_id> --task <task_id> --start-next
   ```

### If `VERDICT: CHANGES_REQUESTED`
1. Re-open or steer the implementer worker with the feedback:
   ```bash
   wdd send --run <run_id> --to dispatch:<implementer_dispatch_id> \
     --subject "Review feedback for task <task_id>" \
     --body "<Specific review findings>"
   ```
2. End your turn. Orca will wake you when the implementer addresses the fixes.
