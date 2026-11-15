#!/usr/bin/env bash
# Test WDD status-brief.sh and wdd status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-status: testing wdd status command"

# Create a mock orca script that returns predictable JSON for status checks
MOCK_ORCA="$TMP_DIR/mock_orca"
cat << 'EOF' > "$MOCK_ORCA"
#!/usr/bin/env bash
cmd="$1"
sub="$2"
shift 2

case "$sub" in
  task-list)
    cat << 'JSON'
{"ok":true,"result":{"tasks":[
  {"id":"task_1","status":"completed","title":"T1 [scaffold] Monorepo setup"},
  {"id":"task_2","status":"completed","title":"T2 [dense] Schema migration"},
  {"id":"task_3","status":"running","title":"T3 [wiring] Fastify app shell"},
  {"id":"task_4","status":"ready","title":"T4 [dense] Accounts API"},
  {"id":"task_5","status":"pending","title":"T5 [dense] Archetypes API"}
]}}
JSON
    ;;
  worker-list)
    cat << 'JSON'
{"ok":true,"result":{"workers":[
  {"dispatchId":"ctx_w3","taskId":"task_3","agent":"antigravity","model":"gemini-3.8-flash","state":"running","outcome":""}
]}}
JSON
    ;;
  inbox)
    cat << 'JSON'
{"ok":true,"result":{"messages":[
  {"id":"msg_1","subject":"worker_done","from":"dispatch:ctx_w2","payload":"taskId=task_2 dispatchId=ctx_w2 outcome=succeeded"}
]}}
JSON
    ;;
  *)
    echo '{"ok":true,"result":{}}'
    ;;
esac
EOF
chmod +x "$MOCK_ORCA"

# Run wdd status using mock orca
STATUS_OUT="$(ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" status --run run_test123)"

# Verify expected lines and structure
echo "$STATUS_OUT" | grep -q "Run: run_test123" || fail "status output must include Run ID"
echo "$STATUS_OUT" | grep -q "2/5 tasks completed" || fail "status output must show 2/5 tasks completed"
echo "$STATUS_OUT" | grep -q "Active:" || fail "status output must show Active worker row"
echo "$STATUS_OUT" | grep -q "ctx_w3" || fail "Active worker must show ctx_w3"
echo "$STATUS_OUT" | grep -q "Inbox:" || fail "status output must show Inbox row"
echo "$STATUS_OUT" | grep -q "1 unread" || fail "Inbox row must show 1 unread"
echo "$STATUS_OUT" | grep -q "Ready:" || fail "status output must show Ready row"
echo "$STATUS_OUT" | grep -q "task_4" || fail "Ready row must name task_4"

# Check output length is strictly concise (<6 lines)
LINE_COUNT="$(echo "$STATUS_OUT" | wc -l | tr -d ' ')"
[ "$LINE_COUNT" -le 6 ] || fail "wdd status output must be <= 6 lines (got $LINE_COUNT lines)"

echo "PASS: wdd status verified"
