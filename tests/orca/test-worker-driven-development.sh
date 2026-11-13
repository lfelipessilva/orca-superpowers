#!/usr/bin/env bash
# Validate worker-driven-development skill: frontmatter, Orca orchestration loop,
# cross-agent matrix, spec templates, and reactive wakeups.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/worker-driven-development"
SKILL_FILE="$SKILL_DIR/SKILL.md"
MATRIX_FILE="$SKILL_DIR/references/agent-matrix.md"
TEMPLATE_FILE="$SKILL_DIR/templates/worker-spec-template.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-worker-driven-development: checking worker-driven-development skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"
[ -f "$MATRIX_FILE" ] || fail "agent-matrix.md missing at $MATRIX_FILE"
[ -f "$TEMPLATE_FILE" ] || fail "worker-spec-template.md missing at $TEMPLATE_FILE"

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

# --- Template checks --------------------------------------------------------
grep -q "worker_done" "$TEMPLATE_FILE" \
  || fail "worker-spec-template.md does not document reporting via worker_done"

echo "PASS: worker-driven-development skill and references are valid"
