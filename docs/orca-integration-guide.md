# Orca-Superpowers Integration & User Guide

`superpowers-orca` is an Orca-first fork of Jesse Vincent's Superpowers framework. It preserves all battle-tested engineering disciplines (TDD, brainstorming before coding, systematic debugging, verification before completion) while replacing generic single-harness subagents with **Orca Orchestrated Workers**, **Task DAGs**, **Decision Gates**, and **Heterogeneous Multi-Agent Teams**.

---

## Key Enhancements over Standard Superpowers

| Feature | Standard Superpowers | Superpowers-Orca |
|---|---|---|
| **Execution Engine** | In-process subagent tools | **Orca Supervised Workers** with dedicated UI tabs & terminals |
| **Agent Heterogeneity** | Single model family (varying cost tiers) | **Cross-Agent Teams** (e.g. Codex implements, Claude reviews, Antigravity coordinates) |
| **Task Management** | Scratchpad ledger markdown (`progress.md`) | **Orca DAG**: `run-create`, `task-create --deps`, `task-list --ready` |
| **Human Blockers** | Entire session pauses or coordinator guesses | **Orca Decision Gates**: `gate-create` blocks only the gated task; independent tasks keep executing |
| **Workspace Isolation** | Manual `git worktree add .worktrees/...` | **Native Orca Worktrees**: `--worktree new-child`, UI status comments, issue links |
| **Reactivity** | Turn-based polling or sleep loops | **Event Wakeups**: Coordinator sleeps until `worker_done`, `ask`, or gate resolution |

---

## The New Orca Skills

### 1. `worker-driven-development` (`superpowers:worker-driven-development`)
Replaces `subagent-driven-development`. Coordinates the end-to-end execution of implementation plans:
```bash
# 1. Initialize run
orca orchestration run-create --objective "Implement user management API"

# 2. Register DAG tasks
orca orchestration task-create --spec "Task 1: User model and DB migration"
orca orchestration task-create --spec "Task 2: Auth endpoints" --deps '["task_1"]'

# 3. Dispatch ready workers to the best matching agent
orca orchestration worker-start --task <task_id> --worktree new-child --name "task-1" --agent codex
```

### 2. `orca-decision-gates` (`superpowers:orca-decision-gates`)
When an architectural ambiguity, security permission, or high-risk choice requires human input:
```bash
orca orchestration gate-create \
  --task <task_id> \
  --question "Select token storage mechanism" \
  --options '["HTTP-only cookies (recommended)", "Bearer auth in local storage"]'
```
*Independent tasks in the DAG continue running concurrently while this task waits for human resolution.*

### 3. `cross-agent-review` (`superpowers:cross-agent-review`)
Eliminates model family bias by enforcing that code is reviewed by a different agent family:
- Implementer: **Codex**
- Reviewer: **Claude**
```bash
orca orchestration worker-start \
  --spec "Read-only review of commits [BASE]..[HEAD] against plan spec" \
  --worktree current \
  --agent claude
```

### 4. `using-orca-worktrees` (`superpowers:using-orca-worktrees`)
Manages clean workspace isolation using native Orca primitives:
- Active worktree inspection: `orca worktree current`
- Setting status comments: `orca worktree set --worktree active --comment "TDD: Red phase"`
- Isolated child worktrees: `--worktree new-child --name <domain>`

### 5. `dispatching-parallel-workers` (`superpowers:dispatching-parallel-workers`)
Dispatches parallel workers across isolated child worktrees for decoupled bugs or independent domains without git lock conflicts.

---

## Agent Matchmaking Matrix

| Role | Recommended Agent | Why |
|---|---|---|
| **Coordinator / Architect** | `antigravity` / `claude` | High-context reasoning, global constraints enforcement, plan drafting. |
| **Implementer** | `codex` | Lightning-fast code generation, tight test iteration, shell fluency. |
| **Code Reviewer** | `claude` | Deep edge-case detection, spec fidelity, security analysis. |
| **Deep Debugger** | `devin` | Autonomous exploration of multi-file legacy bugs and non-deterministic flakes. |

---

## Verifying the Test Suite

Run all Orca skill tests locally:
```bash
npm run test:orca
```
