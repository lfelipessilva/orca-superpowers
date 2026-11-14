# Agent Specialization & Selection Matrix

Orca can supervise workers running across different agent engines. Choosing the right agent for each role maximizes speed, accuracy, and engineering rigor.

## The Cross-Agent Matrix

| Agent ID | Engine / Harness | Primary Strengths | Best Used For | Dispatch Flag |
| :--- | :--- | :--- | :--- | :--- |
| **`codex`** | OpenAI Codex CLI | Fast tool execution, precise code edits, rigorous test driving, shell fluency. | **Implementer**: Writing minimal code to pass tests, refactoring, script writing. | `--agent codex` |
| **`claude`** | Claude Code / Anthropic | Deep architectural reasoning, spec compliance nuance, code smell detection, security. | **Reviewer**: Task reviews, security audits, holistic whole-branch review. | `--agent claude` |
| **`antigravity`** | Google Antigravity (Gemini) | Deep reasoning, massive context analysis, complex multimodal integration, cross-repo awareness. | **Coordinator / Architect**: Managing DAGs, drafting specs, resolving complex conflicts. | `--agent antigravity` |
| **`devin`** | Devin / Cognition | Long-horizon exploration, tracing complex multi-system bugs, environment setup. | **Debugger**: Deep root-cause isolation, non-deterministic flake investigation. | `--agent devin` |
| **`opencode`** | OpenCode Runtime | Open-weights / local models, offline execution, specialized fine-tuned models. | **Local / Offline Tasks**: Repetitive mechanical transforms, air-gapped tasks. | `--agent opencode` |

---

## The Cross-Agent Review Principle

> **Never let an agent review its own work if an alternative agent is available.**

When the implementer is **`codex`**, dispatch the review task to **`claude`** (or **`antigravity`**).
When the implementer is **`claude`**, dispatch the review task to **`codex`** or **`antigravity`**.

Cross-agent evaluation eliminates family-specific cognitive blind spots (e.g. models sharing training data peculiarities or systematic hallucination patterns).

---

## Model catalog (edit this, don't probe CLIs)

Opaque `--model` / `--effort` ids for **antigravity**, **claude**, **cursor**, and **opencode** live in [model-catalog.yaml](model-catalog.yaml).

- Edit the YAML by hand, or: `bash scripts/wdd refresh-models`
- Low-token list: `bash scripts/wdd models [--agent NAME] [--ids-only]`
- Auth map: `bash scripts/wdd agents [--ok-only]`
- Upstream wish: `orca models list --agent <id> --ids-only` (not shipped — catalog + `wdd` are the stand-in)

| Agent | How to pass model |
| :--- | :--- |
| **antigravity** | `--model gemini-3.8-flash --effort medium` (or compound `gemini-3.8-flash-medium`) |
| **claude** | `--model sonnet\|opus\|claude-sonnet-4-6` + optional `--effort` |
| **cursor** | `--model <id>` only (effort usually baked into the id, e.g. `-high`, `-fast`) |
| **opencode** | `--model opencode/beam-free` (+ `--effort` when the host accepts it) |

## Agent Fallback Hierarchy

If a target agent is not authenticated on the host machine (at most one `orca account list --json`):
1. Fall back to the active coordinator's agent engine.
2. If changing models within the same agent, pick ids from `model-catalog.yaml` / `defaults.effort` — do not run provider CLIs to rediscover them.
