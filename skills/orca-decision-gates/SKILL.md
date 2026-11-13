---
name: orca-decision-gates
description: Use when human intervention, approval, or design choice is required during Orca orchestration to create non-blocking decision gates
---

# Orca Decision Gates

Use Orca's native decision gate system (`gate-create`, `gate-resolve`, `gate-list`) to pause specific blocked tasks while allowing independent tasks in the orchestration DAG to proceed unimpeded.

---

## Autonomous Rulings vs. Decision Gates

Superpowers maintains the rule: **Rulings, not stalls**. A running plan does not stall on every small ambiguity. However, when genuine human authority is required, use a Decision Gate instead of blocking the session or making a reckless guess.

| Situation | Action | Mechanism |
| :--- | :--- | :--- |
| **Code style, naming, local refactoring, minor trade-offs** | **Ruling** | Make the professional call autonomously, record the ruling in the ledger/log, and continue. |
| **Architectural forks with equal merit** | **Decision Gate** | `gate-create` with structured options for your human partner. |
| **Destructive or irreversible operations** (e.g. drop table, rm branch) | **Decision Gate** | `gate-create` asking for explicit approval before proceeding. |
| **External side-effects** (git push to main, npm publish, prod deploy) | **Decision Gate** | `gate-create` asking for release confirmation. |
| **Spec contradictions where every path is a guess** | **Decision Gate** | `gate-create` presenting the contradiction and proposed resolutions. |

---

## Non-Blocking DAG Behavior

The fundamental advantage of Orca Decision Gates is that they are **non-blocking** to the overall Run:

```text
[Task 1: Core Models] ───► [Task 2: Auth Flow (GATED)] ───► [Task 4: User Profile API]
                                   │
                                   ▼ (Blocked waiting for human choice)
[Task 3: Independent Billing Service] ───► [Task 5: Billing Tests]  (RUNS CONCURRENTLY!)
```

When Task 2 is gated:
1. Only Task 2 (and downstream dependents like Task 4) waits.
2. Independent tasks (like Task 3 and Task 5) continue to be dispatched and completed!
3. Your human partner sees the gate prominently in Orca's UI or terminal list.

---

## CLI Reference

### 1. Creating a Decision Gate

Attach the gate directly to the affected task:

```bash
orca orchestration gate-create \
  --task <task_id> \
  --question "<Clear description of the choice or approval needed>" \
  --options '["Option A: ...", "Option B: ..."]'
```

*Optionally include `--from <handle>` if dispatched by a worker.*

### 2. Listing Active Gates

To inspect pending gates in the current run:

```bash
orca orchestration gate-list
```

### 3. Resolving a Decision Gate

Gates are typically resolved directly by the user clicking an option in the Orca interface. They can also be resolved via CLI:

```bash
orca orchestration gate-resolve \
  --gate <gate_id> \
  --choice "<chosen_option>"
```

---

## Reactive Coordinator Behavior

When you create a decision gate:
1. Record the gate creation in your coordinator summary.
2. Check if other tasks in the DAG are ready:
   ```bash
   orca orchestration task-list --ready --brief
   ```
3. Dispatch any ready unblocked tasks.
4. **End your turn**. Do NOT poll `gate-list`.
5. Orca will wake the coordinator as soon as the gate is resolved.
6. Upon wake, inspect the chosen option and resume or unblock the gated task.
