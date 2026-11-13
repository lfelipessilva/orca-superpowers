# Orca-Native Superpowers (Orca-Superpowers) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork and transform Superpowers into an Orca-first autonomous engineering system where subagents are replaced by Orca Supervised Workers, tasks form Orca Orchestration DAGs, decision blocks use Orca Decision Gates (`gate-create`), and tasks/reviews leverage heterogeneous agents (Codex, Claude, Antigravity, Devin).

**Architecture:** Preserve the core engineering principles of Superpowers (TDD, brainstorming, systematic debugging, verification before completion). Replace the subagent-centric execution layer with an Orca Orchestration layer:
1. `using-orca-worktrees` replaces manual git worktree scripts with `orca worktree` and `--worktree new-child`.
2. `worker-driven-development` (WDD) replaces `subagent-driven-development` using `orca orchestration run-create`, `task-create --deps`, and `worker-start`.
3. `cross-agent-review` orchestrates reviewer workers from different agent families (e.g., Codex implements, Claude reviews).
4. `gate-create` is integrated as the primary non-blocking decision mechanism for human alignment.
5. Create an Orca tool mapping and bootstrap injector for seamless execution inside Orca.

**Tech Stack:** Bash, Markdown, Node.js, Orca CLI (`orca orchestration`, `orca worktree`, `orca agent`).

**Spec:** Integration specification based on Orca Orchestration primitives (`orca skills get orchestration`).

## Global Constraints

- Preserve all core development disciplines: TDD (`test-driven-development`), `brainstorming`, `systematic-debugging`, and `verification-before-completion` without degrading their strictness.
- Skills must remain declarative actions while mapping concrete executions to `orca orchestration` and `orca-cli`.
- Never poll `check` or terminals; rely entirely on Orca reactive wakeups (`worker_done`, `ask`, `escalation`).
- Zero manual `.worktrees/` directory hacking when running in Orca; use native `orca worktree` and `--worktree current|new-child`.
- Maintain MIT license and proper attribution to Jesse Vincent / `obra/superpowers`.

## Review Focus

1. **Context Pollution:** Workers must not inherit the coordinator's session history; their task spec must be self-contained in `worker-start --spec`.
2. **DAG Deadlocks:** Task dependencies in `task-create --deps` must be acyclic and handle failure/abort states without hanging the Run.
3. **Gate Non-blocking Behavior:** Gating task A (`gate-create`) must not block independent task B from starting or completing.
4. **Agent Compatibility:** Fallback behavior when a requested agent (e.g. `--agent codex` or `--agent claude`) is not configured in the host Orca account.
5. **Worktree Cleanup:** Child worktrees and worker terminals must be cleanly released via `worker-release` upon settling.

---

## Phase 1: Environment & Tool Mapping

### Task 1: Create Orca Tool Mapping and Discovery Reference

**Files:**
- Create: `skills/using-superpowers/references/orca-tools.md`
- Modify: `skills/using-superpowers/SKILL.md`
- Test: `tests/orca/test-tool-mapping.sh`

- [x] **Step 1: Write test to verify `orca-tools.md` exists and defines required action mappings**
  Create `tests/orca/test-tool-mapping.sh` asserting that `orca-tools.md` maps actions:
  - "Dispatch worker" -> `orca orchestration worker-start`
  - "Create task DAG" -> `orca orchestration task-create`
  - "Decision gate" -> `orca orchestration gate-create`
  - "Worktree management" -> `orca worktree`

- [x] **Step 2: Run test to verify failure**
  Run: `bash tests/orca/test-tool-mapping.sh`
  Expected: Fails because file does not exist.

- [x] **Step 3: Create `skills/using-superpowers/references/orca-tools.md`**
  Document the complete mapping table between Superpowers actions and Orca CLI commands.

- [x] **Step 4: Update `skills/using-superpowers/SKILL.md`**
  Reference `orca-tools.md` in the tool mapping resolution list.

- [x] **Step 5: Run test to verify pass**
  Run: `bash tests/orca/test-tool-mapping.sh`
  Expected: Passes with exit code 0.

- [x] **Step 6: Commit**
  ```bash
  git add skills/using-superpowers/references/orca-tools.md skills/using-superpowers/SKILL.md tests/orca/test-tool-mapping.sh
  git commit -m "feat(orca): add orca tool mapping reference and test"
  ```

---

## Phase 2: Orca Worktree Integration

### Task 2: Create `using-orca-worktrees` Skill

