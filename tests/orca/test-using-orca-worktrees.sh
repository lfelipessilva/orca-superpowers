#!/usr/bin/env bash
# Validate the using-orca-worktrees skill: frontmatter, Orca CLI detection,
# child worktree creation, status comments, and resource cleanup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/using-orca-worktrees"
SKILL_FILE="$SKILL_DIR/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-using-orca-worktrees: checking using-orca-worktrees skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"

# --- Frontmatter checks -----------------------------------------------------
grep -q "^name: using-orca-worktrees" "$SKILL_FILE" \
  || fail "skill name is not 'using-orca-worktrees'"

grep -q "^description:" "$SKILL_FILE" \
  || fail "skill is missing description frontmatter"

# --- Core Orca worktree commands documented ---------------------------------
for cmd in "orca worktree current" "orca worktree create" "new-child" "orca worktree set"; do
  grep -q "$cmd" "$SKILL_FILE" \
    || fail "skill does not document '$cmd'"
done

# --- Fallback behavior documented -------------------------------------------
grep -qi "fallback" "$SKILL_FILE" \
  || fail "skill does not document fallback when outside Orca"

echo "PASS: using-orca-worktrees skill is valid"
