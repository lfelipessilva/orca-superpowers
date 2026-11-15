#!/usr/bin/env bash
# Test wdd complete command (flag normalization, safe update, and start-next)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-complete: testing wdd complete command"

# Create a mock orca script that records calls
MOCK_ORCA="$TMP_DIR/mock_orca"
CALL_LOG="$TMP_DIR/orca_calls.log"

cat << EOF > "$MOCK_ORCA"
#!/usr/bin/env bash
echo "\$*" >> "$CALL_LOG"
cmd="\$1"
sub="\$2"
shift 2

case "\$sub" in
  task-update)
    echo '{"ok":true,"result":{"status":"completed"}}'
    ;;
  task-list)
    cat << 'JSON'
{"ok":true,"result":{"tasks":[
  {"id":"task_next","status":"ready","title":"T2 [scaffold] Schema migration"}
]}}
JSON
    ;;
  worker-list)
    cat << 'JSON'
{"ok":true,"result":{"workers":[
  {"dispatchId":"ctx_prev","taskId":"task_1","agent":"antigravity","model":"gemini-3.8-flash","state":"completed","outcome":"succeeded"}
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

# 1. Test accepting --task (the hallucinated flag)
ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" complete --run run_123 --task task_1 --result "Verified scaffold"
grep -q "task-update --run run_123 --id task_1 --status completed --result Verified scaffold" "$CALL_LOG" \
  || fail "complete must map --task to --id in task-update"

# 2. Test accepting --id
> "$CALL_LOG"
ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" complete --run run_123 --id task_1
grep -q "task-update --run run_123 --id task_1 --status completed" "$CALL_LOG" \
  || fail "complete must accept --id"

# 3. Test --start-next launching ready task with sanitized flags
> "$CALL_LOG"
OUT="$(ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" complete --run run_123 --task task_1 --start-next)"
echo "$OUT" | grep -iq "task_1 marked completed" || fail "Expected completion output"
echo "$OUT" | grep -q "worker-start" || fail "Expected worker-start for next ready task"
grep -q "worker-start --run run_123 --task task_next" "$CALL_LOG" \
  || fail "worker-start must be invoked for task_next"

echo "PASS: wdd complete verified"
