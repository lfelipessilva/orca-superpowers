# Lean WDD Orchestration & Dynamic Defaults System Design

- **Date:** 2026-11-15
- **Author:** Antigravity / Luis Felipe
- **Topic:** Worker-Driven Development (WDD) lean orchestration improvements, model-catalog removal, dynamic configuration, and robust lifecycle management.

---

## 1. Intent & The Why

Coordinators executing multi-step implementation plans (e.g., 20+ tasks in a monorepo migration) using Orca's Worker-Driven Development (WDD) need to operate with minimal token consumption and zero friction.

In practice, several issues arose:
1. **Catalog Token Bleed & Stale Data:** The static `model-catalog.yaml` (360 lines, ~2,500 tokens) was frequently read in full by LLM coordinators whenever model ambiguity occurred. Furthermore, static catalogs go stale as providers rapidly update model IDs.
2. **Model/Effort Incompatibilities:** 
   - Antigravity requires a `--model` when `--effort` is passed; omitting `--model` caused `worker-start` to fail on task 1.
   - Cursor rejects `--effort` because effort is baked into model IDs (e.g., `composer-2.5-fast`); passing `--effort high` caused cross-review dispatch to fail.
3. **CLI Flag Hallucinations:** Coordinators frequently hallucinated `orca orchestration task-update --task <id>` instead of `--id <id>`, causing failed turns.
4. **Status Blindness:** When the human asked "is task X actually running?", the coordinator lacked a single status command and had to piece together information using manual python one-liners, terminal searches, and git logs.
5. **Manual Advancement Burden:** Checking messages, parsing payloads, completing tasks, and starting review workers required multiple verbose, error-prone manual steps.

This design eliminates `model-catalog.yaml`, establishes an intelligent defaults and configuration engine, and provides high-signal, low-token lifecycle commands.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- **Zero Token Model Discovery:** Coordinators should not need to discover or specify models for standard workflows; scripts resolve smart defaults automatically.
- **Configurable Defaults (Task vs Permanent):** Support task-level overrides (`--model <id>`), project-level config (`.wddrc`), and user-level persistent config (`~/.config/wdd/config.json`) via `wdd config set ...`.
- **Dynamic On-Demand Query:** `wdd models --agent <name>` queries local CLI / Orca DB dynamically, returning only raw IDs (10–30 tokens total) on demand.
- **Agent-Aware Flag Safety:** Automatically enforce required flags (e.g., ensure `--model` is set when `--effort` is passed to Antigravity) and strip unsupported flags (e.g., suppress `--effort` for Cursor).
- **Atomic Lifecycle Helpers:**
  - `wdd status --run <run_id>`: 5-line summary of run progress, active workers, unread message payloads, and ready tasks.
  - `wdd complete --run <run_id> --task <task_id> [--result <msg>] [--start-next]`: wraps `task-update --id` safely and optionally advances.
  - `wdd check --run <run_id>`: parses inbox messages into a 1-line payload summary.
  - `wdd review --run <run_id> --task <task_id> [--reviewer <agent>]`: dispatches a cross-agent review worker with safe model/effort settings.
- **Workspace Isolation:** All changes remain strictly inside the local repository (`cabezon`), preserving active running sessions.

### Non-Goals
- Modifying the external Orca daemon, RPC protocols, or SQLite schema.
- Building a complex database or background service for configuration.

### Anti-Goals
- Outputting large JSON blobs, formatted tables, or long explanations that burn coordinator tokens.
- Forcing coordinators into multi-turn discovery steps before launching tasks.

---

## 3. Approaches Considered

### Approach A: Smart Defaults + Configuration Engine + Dynamic On-Demand Query + Lifecycle Helpers *(Chosen)*
- Remove static `model-catalog.yaml` and `refresh-model-catalog.sh`.
- Scripts resolve models via a 5-tier hierarchy: CLI Flag > Env Var > Local Config (`.wddrc`) > Global Config (`~/.config/wdd/config.json`) > Built-in Smart Fallback.
- Dynamic `wdd models` queries local CLIs on demand.
- Helper scripts handle flag safety (effort stripping for Cursor, model defaulting for Antigravity) and wrap Orca CLI lifecycle operations.
- *Trade-off:* Requires implementing configuration storage and lifecycle wrappers, but completely eliminates coordinator errors and token waste.

### Approach B: Dynamic Discovery Only (No Script Defaults) *(Rejected)*
- Coordinator queries `wdd models` before every dispatch.
- *Trade-off:* Burns 1 extra turn and ~50–100 tokens per task, plus risks coordinator flag mistakes.

### Approach C: Minimal Hardcoded Table Only *(Rejected)*
- Hardcode 2 models per agent inside scripts without dynamic lookup or configuration persistence.
- *Trade-off:* Does not fulfill user requirement to customize defaults permanently or per-task.