**Files:**
- Create: `skills/using-orca-worktrees/SKILL.md`
- Test: `tests/orca/test-using-orca-worktrees.sh`

- [x] **Step 1: Write test for `using-orca-worktrees` skill layout and content**
  Create `tests/orca/test-using-orca-worktrees.sh` checking frontmatter (name, description) and instructions for:
  - Detecting current worktree with `orca worktree current`
  - Creating isolated worktrees with `orca worktree create` or `--worktree new-child`
  - Setting status metadata with `orca worktree set --comment`
  - Cleanup with `orca worktree rm` / terminal release

- [x] **Step 2: Run test to verify failure**
  Run: `bash tests/orca/test-using-orca-worktrees.sh`
  Expected: Fails.

- [x] **Step 3: Implement `skills/using-orca-worktrees/SKILL.md`**
  Detail the detection protocol:
  1. Check `ORCA_CLI_COMMAND` or `orca status`.
  2. If in Orca, prefer `--worktree current` for single-agent tasks and `--worktree new-child --name <name>` for multi-agent/parallel tasks.
  3. Set worktree status notes: `orca worktree set --worktree active --comment "<phase>"`.
  4. Provide fallback to standard git worktrees only if running outside Orca.

- [x] **Step 4: Run test to verify pass**
  Run: `bash tests/orca/test-using-orca-worktrees.sh`
  Expected: Passes with exit code 0.

- [x] **Step 5: Commit**
  ```bash
  git add skills/using-orca-worktrees/ tests/orca/test-using-orca-worktrees.sh
  git commit -m "feat(orca): implement using-orca-worktrees skill"
  ```

---

## Phase 3: Worker-Driven Development (WDD)

### Task 3: Implement `worker-driven-development` Skill

**Files:**
- Create: `skills/worker-driven-development/SKILL.md`
- Create: `skills/worker-driven-development/references/agent-matrix.md`
- Create: `skills/worker-driven-development/templates/worker-spec-template.md`
- Test: `tests/orca/test-worker-driven-development.sh`

- [x] **Step 1: Write test for `worker-driven-development`**
  Create `tests/orca/test-worker-driven-development.sh` testing:
  - Frontmatter and required references.
  - Presence of Orca orchestration lifecycle (`run-create`, `task-create`, `worker-start`, `worker_done`, `ask`, `escalation`).
  - Cross-agent delegation rules.

- [x] **Step 2: Run test to verify failure**
  Run: `bash tests/orca/test-worker-driven-development.sh`
  Expected: Fails.

- [x] **Step 3: Create `skills/worker-driven-development/references/agent-matrix.md`**
  Define agent specializations and dispatch recommendations:
  - **Codex**: Fast code implementation, unit tests, shell commands (`--agent codex`).
  - **Claude**: Architectural critique, complex code review, spec ambiguity checking (`--agent claude`).
  - **Antigravity / Gemini**: Large codebase context, multimodality, broad refactoring (`--agent antigravity`).
  - **Devin**: Deep repo-level exploration and autonomous remediation (`--agent devin`).

- [x] **Step 4: Create `skills/worker-driven-development/templates/worker-spec-template.md`**
  Create self-contained task specification template:
  - Target files and constraints.
  - Test command and expected deliverable.
  - Instructions on how to report via `worker_done` or ask questions via `ask`.

- [x] **Step 5: Implement `skills/worker-driven-development/SKILL.md`**
  Write complete WDD lifecycle:
  1. `run-create --objective "<goal>"`
  2. `task-create --spec "<spec>" --deps <deps>`
  3. `task-list --ready`
  4. `worker-start --task <task_id> --agent <agent> --worktree new-child`
  5. End turn; wait for Orca wakeups.
  6. On wake: settle completed tasks, trigger review workers, dispatch next ready tasks.

- [x] **Step 6: Run test to verify pass**
  Run: `bash tests/orca/test-worker-driven-development.sh`
  Expected: Passes with exit code 0.

- [x] **Step 7: Commit**
  ```bash
  git add skills/worker-driven-development/ tests/orca/test-worker-driven-development.sh
  git commit -m "feat(orca): implement worker-driven-development skill with agent matrix"
  ```

---

## Phase 4: Decision Gates Integration

### Task 4: Implement Decision Gates Protocol (`orca-decision-gates`)

**Files:**
- Create: `skills/orca-decision-gates/SKILL.md`
- Test: `tests/orca/test-decision-gates.sh`

