---
name: cross-agent-review
description: Use when completing tasks or before merging to dispatch a review worker from a different agent family (heterogeneous review)
---

# Cross-Agent Code Review

Dispatch independent code review workers using heterogeneous agent pairing (e.g. Codex implements, Claude reviews) to eliminate model family blind spots and catch defects before code merges.

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

Dispatch the review worker using `--worktree current` so it inspects the exact working copy without moving HEAD:

```bash
orca orchestration worker-start \
  --spec "$(cat <<EOF
[Paste filled templates/review-worker-spec.md with BASE_SHA and HEAD_SHA]
EOF
)" \
  --worktree current \
  --agent <reviewer_agent>
```

*(Ensure `<reviewer_agent>` is different from the implementer agent).*

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
   orca orchestration task-update --task <task_id> --status completed
   ```
3. Release reviewer terminal:
   ```bash
   orca orchestration worker-release --terminal <reviewer_term>
   ```

### If `VERDICT: CHANGES_REQUESTED`
1. Re-open or steer the implementer worker with the feedback:
   ```bash
   orca orchestration send \
     --to dispatch:<implementer_dispatch_id> \
     --subject "Review feedback for task <task_id>" \
     --body "<Specific review findings>"
   ```
2. End your turn. Orca will wake you when the implementer addresses the fixes.
