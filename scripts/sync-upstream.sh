#!/usr/bin/env bash
# ==============================================================================
# sync-upstream.sh - Sync Superpowers-Orca with upstream obra/superpowers
# ==============================================================================
# Usage:
#   ./scripts/sync-upstream.sh [--check-only]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

UPSTREAM_URL="https://github.com/obra/superpowers.git"
UPSTREAM_BRANCH="main"
CHECK_ONLY=false

if [[ "${1:-}" == "--check-only" ]]; then
  CHECK_ONLY=true
fi

echo "=== Syncing with upstream ($UPSTREAM_URL) ==="

# 1. Ensure upstream remote exists
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Adding upstream remote: $UPSTREAM_URL"
  git remote add upstream "$UPSTREAM_URL"
fi

# 2. Fetch upstream
echo "Fetching upstream changes..."
git fetch upstream "$UPSTREAM_BRANCH"

CURRENT_BRANCH="$(git branch --show-current)"
UPSTREAM_REF="upstream/$UPSTREAM_BRANCH"

# 3. Check for incoming commits
BEHIND_COUNT=$(git rev-list --count "HEAD..$UPSTREAM_REF" 2>/dev/null || echo "0")

if [ "$BEHIND_COUNT" -eq 0 ]; then
  echo "✓ Already up to date with upstream obra/superpowers!"
  exit 0
fi

echo "Upstream has $BEHIND_COUNT new commit(s)."

if [ "$CHECK_ONLY" = true ]; then
  echo "Incoming commits:"
  git log --oneline "HEAD..$UPSTREAM_REF" -n 10
  exit 0
fi

# 4. Attempt merge
echo "Merging upstream/$UPSTREAM_BRANCH into $CURRENT_BRANCH..."
if git merge "$UPSTREAM_REF" -m "chore(upstream): sync changes from obra/superpowers"; then
  echo "✓ Successfully merged upstream changes!"
else
  echo ""
  echo "⚠️ Merge conflict encountered. Please resolve the conflicts and commit:"
  git status --short
  exit 1
fi

# 5. Run Orca tests to ensure no regressions
echo "Running Orca test suite to verify compatibility..."
if bash "$REPO_ROOT/tests/orca/run-all-orca-tests.sh"; then
  echo ""
  echo "=========================================================="
  echo "✓ Upstream sync complete and all Orca tests passed!"
  echo "Push your updated branch to GitHub with:"
  echo "  git push origin $CURRENT_BRANCH"
  echo "=========================================================="
else
  echo ""
  echo "❌ Orca tests failed after upstream merge. Please inspect failures." >&2
  exit 1
fi
