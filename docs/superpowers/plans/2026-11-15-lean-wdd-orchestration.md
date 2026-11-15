# Lean WDD Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate `model-catalog.yaml` in favor of dynamic discovery and persistent defaults, fix agent flag incompatibilities (Antigravity `--model`, Cursor `--effort`), and provide atomic low-token lifecycle commands (`status`, `complete`, `check`, `review`, `config`) for WDD coordinators.

**Architecture:** A modular set of lean bash/python helper scripts wrapped by `skills/worker-driven-development/scripts/wdd`. Model and effort resolution is managed by a centralized hierarchy (CLI flags > Env vars > local `.wddrc` > global `~/.config/wdd/config.json` > smart defaults). All orchestration lifecycle actions sanitize agent flags before calling `orca orchestration`.

**Tech Stack:** Bash, Python 3, Orca CLI (`orca orchestration`).

**Spec:** [docs/superpowers/specs/2026-11-15-lean-wdd-orchestration-design.md](file:///Users/luisfelipe/orca/workspaces/skill/cabezon/docs/superpowers/specs/2026-11-15-lean-wdd-orchestration-design.md)

## Global Constraints
- Zero coordinator token burn on model discovery during standard runs.
- Do NOT touch external running sessions or modify files outside this workspace (`cabezon`).
- Output of all `wdd` commands must be strictly concise (1–6 lines) to preserve LLM context.
- All existing Orca test suites in `tests/orca/` must pass.

## Review Focus
1. Antigravity worker-start without `--model` must inject default model when `--effort` is passed.
2. Cursor worker-start must never receive the `--effort` flag (effort is encoded in model ID).
3. `task-update` must accept both `--task` and `--id` flags to prevent coordinator hallucinations.
4. Local project `.wddrc` configuration must override global user config and built-in defaults.
5. Dynamic query commands must degrade gracefully if local agent CLIs (`agy`, `agent`) are not installed.

---

### Task 1: Clean Removal of Static Catalog & Refresh Script

**WDD class:** scaffold

**Files:**
- Remove: `skills/worker-driven-development/references/model-catalog.yaml`
- Remove: `skills/worker-driven-development/scripts/refresh-model-catalog.sh`
- Remove: `scripts/list-model-catalog.sh`
- Remove: `scripts/refresh-model-catalog.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`

**Interfaces:**
- Consumes: none
- Produces: `wdd` without obsolete `refresh-models` command

- [ ] **Step 1: Write test verifying obsolete files and commands are cleanly handled**
- [ ] **Step 2: Run test to observe status**
- [ ] **Step 3: Remove catalog files, symlinks, and references in `wdd`**
- [ ] **Step 4: Verify `wdd help` runs without errors**
- [ ] **Step 5: Commit changes**

---

### Task 2: Configuration & Defaults Engine (`wdd-config.sh` & `wdd config`)

**WDD class:** scaffold

**Files:**
- Create: `skills/worker-driven-development/scripts/wdd-config.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-config.sh`

**Interfaces:**
- Consumes: environment variables, `.wddrc`, `~/.config/wdd/config.json`
- Produces: `wdd config [set|get|list]`, `resolve_agent_model`, `resolve_agent_effort`

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-config.sh`**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `wdd-config.sh` with resolution hierarchy and CLI commands**
- [ ] **Step 4: Wire `config` command into `skills/worker-driven-development/scripts/wdd`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 3: Dynamic On-Demand Model Query (`list-models.sh` & `wdd models`)

**WDD class:** wiring

**Files:**
- Create: `skills/worker-driven-development/scripts/list-models.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-models.sh`

**Interfaces:**
- Consumes: `agy models`, `agent models`, Orca SQLite cache, or built-in defaults
- Produces: `wdd models [--agent <name>] [--ids-only]`

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-models.sh`**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `list-models.sh` with fast dynamic query and brief fallback**
- [ ] **Step 4: Connect `wdd models` to `list-models.sh`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 4: Agent Flag Sanitization & Defaults in `wdd-boot.sh`

**WDD class:** dense

**Files:**
- Modify: `skills/worker-driven-development/scripts/wdd-boot.sh`
- Test: `tests/orca/test-wdd-boot.sh`

**Interfaces:**
- Consumes: `wdd-config.sh`
- Produces: sanitized `worker-start` invocation (Antigravity receives `--model`, Cursor strips `--effort`)

- [ ] **Step 1: Write failing test verifying Antigravity defaults model and Cursor strips effort**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Integrate `wdd-config.sh` into `wdd-boot.sh` with flag sanitization**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit changes**

---

### Task 5: Status Inspection Command (`wdd status`)

**WDD class:** wiring

**Files:**
- Create: `skills/worker-driven-development/scripts/status-brief.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-status.sh`

**Interfaces:**
- Consumes: `orca orchestration task-list`, `worker-list`, `inbox`
- Produces: `wdd status --run <run_id>` (<6 lines overview)

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-status.sh`**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `status-brief.sh` parsing tasks, active workers, and unread messages**
- [ ] **Step 4: Wire `wdd status` into `wdd`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 6: Safe Completion & Advancement Command (`wdd complete`)

**WDD class:** wiring

**Files:**
- Create: `skills/worker-driven-development/scripts/complete-brief.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-complete.sh`

**Interfaces:**
- Consumes: `orca orchestration task-update`, `wdd ready`, `wdd-config`
- Produces: `wdd complete --run <run_id> --task <task_id> [--result <msg>] [--start-next]`

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-complete.sh`**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `complete-brief.sh` accepting `--task` or `--id` and advancing**
- [ ] **Step 4: Wire `wdd complete` into `wdd`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 7: Brief Inbox Check Command (`wdd check`)

**WDD class:** wiring

**Files:**
- Create: `skills/worker-driven-development/scripts/check-brief.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-check.sh`

**Interfaces:**
- Consumes: `orca orchestration check`
- Produces: `wdd check --run <run_id>` (1-line parsed event)

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-check.sh`**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `check-brief.sh` to extract `[worker_done]` or `[ask]` cleanly**
- [ ] **Step 4: Wire `wdd check` into `wdd`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 8: Automated Cross-Agent Review Dispatch (`wdd review`)

**WDD class:** dense

**Files:**
- Create: `skills/worker-driven-development/scripts/review-brief.sh`
- Modify: `skills/worker-driven-development/scripts/wdd`
- Test: `tests/orca/test-wdd-review.sh`

**Interfaces:**
- Consumes: `wdd agents --ok-only`, `wdd-config.sh`
- Produces: `wdd review --run <run_id> --task <task_id> [--reviewer <agent>]`

- [ ] **Step 1: Write failing test in `tests/orca/test-wdd-review.sh`**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `review-brief.sh` with heterogeneous agent selection and sanitized spec**
- [ ] **Step 4: Wire `wdd review` into `wdd`**
- [ ] **Step 5: Run test to verify it passes**
- [ ] **Step 6: Commit changes**

---

### Task 9: Documentation and Test Suite Verification

**WDD class:** scaffold

**Files:**
- Modify: `skills/worker-driven-development/SKILL.md`
- Modify: `skills/using-superpowers/references/orca-tools.md`
- Modify: `tests/orca/test-worker-driven-development.sh`
- Modify: `tests/orca/run-all-orca-tests.sh`

**Interfaces:**
- Consumes: all implemented scripts
- Produces: updated documentation and clean green test suite

- [ ] **Step 1: Update `SKILL.md` and `orca-tools.md` documenting new commands and rules**
- [ ] **Step 2: Update `test-worker-driven-development.sh` to validate new architecture**
- [ ] **Step 3: Run full test suite `bash tests/orca/run-all-orca-tests.sh`**
- [ ] **Step 4: Commit changes**
