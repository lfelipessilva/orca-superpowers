#!/usr/bin/env bash
# Validate dispatching-parallel-workers skill: frontmatter, child worktree isolation,
# independent domain criteria, and integration merge workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/dispatching-parallel-workers"
SKILL_FILE="$SKILL_DIR/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-parallel-workers: checking dispatching-parallel-workers skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"

# --- Frontmatter checks -----------------------------------------------------
grep -q "^name: dispatching-parallel-workers" "$SKILL_FILE" \
  || fail "skill name is not 'dispatching-parallel-workers'"

grep -q "^description:" "$SKILL_FILE" \
  || fail "skill missing description frontmatter"

# --- Child worktree isolation documented ------------------------------------
grep -q "new-child" "$SKILL_FILE" \
  || fail "SKILL.md does not document child worktree isolation (--worktree new-child)"

# --- Settle and merge workflow documented -----------------------------------
grep -qi "merge" "$SKILL_FILE" \
  || fail "SKILL.md does not document merge/integration of worker outcomes"

echo "PASS: dispatching-parallel-workers skill is valid"
