---
name: worker-driven-development
description: Use when executing multi-step implementation plans in Orca using supervised workers, task DAGs, decision gates, and cross-agent review
---

# Worker-Driven Development (WDD)

Execute implementation plans in Orca by orchestrating supervised workers across an explicit Task DAG, enforcing TDD, triggering cross-agent reviews after each task, and using non-blocking decision gates for human alignment.

**Core principle:** Fresh worker per task + Cross-agent review (e.g. Codex implements, Claude reviews) + Non-blocking Decision Gates = fast, reliable, industrial-grade delivery.

---

## Why Orca Workers instead of Subagents

1. **Context Cleanliness:** Workers start with fresh context and only the exact task spec they need. They never inherit session debris or compaction errors.
2. **True Heterogeneity:** Dispatch different tasks to the agent best suited for them (see [agent-matrix.md](references/agent-matrix.md)).
3. **User Transparency:** Workers run in dedicated Orca tabs/terminals where your human partner can monitor progress in real time.
4. **Resilient Reactive Scheduling:** The coordinator sleeps while workers run; Orca wakes the coordinator when events occur.

---

## The WDD Coordinator Loop

```text
1. Initialize Run   → orca orchestration run-create --objective "<goal>"
2. Populate DAG     → orca orchestration task-create --spec "<spec>" [--deps '<json>']
3. Dispatch Ready   → orca orchestration task-list --ready --brief
                      orca orchestration worker-start --task <id> --agent <agent>
4. Sleep & End Turn → Wait for reactive Orca wakeups (NO polling)
5. On Wakeup        → Handle worker_done, answer questions, or resolve gates
6. Cross-Review     → Dispatch review worker from a different agent family
7. Repeat / Settle  → Next ready tasks until Run is complete
```

---

## Step-by-Step Execution

### Step 1: Initialize the Run

Create a lightweight Orca orchestration run to anchor this plan's lifecycle:

```bash
orca orchestration run-create --objective "Implement [Feature Name] per plan [Path]"
```

Orca binds this run to your coordinator session.

### Step 2: Populate the Task DAG

Read the implementation plan and register each bite-sized task. Encode dependencies explicitly using `--deps`:

```bash
# Task 1 (no dependencies)
orca orchestration task-create --spec "Task 1: Core data models and schemas"

# Task 2 (depends on Task 1)
orca orchestration task-create --spec "Task 2: API routes and validation" --deps '["task_1"]'

# Task 3 (depends on Task 2)
orca orchestration task-create --spec "Task 3: Integration tests and documentation" --deps '["task_2"]'
```

### Step 3: Check Ready Tasks and Dispatch Workers

Query which tasks have all dependencies satisfied:

```bash
orca orchestration task-list --ready --brief
```

For each ready task, select the optimal agent from [agent-matrix.md](references/agent-matrix.md) (e.g. `codex` for implementation):

```bash
orca orchestration worker-start \
  --task <task_id> \
  --worktree new-child \
  --name "<short-task-name>" \
  --agent codex
```

*(Use `--worktree current` only when this coordinator session's worktree **is** the target repo. If the Cursor/Orca chat is open in another folder — e.g. the skills repo — `current` points at the wrong tree. Prefer an explicit selector: `--worktree path:/abs/path/to/target` or `id:<repo-id>::<path>`, and always pass `--run <run_id>` so reviews do not spawn a new Run.)*

### Step 4: End Turn (Reactive Wakeup Rule)

**Never poll `check`, loop, or sleep in bash.**
Once ready workers are dispatched, **end your turn immediately**. Orca will wake you when:
- A worker finishes and reports `worker_done`.
- A worker asks a clarifying question (`ask`).
- An escalation or permission prompt arises.

### Step 5: Handling Wake Events

When Orca wakes you with incoming messages:

1. **Worker Question (`question` / `ask`)**:
   - If the answer is clear from the spec, answer immediately:
     ```bash
     orca orchestration reply --id <message_id> --body "<answer>"
     ```
   - If the question reveals a critical design fork, create a Decision Gate (see below).

2. **Task Completion (`worker_done`)**:
   - Inspect the worker's changes and test results.
   - Dispatch a **Cross-Agent Task Reviewer** (Step 6).

3. **Escalations (`stopReason` / `exited`)**:
   - If a worker stopped without `worker_done`, steer it with `orca orchestration send` or restart it.

### Step 6: Cross-Agent Review

To avoid blind spots, dispatch a reviewer running on a **different agent engine** than the implementer (e.g., dispatch `claude` to review `codex`'s commit):

```bash
orca orchestration worker-start \
  --spec "Review task <task_id> diff against spec. Read-only review on current worktree." \
  --worktree current \
  --agent claude
```

- If review passes (`APPROVED`): Mark the task complete:
  ```bash
  orca orchestration task-update --task <task_id> --status completed
  ```
- If review finds issues: Send the findings back to the implementer via `orca orchestration send`.

### Step 7: Decision Gates for Human Blocks

If a task hits an ambiguity requiring human preference or a high-risk operation, **never block the whole coordinator or abort**:
Create an Orca Decision Gate:

```bash
orca orchestration gate-create \
  --task <task_id> \
  --question "Should we use Option A (fast) or Option B (durable)?" \
  --options '["Option A", "Option B"]'
```

Only `<task_id>` is blocked. Other independent ready tasks in the DAG continue executing!

---

## Completion & Teardown

When `orca orchestration task-list` shows all tasks completed:
1. Run full verification with `superpowers:verification-before-completion`.
2. Release worker terminal allocations:
   ```bash
   orca orchestration worker-release --terminal <handle>
   ```
3. Complete development branch with `superpowers:finishing-a-development-branch`.
