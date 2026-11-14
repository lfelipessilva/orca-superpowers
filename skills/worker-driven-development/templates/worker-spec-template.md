# Supervised Worker Spec (lean / plan-pointer)

Prefer short specs. Do **not** paste the whole plan into `--spec`.

```markdown
## Task Objective
Implement Plan Task N: <title from plan>

## Plan
<path/to/plan.md> — read **only** the section `### Task N: …` (and its Interfaces).

## WDD class
wiring | scaffold | dense

## Review policy
skip | cross

## Target Files
(from the plan task's Files block)

## Verification
(from the plan task's run/expected steps)

## Done
Working tree clean, tests pass → `worker_done` with verification evidence.
Blocking question → `ask`.
```
