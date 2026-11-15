#!/usr/bin/env bash
# Test WDD configuration engine, defaults, and flag sanitization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-config: checking configuration and model defaults resolution"

# Setup isolated env
export WDD_CONFIG_DIR="$TMP_DIR/global_config"
mkdir -p "$WDD_CONFIG_DIR"
export WDD_LOCAL_DIR="$TMP_DIR/local_proj"
mkdir -p "$WDD_LOCAL_DIR"

cd "$WDD_LOCAL_DIR"

# 1. Built-in defaults when nothing configured
AG_MODEL="$(bash "$WDD" config resolve-model --agent antigravity)"
[ "$AG_MODEL" = "gemini-3.8-flash" ] || fail "Expected antigravity default gemini-3.8-flash, got $AG_MODEL"

CURSOR_MODEL="$(bash "$WDD" config resolve-model --agent cursor)"
[ "$CURSOR_MODEL" = "composer-2.5-fast" ] || fail "Expected cursor default composer-2.5-fast, got $CURSOR_MODEL"

# 2. Local config set & get
bash "$WDD" config set antigravity.model gemini-3.8-flash-high --local
[ -f "$WDD_LOCAL_DIR/.wddrc" ] || fail ".wddrc was not created in local dir"

GET_VAL="$(bash "$WDD" config get antigravity.model --local)"
[ "$GET_VAL" = "gemini-3.8-flash-high" ] || fail "Expected gemini-3.8-flash-high, got $GET_VAL"

RESOLVED_AG="$(bash "$WDD" config resolve-model --agent antigravity)"
[ "$RESOLVED_AG" = "gemini-3.8-flash-high" ] || fail "Expected resolved local model gemini-3.8-flash-high, got $RESOLVED_AG"

# 3. Global config set & get
bash "$WDD" config set cursor.model composer-2.5 --global
[ -f "$WDD_CONFIG_DIR/config.json" ] || fail "global config.json was not created"

RESOLVED_CURSOR="$(bash "$WDD" config resolve-model --agent cursor)"
[ "$RESOLVED_CURSOR" = "composer-2.5" ] || fail "Expected global resolved cursor composer-2.5, got $RESOLVED_CURSOR"

# 4. Local overrides global
bash "$WDD" config set cursor.model gpt-5.3-codex-high --local
RESOLVED_CURSOR_LOCAL="$(bash "$WDD" config resolve-model --agent cursor)"
[ "$RESOLVED_CURSOR_LOCAL" = "gpt-5.3-codex-high" ] || fail "Local should override global cursor model"

# 5. Environment variable overrides local
export WDD_MODEL_CURSOR="gpt-5.3-codex-fast"
RESOLVED_CURSOR_ENV="$(bash "$WDD" config resolve-model --agent cursor)"
[ "$RESOLVED_CURSOR_ENV" = "gpt-5.3-codex-fast" ] || fail "Env var should override local config"
unset WDD_MODEL_CURSOR

# 6. Flag sanitization:
# Antigravity without model but with effort -> must inject model
SANITIZED_AG="$(bash "$WDD" config sanitize-flags --agent antigravity --effort medium)"
echo "$SANITIZED_AG" | grep -q -- "--model" || fail "Antigravity with effort must inject --model"
echo "$SANITIZED_AG" | grep -q -- "--effort medium" || fail "Antigravity must keep --effort"

# Cursor with effort -> must strip effort
SANITIZED_CURSOR="$(bash "$WDD" config sanitize-flags --agent cursor --model composer-2.5 --effort high)"
echo "$SANITIZED_CURSOR" | grep -q -- "--model composer-2.5" || fail "Cursor must keep --model"
echo "$SANITIZED_CURSOR" | grep -q -- "--effort" && fail "Cursor must strip --effort flag"

echo "PASS: wdd-config tests passed"
