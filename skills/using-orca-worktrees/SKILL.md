---
name: using-orca-worktrees
description: Use when starting feature work or multi-agent execution in Orca to ensure clean workspace isolation using native Orca child worktrees
---

# Using Orca Worktrees

Ensure multi-agent and feature work happens in clean, isolated workspaces using Orca's native worktree management.

**Core principle:** Never use ad-hoc `git worktree add .worktrees/...` commands when running in Orca. Native Orca worktrees provide UI visibility, terminal bindings, issue tracking integration, and automatic cleanup.

**Announce at start:** "I'm using the using-orca-worktrees skill to prepare an isolated workspace."

---

## Step 0: Detect Orca Runtime

Determine whether you are running inside an Orca-managed session:

```bash
# 1. Check for Orca CLI
if command -v orca >/dev/null 2>&1 || [ -n "${ORCA_CLI_COMMAND:-}" ]; then
  ORCA="${ORCA_CLI_COMMAND:-orca}"
else
  ORCA=""
fi
```

- **If Orca is NOT available (Fallback):** Fall back immediately to the standard `superpowers:using-git-worktrees` skill.
- **If Orca is available:** Continue to Step 1.

---

## Step 1: Detect Current Worktree Status

Run:

```bash
orca worktree current
```

- If already running in a dedicated feature worktree or child worktree:
  - Note the active worktree path and branch.
  - Set a helpful status comment:
    ```bash
    orca worktree set --worktree active --comment "Superpowers: Starting task execution"
    ```
  - Proceed directly to work without creating another top-level worktree.

---

## Step 2: Workspace Isolation Strategy for Workers

When coordinating multi-agent tasks, choose the right worktree option:

| Scenario | Worktree Flag | Rationale |
|----------|---------------|-----------|
| **Single-agent in-place work** | `--worktree current` | The worker operates directly in your current workspace when no concurrent edits happen. |
| **Concurrent tasks / Sub-workers** | `--worktree new-child --name <task-name>` | Creates an isolated nested worktree. No file edit collisions, dedicated terminal in Orca UI. |
| **New standalone project branch** | `orca worktree create --name <branch> --agent <agent>` | Standalone branch for major feature work independent of coordinator. |

### Creating a Child Worktree for Supervised Workers

When dispatching an Orca worker with task isolation:

```bash
$ORCA orchestration worker-start \
  --task <task_id> \
  --worktree new-child \
  --name "<short-task-name>" \
  --agent <agent_id>
```

Orca automatically:
1. Provisions the child worktree directory under Orca's managed workspace structure.
2. Checks out the appropriate branch or detached HEAD.
3. Launches the worker terminal/chat session visibly in the Orca interface.

---

## Step 3: Tracking Status with Worktree Comments

Keep the user informed via the Orca sidebar by updating comments during phase transitions:

```bash
# Example transitions:
$ORCA worktree set --worktree active --comment "TDD: Writing failing tests"
$ORCA worktree set --worktree active --comment "Implementing minimal code"
$ORCA worktree set --worktree active --comment "Verification & Review"
```

If the workspace is linked to Linear or GitLab issues, Orca displays the comment alongside the issue context.

---

## Step 4: Finishing & Resource Cleanup

When an isolated worker finishes:
1. Verify the worker reported `worker_done`.
2. Inspect the worker's changes and merge back if working from a child branch:
   ```bash
   git merge <child-branch-or-sha>
   ```
3. Release the worker's terminal and worktree accounting:
   ```bash
   $ORCA orchestration worker-release --terminal <terminal_handle>
   ```
4. If a child worktree is no longer needed:
   Orca automatically cleans child worktrees whose tasks have settled.

---

## Summary Checklist

- [ ] Check Orca environment (`$ORCA worktree current`).
- [ ] Fall back to git worktrees if Orca is not available.
- [ ] Use `--worktree new-child` for parallel or risk-isolated tasks.
- [ ] Keep Orca UI updated with `$ORCA worktree set --worktree active --comment "..."`.
- [ ] Release finished worker terminals cleanly via `worker-release`.
