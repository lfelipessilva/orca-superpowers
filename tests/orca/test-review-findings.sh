#!/usr/bin/env bash
# Verification tests for review findings (agent case-insensitivity, review task skipping, repo root .wddrc, error reporting)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wdd_findings.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-review-findings: verifying fixes for reviewer findings"

# 1. Finding 1: Agent case-insensitivity in sanitize-flags
OUT_CURSOR="$(bash "$WDD" config sanitize-flags --agent Cursor --effort high)"
echo "$OUT_CURSOR" | grep -q -- "--effort" && fail "Finding 1: --agent Cursor must strip --effort flag"

OUT_AG="$(bash "$WDD" config sanitize-flags --agent Antigravity --effort medium)"
echo "$OUT_AG" | grep -q -- "--model gemini-3.8-flash" || fail "Finding 1: --agent Antigravity must inject default --model"

# 2. Finding 2: Review task title check in complete-brief.sh
MOCK_ORCA="$TMP_DIR/mock_orca"
CALL_LOG="$TMP_DIR/orca_calls.log"

cat << 'EOF' > "$MOCK_ORCA"
#!/usr/bin/env bash
echo "$*" >> "$CALL_LOG"
sub="$2"
shift 2

case "$sub" in
  task-update)
    echo '{"ok":true,"result":{"status":"completed"}}'
    ;;
  task-list)
    cat << 'JSON'
{"ok":true,"result":{"tasks":[
  {"id":"task_rev_uuid","status":"completed","title":"Review: T2 Schema migration"},
  {"id":"task_impl_uuid","status":"completed","title":"T2 [dense] Schema migration"},
  {"id":"task_next_uuid","status":"ready","title":"T3 [wiring] Fastify app shell"}
]}}
JSON
    ;;
  worker-list)
    cat << 'JSON'
{"ok":true,"result":{"workers":[
  {"dispatchId":"ctx_impl","taskId":"task_impl_uuid","agent":"antigravity","model":"gemini-3.8-flash","state":"completed","outcome":"succeeded"},
  {"dispatchId":"ctx_rev","taskId":"task_rev_uuid","agent":"cursor","model":"composer-2.5-fast","state":"completed","outcome":"succeeded"}
]}}
JSON
    ;;
  worker-start)
    echo '{"ok":true,"result":{"dispatchId":"ctx_next","state":"ready"}}'
    ;;
  *)
    echo '{"ok":true,"result":{}}'
    ;;
esac
EOF
chmod +x "$MOCK_ORCA"

> "$CALL_LOG"
OUT_START="$(CALL_LOG="$CALL_LOG" ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" complete --run run_test --task task_rev_uuid --start-next)"
echo "$OUT_START" | grep -q "antigravity" || fail "Finding 2: --start-next must pick implementer agent (antigravity), not reviewer (cursor)"

# 3. Finding 3: Stderr captured on Orca CLI errors
MOCK_FAIL_ORCA="$TMP_DIR/mock_fail_orca"
cat << 'EOF' > "$MOCK_FAIL_ORCA"
#!/usr/bin/env bash
echo "Authentication failed: token expired" >&2
exit 1
EOF
chmod +x "$MOCK_FAIL_ORCA"

OUT_ERR="$(ORCA_CLI_COMMAND="$MOCK_FAIL_ORCA" bash "$WDD" complete --run run_test --task task_1 2>&1 || true)"
echo "$OUT_ERR" | grep -q "Authentication failed: token expired" || fail "Finding 3: complete-brief must report stderr error details"

# 4. Finding 4: Project root .wddrc discovery from subdirectory
SUBDIR="$TMP_DIR/sub/nested"
mkdir -p "$SUBDIR"
cat << 'EOF' > "$TMP_DIR/.wddrc"
{"antigravity": {"model": "gemini-test-root"}}
EOF

cd "$SUBDIR"
git init -q
cp "$TMP_DIR/.wddrc" .
RESOLVED_SUB="$(bash "$WDD" config resolve-model --agent antigravity)"
[ "$RESOLVED_SUB" = "gemini-test-root" ] || fail "Finding 4: .wddrc must be discovered in repo root from subdirectory"

echo "PASS: all review finding tests passed"
