#!/usr/bin/env bash
# Validate install.sh and sync-upstream.sh scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INSTALL_SCRIPT="$REPO_ROOT/scripts/install.sh"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-upstream.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-scripts: checking install.sh and sync-upstream.sh"

[ -x "$INSTALL_SCRIPT" ] || fail "install.sh missing or not executable"
[ -x "$SYNC_SCRIPT" ] || fail "sync-upstream.sh missing or not executable"

# Test local install and uninstall
TMP_TARGET="$REPO_ROOT/.agents/skills"
bash "$INSTALL_SCRIPT" --local
[ -d "$TMP_TARGET/worker-driven-development" ] || fail "worker-driven-development not installed"
[ -d "$TMP_TARGET/orca-decision-gates" ] || fail "orca-decision-gates not installed"

# Test uninstall
bash "$INSTALL_SCRIPT" --local --uninstall
[ ! -e "$TMP_TARGET/worker-driven-development" ] || fail "worker-driven-development not removed after uninstall"

# Test sync-upstream with --check-only
bash "$SYNC_SCRIPT" --check-only >/dev/null

echo "PASS: install.sh and sync-upstream.sh are valid and functional"
