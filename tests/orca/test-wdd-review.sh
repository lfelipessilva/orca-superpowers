#!/usr/bin/env bash
# Test wdd review command (heterogeneous agent selection, spec generation, and flag sanitization)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-review: testing wdd review command"

MOCK_ORCA="$TMP_DIR/mock_orca"
CALL_LOG="$TMP_DIR/orca_calls.log"

cat << 'EOF' > "$MOCK_ORCA"
#!/usr/bin/env bash
echo "$*" >> "$CALL_LOG"
cmd="$1"
sub="$2"
shift 2

case "$sub" in
  account)
    # mock cursor and antigravity both authenticated
    cat << 'JSON'
{"ok":true,"result":{"antigravity":{"accounts":[{"id":"1"}]},"cursor":{"accounts":[{"id":"2"}]},"rateLimits":{"cursor":{"status":"ok"},"antigravity":{"status":"ok"}}}}
JSON
    ;;
  task-list)
    cat << 'JSON'
{"ok":true,"result":{"tasks":[
  {"id":"task_dense_1","status":"dispatched","title":"T2 [dense] Schema migration"}
]}}
JSON
    ;;
  worker-list)
    cat << 'JSON'
{"ok":true,"result":{"workers":[
  {"dispatchId":"ctx_impl_1","taskId":"task_dense_1","agent":"antigravity","model":"gemini-3.8-flash","state":"completed","outcome":"succeeded"}
]}}
JSON
    ;;
  task-create)
    echo '{"ok":true,"result":{"id":"task_rev_1"}}'
    ;;
  worker-start)
    echo '{"ok":true,"result":{"dispatchId":"ctx_rev_1","state":"ready"}}'
    ;;
  *)
    echo '{"ok":true,"result":{}}'
    ;;
esac
EOF
chmod +x "$MOCK_ORCA"

# 1. Automatic heterogeneous reviewer selection (Antigravity was implementer -> picks Cursor)
OUT="$(CALL_LOG="$CALL_LOG" ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" review --run run_123 --task task_dense_1)"
echo "$OUT" | grep -q "Review dispatched" || fail "Expected 'Review dispatched' in output"
echo "$OUT" | grep -q "cursor" || fail "Reviewer agent should be cursor (heterogeneous vs antigravity)"

# 2. Check call log:
# task-create must use --parent task_dense_1
grep -q -- "--parent task_dense_1" "$CALL_LOG" || fail "Review task must be created with --parent"

# worker-start on cursor must NEVER have --effort
grep "worker-start" "$CALL_LOG" | grep -q "cursor" || fail "worker-start must launch cursor"
grep "worker-start" "$CALL_LOG" | grep -q -- "--effort" && fail "Cursor reviewer must NOT have --effort passed"

echo "PASS: wdd review verified"
