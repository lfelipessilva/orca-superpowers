# Orca Orchestration Tool Mapping

Skills speak in declarative actions ("dispatch a subagent", "create a todo", "read a file", "request code review"). In the Orca runtime environment, these resolve to the native Orca CLI commands and orchestration primitives below.

## Hard rule: workers, not harness subagents

When Orca is available (`command -v orca` and a usable worktree), **never** use
the host harness's Task / Explore / `invoke_subagent` / in-process subagent tools
for plan execution, review, parallel fixes, or agent discovery.

| Temptation | Do this instead |
|------------|-----------------|
| Cursor Task / Explore "is antigravity a model?" | `orca account list`; `orca orchestration worker-start --help`; `--agent antigravity` |
| `subagent-driven-development` after a plan | `worker-driven-development` (`run-create` → `task-create` → `worker-start`) |
| `dispatching-parallel-agents` | `dispatching-parallel-workers` (`--worktree new-child`) |
| `requesting-code-review` subagent | `cross-agent-review` via `worker-start --agent <other-family>` |
| `--worktree current` while chat is in another repo | Explicit `--worktree path:/abs/target` (or `id:…`) **and** `--run <run_id>` |
| Polling `worker-show` / sleep loops | End turn; Orca wakes on `worker_done` / `ask` / gate resolve |

Antigravity is an Orca `--agent` id, not a Cursor Task model slug. Grok on Cursor
workers is `--agent cursor --model <provider-model-id>`.

## Action Mapping Table

| Action skills request | Orca equivalent |
|-----------------------|-----------------|
| Dispatch implementer / worker | `orca orchestration worker-start --spec "<spec>" --worktree current\|new-child --agent <agent>` |
| Track tasks & plan dependencies | `orca orchestration run-create --objective "<goal>"` followed by `orca orchestration task-create --spec "<task>" [--deps '<json_array>']` |
| Check ready tasks in DAG | `orca orchestration task-list --ready --brief` |
| Parallel dispatch | `orca orchestration worker-start --spec "<spec>" --worktree new-child --name <domain> --agent <agent>` |
| Request code review (cross-agent) | `orca orchestration worker-start --spec "<review_spec>" --worktree current --agent <reviewer_agent>` |
| Human clarification / Permission gate | `orca orchestration gate-create --task <task_id> --question "<text>" [--options '<json_array>']` |
| Resolve decision gate | `orca orchestration gate-resolve --gate <gate_id> --choice "<selected>"` (or via Orca UI) |
| Steer or message a worker | `orca orchestration send --to dispatch:<dispatch_id> --subject "<topic>" --body "<message>"` |
| Answer a worker's question | `orca orchestration reply --id <message_id> --body "<answer>"` |
| Worktree isolation | `orca worktree create` or `--worktree new-child --name <short-name>` |
| Worktree metadata & comments | `orca worktree set --worktree active --comment "<phase/status>"` |
| Release settled worker resources | `orca orchestration worker-release --terminal <handle>` |

## Cross-Agent Support

Orca supports heterogeneous agent runtimes on the same machine or remote hosts:
- **`codex`**: High-speed code implementation, precise refactorings, test generation, shell tasks.
- **`claude`**: Deep architectural reasoning, spec compliance review, subtle concurrency or edge-case detection.
- **`antigravity`**: Wide codebase context, complex multimodality, cross-project analysis.
- **`devin`**: Autonomous long-horizon repository debugging and investigation.

Specify `--agent <id>` explicitly on `worker-start` to match the best agent to the task.

## Decision Gates (`gate-create`)

When an implementation task encounters an ambiguity, architectural fork, or requires human consent for sensitive operations, **do not stall the entire session**.
1. Create a decision gate tied to that specific task:
   ```bash
   orca orchestration gate-create --task <task_id> --question "<question>" --options '["Option A", "Option B"]'
   ```
2. Any independent tasks in the DAG continue executing without interruption.
3. The human partner can resolve the gate via Orca's UI or via `orca orchestration gate-resolve`.
4. Orca automatically wakes the coordinator when the gate is resolved.

## Reactive Wakeup Rule

Never poll `orca orchestration check` or run sleep loops. When workers are started or gates are created:
1. Complete any immediate coordinator bookkeeping.
2. **End your turn** (make no further tool calls).
3. Orca will automatically wake the coordinator when:
   - A worker reports `worker_done`.
   - A worker asks a question (`ask`).
   - An escalation or gate resolution occurs.
