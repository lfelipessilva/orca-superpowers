#!/usr/bin/env bash
# Test dynamic model listing via list-models.sh and wdd models
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-models: testing dynamic on-demand model queries"

# 1. Antigravity models query
AG_MODELS="$(bash "$WDD" models --agent antigravity --ids-only)"
[ -n "$AG_MODELS" ] || fail "Antigravity models query returned empty output"
echo "$AG_MODELS" | grep -q "gemini" || fail "Antigravity models should contain gemini models"

# 2. Cursor models query
CURSOR_MODELS="$(bash "$WDD" models --agent cursor --ids-only)"
[ -n "$CURSOR_MODELS" ] || fail "Cursor models query returned empty output"
echo "$CURSOR_MODELS" | grep -Eq "composer|codex" || fail "Cursor models should contain composer or codex"

# 3. Claude models query
CLAUDE_MODELS="$(bash "$WDD" models --agent claude --ids-only)"
[ -n "$CLAUDE_MODELS" ] || fail "Claude models query returned empty output"
echo "$CLAUDE_MODELS" | grep -q "sonnet" || fail "Claude models should contain sonnet"

# 4. Brevity check: output should not be a massive dump
LINE_COUNT="$(echo "$AG_MODELS" | wc -l | tr -d ' ')"
[ "$LINE_COUNT" -le 25 ] || fail "Antigravity models output exceeded 25 lines ($LINE_COUNT lines)"

echo "PASS: dynamic model query verified"
