#!/usr/bin/env bash
# Verify that static model catalog files and obsolete refresh scripts are cleanly removed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-catalog-removal: checking removal of static catalog and refresh script"

# Obsolete files must not exist
[ ! -f "$REPO_ROOT/skills/worker-driven-development/references/model-catalog.yaml" ] \
  || fail "model-catalog.yaml should be removed"

[ ! -f "$REPO_ROOT/skills/worker-driven-development/scripts/refresh-model-catalog.sh" ] \
  || fail "refresh-model-catalog.sh should be removed"

[ ! -e "$REPO_ROOT/scripts/refresh-model-catalog.sh" ] \
  || fail "scripts/refresh-model-catalog.sh should be removed"

[ ! -e "$REPO_ROOT/scripts/list-model-catalog.sh" ] \
  || fail "scripts/list-model-catalog.sh should be removed"

# wdd help output should not mention refresh-models
HELP_OUT="$(bash "$WDD" help 2>&1 || true)"
echo "$HELP_OUT" | grep -q "refresh-models" \
  && fail "wdd help should not mention refresh-models"

# wdd refresh-models should fail with unknown command
if bash "$WDD" refresh-models 2>/dev/null; then
  fail "wdd refresh-models should fail as unknown command"
fi

echo "PASS: catalog removal verified"
