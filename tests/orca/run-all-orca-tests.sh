#!/usr/bin/env bash
# Run all Orca integration and skill validation tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running Orca-Superpowers Test Suite ==="

test_scripts=(
  "$SCRIPT_DIR/test-catalog-removal.sh"
  "$SCRIPT_DIR/test-wdd-config.sh"
  "$SCRIPT_DIR/test-wdd-models.sh"
  "$SCRIPT_DIR/test-wdd-boot.sh"
  "$SCRIPT_DIR/test-wdd-status.sh"
  "$SCRIPT_DIR/test-wdd-complete.sh"
  "$SCRIPT_DIR/test-wdd-check.sh"
  "$SCRIPT_DIR/test-wdd-review.sh"
  "$SCRIPT_DIR/test-tool-mapping.sh"
  "$SCRIPT_DIR/test-using-orca-worktrees.sh"
  "$SCRIPT_DIR/test-worker-driven-development.sh"
  "$SCRIPT_DIR/test-writing-plans-orca-handoff.sh"
  "$SCRIPT_DIR/test-decision-gates.sh"
  "$SCRIPT_DIR/test-cross-agent-review.sh"
  "$SCRIPT_DIR/test-parallel-workers.sh"
  "$SCRIPT_DIR/test-scripts.sh"
  "$REPO_ROOT/tests/skill-layout/test-no-dev-files-in-skills.sh"
)

passed=0
total=${#test_scripts[@]}

for script in "${test_scripts[@]}"; do
  echo "Running: $(basename "$script")..."
  bash "$script"
  passed=$((passed + 1))
done

echo ""
echo "=== All $passed/$total Orca-Superpowers tests passed! ==="