- [x] **Step 1: Write test for Decision Gates skill**
  Create `tests/orca/test-decision-gates.sh` checking:
  - Guidelines for when to create gates (destructive operations, external effects, spec ambiguities).
  - Exact command syntax for `orca orchestration gate-create` and `gate-resolve`.
  - Non-blocking execution rules for independent DAG tasks.

- [x] **Step 2: Run test to verify failure**
  Run: `bash tests/orca/test-decision-gates.sh`
  Expected: Fails.

- [x] **Step 3: Implement `skills/orca-decision-gates/SKILL.md`**
  Document:
  1. Gate criteria vs ruling criteria (when to rule autonomously vs when to gate).
  2. Creating a gate:
     `orca orchestration gate-create --task <task_id> --question "<question>" --options '["Option 1", "Option 2"]'`
  3. How independent tasks continue while the gated task waits.
  4. Resolving gates: `orca orchestration gate-resolve --gate <gate_id> --choice "<selected>"` or UI resolution.
  5. Reacting to gate resolution when Orca wakes the coordinator.

- [x] **Step 4: Run test to verify pass**
  Run: `bash tests/orca/test-decision-gates.sh`
  Expected: Passes with exit code 0.

- [x] **Step 5: Commit**
  ```bash
  git add skills/orca-decision-gates/ tests/orca/test-decision-gates.sh
  git commit -m "feat(orca): implement orca-decision-gates skill"
  ```

---

## Phase 5: Cross-Agent Code Review & Parallel Workers

### Task 5: Implement `cross-agent-review` and `dispatching-parallel-workers`

**Files:**
- Create: `skills/cross-agent-review/SKILL.md`
- Create: `skills/cross-agent-review/templates/review-worker-spec.md`
- Create: `skills/dispatching-parallel-workers/SKILL.md`
- Test: `tests/orca/test-cross-agent-review.sh`
- Test: `tests/orca/test-parallel-workers.sh`

- [x] **Step 1: Write tests for review and parallel worker skills**
  Create `tests/orca/test-cross-agent-review.sh` and `tests/orca/test-parallel-workers.sh`.

- [x] **Step 2: Run tests to verify failure**
  Run: `bash tests/orca/test-cross-agent-review.sh && bash tests/orca/test-parallel-workers.sh`
  Expected: Fails.

- [x] **Step 3: Implement `skills/cross-agent-review/SKILL.md`**
  Specify:
  - Heterogeneous pairing principle: Never have an agent review its own code when an alternative agent is available.
  - Dispatching a review worker on `--worktree current`:
    `orca orchestration worker-start --spec "<review_spec>" --worktree current --agent claude`
  - Read-only review constraints and structured feedback output.

- [x] **Step 4: Implement `skills/dispatching-parallel-workers/SKILL.md`**
  Specify:
  - Identifying independent failures or components.
  - Spawning parallel workers in child worktrees (`--worktree new-child --name <subsystem>`).
  - Settle & merge workflow upon wake.

- [x] **Step 5: Run tests to verify pass**
  Run: `bash tests/orca/test-cross-agent-review.sh && bash tests/orca/test-parallel-workers.sh`
  Expected: Passes with exit code 0.

- [x] **Step 6: Commit**
  ```bash
  git add skills/cross-agent-review/ skills/dispatching-parallel-workers/ tests/orca/
  git commit -m "feat(orca): implement cross-agent-review and dispatching-parallel-workers"
  ```

---

## Phase 6: Packaging, Documentation & Verification

### Task 6: Packaging as Orca Skill Pack and Updating Documentation

**Files:**
- Modify: `package.json`
- Modify: `README.md`
- Create: `docs/orca-integration-guide.md`
- Test: `tests/orca/run-all-orca-tests.sh`

- [x] **Step 1: Write `tests/orca/run-all-orca-tests.sh` to run the entire test suite**
  Include linting, skill frontmatter verification, and Orca workflow validation.

- [x] **Step 2: Update `package.json` metadata**
  Update name, description, keywords (`orca`, `orchestration`, `multi-agent`).

- [x] **Step 3: Write `docs/orca-integration-guide.md` and update `README.md`**
  Provide setup instructions, examples of running WDD with Codex and Claude, and gate handling.

- [x] **Step 4: Run full verification suite**
  Run: `bash tests/orca/run-all-orca-tests.sh`
  Expected: All Orca tests pass cleanly.

- [x] **Step 5: Final review and commit**
  ```bash
  git add package.json README.md docs/orca-integration-guide.md tests/orca/run-all-orca-tests.sh
  git commit -m "chore(orca): finalize packaging and documentation for orca-superpowers"
  ```
