---
name: dispatching-parallel-workers
description: Use when facing 2+ independent failures, test breakages, or decoupled tasks to run concurrent Orca workers in child worktrees
---

# Dispatching Parallel Workers

When you face multiple independent issues (unrelated failing test suites, separate micro-features, or decoupled bugs), investigating or fixing them sequentially wastes time.

Orca enables true concurrent multi-agent execution by dispatching parallel workers into isolated **child worktrees** (`--worktree new-child`).

---

## When to Dispatch in Parallel

```text
Are there multiple tasks / failures?
  ├── YES ──► Are they independent (no shared files/state)?
  │             ├── YES ──► Dispatch parallel workers in child worktrees
  │             └── NO  ──► Sequential execution via Task DAG
  └── NO  ──► Single worker execution
```

**Great for:**
- 3+ test suites failing with different root causes (e.g. `auth.test.ts` and `billing.test.ts`).
- Migrating multiple independent modules to a new interface.
- Simultaneously writing documentation, frontend styles, and backend validators.

---

## Step 1: Identify Independent Domains

Group the tasks into distinct boundaries where workers will not overwrite each other's files:
- Domain A: `src/auth/`
- Domain B: `src/billing/`
- Domain C: `src/notifications/`

---

## Step 2: Dispatch Concurrent Workers in Child Worktrees

Dispatch each worker in its own child worktree using `--worktree new-child --name <domain>`:

```bash
# Worker 1: Auth domain
orca orchestration worker-start \
  --spec "Fix failing tests in tests/auth.test.ts. Follow TDD and commit." \
  --worktree new-child \
  --name "auth-fix" \
  --agent codex

# Worker 2: Billing domain
orca orchestration worker-start \
  --spec "Fix race conditions in tests/billing.test.ts. Follow TDD and commit." \
  --worktree new-child \
  --name "billing-fix" \
  --agent claude
```

Each worker runs in its own isolated worktree and git branch, eliminating file contention or lock errors.

---

## Step 3: End Your Turn (Reactive Wakeup)

Once all parallel workers are dispatched:
- **End your turn immediately**.
- Do NOT poll or run wait loops.
- Orca will wake the coordinator as each worker finishes (`worker_done`) or if a worker requires input (`ask`).

---

## Step 4: Settle and Merge Integration

As each worker settles:
1. Inspect the child worktree branch:
   ```bash
   git log -1 <child_branch>
   git diff main..<child_branch>
   ```
2. Merge the clean child branch back into your coordinator workspace:
   ```bash
   git merge --no-ff <child_branch> -m "Merge parallel fix: <domain>"
   ```
3. Run the integrated test suite to verify no cross-module regression.
4. Release the settled worker terminal:
   ```bash
   orca orchestration worker-release --terminal <terminal_handle>
   ```
