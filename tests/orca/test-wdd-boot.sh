#!/usr/bin/env bash
# Test agent flag sanitization and smart defaults in wdd-boot.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"
FIXTURE="$SCRIPT_DIR/fixtures/wdd-boot-sample-plan.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-boot: testing wdd-boot smart model defaulting and flag sanitization"

# 1. Antigravity without --model must auto-default --model when --effort is set
BOOT_AG="$(bash "$WDD" boot --plan "$FIXTURE" --agent antigravity --dry-run)"
echo "$BOOT_AG" | grep -q "worker-start" || fail "Expected worker-start in boot output"
echo "$BOOT_AG" | grep "worker-start" | grep -q -- "--model" || fail "Antigravity boot must inject --model into worker-start"
echo "$BOOT_AG" | grep "worker-start" | grep -q -- "gemini-3.8-flash" || fail "Antigravity boot should use default model gemini-3.8-flash"

# 2. Cursor boot must strip --effort flag from worker-start
BOOT_CURSOR="$(bash "$WDD" boot --plan "$FIXTURE" --agent cursor --dry-run)"
echo "$BOOT_CURSOR" | grep "worker-start" | grep -q -- "--model composer-2.5-fast" || fail "Cursor boot must use composer-2.5-fast"
echo "$BOOT_CURSOR" | grep "worker-start" | grep -q -- "--effort" && fail "Cursor boot must NOT pass --effort to worker-start"

# 3. Explicit model override is preserved
BOOT_CUSTOM="$(bash "$WDD" boot --plan "$FIXTURE" --agent antigravity --model gpt-oss-120b-medium --dry-run)"
echo "$BOOT_CUSTOM" | grep "worker-start" | grep -q -- "--model gpt-oss-120b-medium" || fail "Explicit --model must be respected"

echo "PASS: wdd-boot flag sanitization verified"
