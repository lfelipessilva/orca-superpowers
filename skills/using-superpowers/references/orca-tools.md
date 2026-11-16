# Orca Orchestration Tool Mapping

Skills speak in declarative actions ("dispatch a subagent", "create a todo", "read a file", "request code review"). In the Orca runtime environment, these resolve to the native Orca CLI commands and orchestration primitives below.

## Hard rule: workers, not harness subagents

When Orca is available (`command -v orca` and a usable worktree), **never** use
the host harness's Task / Explore / `invoke_subagent` / in-process subagent tools
for plan execution, review, parallel fixes, or agent discovery.

| Temptation | Do this instead |
|------------|-----------------|
| Cursor Task / Explore "is antigravity a model?" | `--agent antigravity` + `bash ~/.agents/skills/worker-driven-development/scripts/wdd models` |
| "What models exist?" / `agy` / `agent models` / `agent-context` | `wdd models --ids-only` (dynamic low-token query; or `wdd config set ...`) |
| Raw `orca account list --json` | `wdd agents` or `wdd agents --ok-only` |
| Human already named agent/model/effort | `wdd boot` / `worker-start` with **zero** discovery commands |
| Hand-rolling run + tasks + first workers | `wdd boot --plan <plan.md> --agent <id> […]` then end turn |
| Is task X running / run status | `wdd status --run <run_id>` (<6 lines overview) |
| Wakeup bookkeeping | `wdd check --run <run_id>` + `wdd complete --run … --start-next` |
| Review on dense tasks | `wdd review --run <run_id> --task <id>` (automated heterogeneous review) |
| Who is ready / worker state | `wdd ready --run …` / `wdd workers --run …` |
| Review every task | Selective: cross-agent only for WDD class `dense`; skip wiring/scaffold |
| Coordinator essays / re-read plan each wake | Lean coordinator: one action → end turn |
| `subagent-driven-development` after a plan | `worker-driven-development` (`wdd boot` or manual DAG) |
| `dispatching-parallel-agents` | `dispatching-parallel-workers` (`--worktree new-child`) |
| `requesting-code-review` subagent | `cross-agent-review` via `wdd review` or `worker-start --agent <other-family>` |
| `--worktree current` while chat is in another repo | Explicit `--worktree path:/abs/target` (or `id:…`) **and** `--run <run_id>` |
| Polling `worker-show` / sleep loops | End turn; Orca wakes on `worker_done` / `ask` / gate resolve |

Antigravity is an Orca `--agent` id, not a Cursor Task model slug. Grok on Cursor
workers is `--agent cursor --model <provider-model-id>`.

**Upstream wish:** `orca models list --agent <id> --ids-only` (one line per id, no account/rate-limit blob). Until Orca ships it, dynamic CLI queries (`list-models.sh`) and `wdd-config.sh` smart defaults are the brief path.

## Action Mapping Table

Prefer the low-token `wdd` helpers (`~/.agents/skills/worker-driven-development/scripts/wdd`) over raw dumps:

| Action skills request | WDD helper (preferred) | Native Orca primitive |
|-----------------------|------------------------|-----------------------|
| Dispatch implementer / worker | `wdd boot --plan <plan> --agent <agent>` or `wdd complete --run <id> --task <id> --start-next` | `orca orchestration worker-start --spec "<spec>" --worktree current\|new-child --agent <agent>` |
| Track tasks & plan dependencies | `wdd boot --plan <plan> --agent <agent>` or `wdd task-list --run <run_id>` | `orca orchestration run-create --objective "<goal>"` followed by `orca orchestration task-create --spec "<task>" [--deps '<json_array>']` |
| Check ready tasks in DAG | `wdd ready --run <run_id>` | `orca orchestration task-list --ready --brief` |
| Parallel dispatch | `wdd workers --run <run_id>` | `orca orchestration worker-start --spec "<spec>" --worktree new-child --name <domain> --agent <agent>` |
| Request code review (cross-agent) | `wdd review --run <run_id> --task <task_id>` | `orca orchestration worker-start --spec "<review_spec>" --worktree current --agent <reviewer_agent>` |
| Human clarification / Permission gate | `wdd gate create --task <task_id> --question "<text>" [--options '<json_array>']` | `orca orchestration gate-create --task <task_id> --question "<text>" [--options '<json_array>']` |
| Resolve decision gate | `wdd gate resolve --id <gate_id> --resolution "<selected>"` | `orca orchestration gate-resolve --id <gate_id> --resolution "<selected>"` |
| Steer or message a worker | `wdd send --run <run_id> --to dispatch:<dispatch_id> --subject "<topic>" --body "<message>"` | `orca orchestration send --to dispatch:<dispatch_id> --subject "<topic>" --body "<message>"` |
| Answer a worker's question | `wdd reply --id <message_id> --body "<answer>"` | `orca orchestration reply --id <message_id> --body "<answer>"` |
| Inspect worker output / status | `wdd status --run <run_id>` / `wdd read --dispatch <id>` / `wdd show --dispatch <id>` | `orca orchestration worker-show` / `worker-read` |
| Worktree isolation | `orca worktree create` or `--worktree new-child --name <short-name>` | `orca worktree create` |
| Worktree metadata & comments | `orca worktree set --worktree active --comment "<phase/status>"` | `orca worktree set` |
| Release settled worker resources | `wdd release --dispatch <dispatch_id>` | `orca orchestration worker-release --terminal <handle>` |

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
   wdd gate create --task <task_id> --question "<question>" --options '["Option A", "Option B"]'
   ```
2. Any independent tasks in the DAG continue executing without interruption.
3. The human partner can resolve the gate via Orca's UI or via `wdd gate resolve --id <gate_id> --resolution "<selected>"`.
4. Orca automatically wakes the coordinator when the gate is resolved.

## Reactive Wakeup Rule

Never poll `orca orchestration check` or run sleep loops. When workers are started or gates are created:
1. Complete any immediate coordinator bookkeeping.
2. **End your turn** (make no further tool calls).
3. Orca will automatically wake the coordinator when:
   - A worker reports `worker_done`.
   - A worker asks a question (`ask`).
   - An escalation or gate resolution occurs.