---

## 4. Detailed Architecture & Design

### 4.1 Configuration & Model Resolution Hierarchy

When a worker is started (`wdd boot`, `wdd worker-start`, `wdd review`), the script resolves model and effort settings using the following precedence:

1. **Explicit CLI flags:** `--model <id>` and `--effort <level>`.
2. **Environment variables:** `WDD_MODEL_<AGENT>` and `WDD_EFFORT_<AGENT>`.
3. **Local Project Config:** `./.wddrc` (JSON or key-value format in current repository root).
4. **Global User Config:** `~/.config/wdd/config.json`.
5. **Built-in Smart Fallbacks:**
   - `antigravity`: model `gemini-3.8-flash`, effort allowed (`low`, `medium`, `high`).
   - `cursor`: model `composer-2.5-fast`, effort flag **stripped** (`effort_in_id: true`).
   - `claude`: model `sonnet`, effort allowed.
   - `codex`: model `gpt-5.3-codex`, effort allowed.
   - `opencode`: model `auto`, effort allowed if supported.

### 4.2 `wdd config` Subcommand

A dedicated configuration helper allows reading and updating defaults permanently or locally:
```bash
wdd config set <agent>.model <model_id> [--global | --local]
wdd config set <agent>.effort <level> [--global | --local]
wdd config get <agent>
wdd config list
```
- `--local` writes to `./.wddrc`.
- `--global` (default) writes to `~/.config/wdd/config.json`.

### 4.3 Agent Flag Sanitization Engine

Before calling `orca orchestration worker-start`:
- If `agent == "antigravity"`:
  - If `--effort` is specified but `--model` is missing, inject the resolved default model (e.g., `gemini-3.8-flash`).
- If `agent == "cursor"`:
  - Strip `--effort` flag completely (Cursor requires effort to be part of the model ID).
  - If model is `composer-2.5` and high effort is desired, map to `composer-2.5-fast` or the appropriate model ID.
- If `--effort` is passed, validate it matches `low | medium | high` (or class hint defaults: wiring -> low, scaffold -> medium, dense -> high).

### 4.4 Dynamic `wdd models` Helper

Replaces the catalog parser:
- `wdd models [--agent <name>] [--ids-only]`
  - For `antigravity`: queries `agy models 2>/dev/null | awk '{print $1}'`.
  - For `cursor`: queries `agent models 2>/dev/null | awk 'NR>2 && NF{print $1}' | head -15`.
  - Fallback / Orca DB: queries `~/Library/Application Support/orca/agent-model-catalog.db` if available.
  - Offline fallback: outputs the configured default and top known aliases for that agent.
  - Formats output as raw IDs (or brief 1-line notes), strictly capped to prevent token bloat.

### 4.5 Orchestration Lifecycle Commands in `wdd`

#### `wdd status --run <run_id>`
Prints an ultra-compact status snapshot (<6 lines):
```text
Run: run_b25869e4bef5 [4/22 tasks completed]
Active: ctx_46f97d390dae (antigravity/gemini-3.8-flash) on T4: Accounts API (running)
Inbox: 1 unread: worker_done ctx_46f97d390dae on T4 (outcome=succeeded)
Ready: T5 [dense] Archetypes + baits API
```

#### `wdd complete --run <run_id> --task <task_id> [--result <msg>] [--start-next]`
- Calls `orca orchestration task-update --run <run_id> --id <task_id> --status completed [--result <msg>]`.
- If `--start-next` is supplied:
  - Inspects newly ready tasks via `wdd ready --run <run_id>`.
  - If a task is ready, inspects its class (`wiring`, `scaffold`, `dense`).
  - Launches the worker using `wdd-boot`'s resolution engine.

#### `wdd check --run <run_id>`
- Calls `orca orchestration check --run <run_id>` and extracts the essential event into 1 line:
  `[worker_done] task=task_aa317c5f8980 dispatch=ctx_5cf5176e0772 outcome=succeeded`
  or
  `[ask] message_id=... from=... question="..."`

#### `wdd review --run <run_id> --task <task_id> [--reviewer <agent>]`
- Automatically identifies the implementer's agent family.
- Selects an available alternative agent from `wdd agents --ok-only` (e.g., if implementer was Antigravity, select Cursor or Claude).
- Resolves safe model/effort for the reviewer.
- Creates the review task in the run (if not already created) and starts the review worker with a standardized, plan-referenced review prompt.

---

## 5. What is Left to the Builder

- Implementing the python/bash helper scripts under `skills/worker-driven-development/scripts/`.
- Removing `model-catalog.yaml` and `refresh-model-catalog.sh`.
- Updating root `scripts/` symlinks.
- Updating `SKILL.md` and reference docs.
- Updating and expanding tests in `tests/orca/` to verify config persistence, flag sanitization, status output, and lifecycle commands.
