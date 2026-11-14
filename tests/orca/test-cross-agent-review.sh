#!/usr/bin/env bash
# Validate cross-agent-review skill: frontmatter, heterogeneous reviewer selection,
# read-only diff inspection, and review spec template.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKILL_DIR="$REPO_ROOT/skills/cross-agent-review"
SKILL_FILE="$SKILL_DIR/SKILL.md"
TEMPLATE_FILE="$SKILL_DIR/templates/review-worker-spec.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-cross-agent-review: checking cross-agent-review skill"

[ -f "$SKILL_FILE" ] || fail "SKILL.md missing at $SKILL_FILE"
[ -f "$TEMPLATE_FILE" ] || fail "review-worker-spec.md missing at $TEMPLATE_FILE"

# --- Frontmatter checks -----------------------------------------------------
grep -q "^name: cross-agent-review" "$SKILL_FILE" \
  || fail "skill name is not 'cross-agent-review'"

grep -q "^description:" "$SKILL_FILE" \
  || fail "skill missing description frontmatter"

# --- Heterogeneous principle documented -------------------------------------
grep -qi "heterogeneous" "$SKILL_FILE" \
  || fail "SKILL.md does not document heterogeneous agent pairing"

# --- Read-only review constraint --------------------------------------------
grep -qi "read-only" "$SKILL_FILE" \
  || fail "SKILL.md does not document read-only review constraint"

# --- Selective review policy ------------------------------------------------
grep -q "Selective review" "$SKILL_FILE" \
  || fail "SKILL.md must document Selective review"
grep -q "wiring" "$SKILL_FILE" \
  || fail "SKILL.md must mention wiring class (skip cross-review)"
grep -q "dense" "$SKILL_FILE" \
  || fail "SKILL.md must mention dense class (require cross-review)"

# --- Template checks --------------------------------------------------------
grep -q "git diff" "$TEMPLATE_FILE" \
  || fail "template does not include git diff inspection command"

echo "PASS: cross-agent-review skill is valid"
