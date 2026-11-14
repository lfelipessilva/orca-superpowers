#!/usr/bin/env bash
# Validate worker-driven-development skill: frontmatter, Orca orchestration loop,
# cross-agent matrix, spec templates, lean CLI scripts, and reactive wakeups.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/worker-driven-development"
SKILL_FILE="$SKILL_DIR/SKILL.md"
MATRIX_FILE="$SKILL_DIR/references/agent-matrix.md"
CATALOG_FILE="$SKILL_DIR/references/model-catalog.yaml"
TEMPLATE_FILE="$SKILL_DIR/templates/worker-spec-template.md"
WDD="$SKILL_DIR/scripts/wdd"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-worker-driven-development: checking worker-driven-development skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"
[ -f "$MATRIX_FILE" ] || fail "agent-matrix.md missing at $MATRIX_FILE"
[ -f "$CATALOG_FILE" ] || fail "model-catalog.yaml missing at $CATALOG_FILE"
[ -f "$TEMPLATE_FILE" ] || fail "worker-spec-template.md missing at $TEMPLATE_FILE"
[ -x "$WDD" ] || [ -f "$WDD" ] || fail "scripts/wdd missing"
for s in wdd-boot.sh list-model-catalog.sh refresh-model-catalog.sh agents-brief.sh ready-brief.sh workers-brief.sh; do
  [ -f "$SKILL_DIR/scripts/$s" ] || fail "missing skill script $s"
done

# --- Frontmatter checks -----------------------------------------------------
grep -q "^name: worker-driven-development" "$SKILL_FILE" \
  || fail "skill name is not 'worker-driven-development'"

grep -q "^description:" "$SKILL_FILE" \
  || fail "skill missing description frontmatter"

# --- Orca Orchestration Lifecycle commands ----------------------------------
for cmd in "run-create" "task-create" "worker-start" "worker_done" "task-list"; do
  grep -q "$cmd" "$SKILL_FILE" \
    || fail "SKILL.md does not document '$cmd'"
done

# --- Cross-agent references -------------------------------------------------
for agent in "codex" "claude" "antigravity"; do
  grep -qi "$agent" "$MATRIX_FILE" \
    || fail "agent-matrix.md does not document '$agent'"
done

# --- Model catalog + no-discovery rule --------------------------------------
grep -q "Dispatch without a discovery tour" "$SKILL_FILE" \
  || fail "SKILL.md must ban discovery tours before worker-start"
grep -q "model-catalog.yaml" "$SKILL_FILE" \
  || fail "SKILL.md must point at model-catalog.yaml"
for family in antigravity claude cursor opencode; do
  grep -q "^${family}:" "$CATALOG_FILE" \
    || fail "model-catalog.yaml missing family '$family'"
done
grep -q "orca models list" "$CATALOG_FILE" \
  || fail "catalog should document upstream orca models list wish"

# --- Lean coordinator + selective review + wdd CLI --------------------------
grep -q "Lean coordinator" "$SKILL_FILE" \
  || fail "SKILL.md must document Lean coordinator mode"
grep -q "one action" "$SKILL_FILE" \
  || fail "SKILL.md must require one action per wakeup then end turn"
grep -q "scripts/wdd" "$SKILL_FILE" \
  || fail "SKILL.md must point at scripts/wdd"
grep -q "Selective review" "$SKILL_FILE" \
  || fail "SKILL.md must document Selective review"
for class in wiring scaffold dense; do
  grep -q "$class" "$SKILL_FILE" \
    || fail "SKILL.md must define review class '$class'"
done
grep -q "Plan Task" "$TEMPLATE_FILE" \
  || fail "worker-spec-template.md must use plan-pointer specs"
grep -q "wdd agents" "$SKILL_FILE" \
  || fail "SKILL.md must prefer wdd agents over raw account list"

bash "$WDD" models --agent antigravity --ids-only | grep -q . \
  || fail "wdd models produced no ids"

FIXTURE="$SCRIPT_DIR/fixtures/wdd-boot-sample-plan.md"
[ -f "$FIXTURE" ] || fail "missing fixture $FIXTURE"
BOOT_OUT="$(bash "$WDD" boot --plan "$FIXTURE" --agent antigravity --model gemini-3.8-flash --effort medium --dry-run)"
echo "$BOOT_OUT" | grep -q "run-create" \
  || fail "wdd boot dry-run must show run-create"
echo "$BOOT_OUT" | grep -q "task-create" \
  || fail "wdd boot dry-run must show task-create"
echo "$BOOT_OUT" | grep -q "worker-start" \
  || fail "wdd boot dry-run must show worker-start for ready tasks"
echo "$BOOT_OUT" | grep -q "review=skip" \
  || fail "wdd boot dry-run must classify non-dense tasks as review=skip"
echo "$BOOT_OUT" | grep -q "review=cross" \
  || fail "wdd boot dry-run must classify dense tasks as review=cross"

# agents-brief should be tiny vs raw account list (when orca available)
if command -v orca >/dev/null 2>&1; then
  BRIEF="$(bash "$WDD" agents 2>/dev/null || true)"
  RAW_LEN="$(${ORCA_CLI_COMMAND:-orca} account list --json 2>/dev/null | wc -c | tr -d ' ')"
  BRIEF_LEN="$(printf '%s' "$BRIEF" | wc -c | tr -d ' ')"
  [[ -n "$BRIEF" ]] || fail "wdd agents produced empty output"
  # brief should be much smaller than raw json blob
  if [[ "$RAW_LEN" -gt 1000 && "$BRIEF_LEN" -ge "$RAW_LEN" ]]; then
    fail "wdd agents output not smaller than raw account list ($BRIEF_LEN >= $RAW_LEN)"
  fi
  echo "$BRIEF" | grep -qE 'antigravity|cursor|claude' \
    || fail "wdd agents should mention known agent families"
fi

# --- Template checks --------------------------------------------------------
grep -q "worker_done" "$TEMPLATE_FILE" \
  || fail "worker-spec-template.md does not document reporting via worker_done"

echo "PASS: worker-driven-development skill and references are valid"
