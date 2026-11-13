#!/usr/bin/env bash
# Validate the orca-decision-gates skill: frontmatter, gate-create, gate-resolve,
# non-blocking DAG behavior, and decision criteria.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/orca-decision-gates"
SKILL_FILE="$SKILL_DIR/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-decision-gates: checking orca-decision-gates skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"

# --- Frontmatter checks -----------------------------------------------------
grep -q "^name: orca-decision-gates" "$SKILL_FILE" \
  || fail "skill name is not 'orca-decision-gates'"

grep -q "^description:" "$SKILL_FILE" \
  || fail "skill missing description frontmatter"

# --- Gate commands documented -----------------------------------------------
for cmd in "gate-create" "gate-resolve" "gate-list"; do
  grep -q "$cmd" "$SKILL_FILE" \
    || fail "SKILL.md does not document '$cmd'"
done

# --- Non-blocking DAG behavior documented ------------------------------------
grep -qi "non-blocking" "$SKILL_FILE" \
  || fail "SKILL.md does not document non-blocking behavior for independent tasks"

# --- Criteria: rulings vs gates ---------------------------------------------
grep -qi "ruling" "$SKILL_FILE" \
  || fail "SKILL.md does not contrast rulings vs gates"

echo "PASS: orca-decision-gates skill is valid"
