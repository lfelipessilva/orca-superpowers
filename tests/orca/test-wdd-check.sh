#!/usr/bin/env bash
# Test wdd check command (parsing check output into a concise 1-line event)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WDD="$REPO_ROOT/skills/worker-driven-development/scripts/wdd"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-wdd-check: testing wdd check command"

MOCK_ORCA="$TMP_DIR/mock_orca"
cat << 'EOF' > "$MOCK_ORCA"
#!/usr/bin/env bash
cmd="$1"
sub="$2"
shift 2

case "$sub" in
  check)
    if [[ "${MOCK_SCENARIO:-worker_done}" == "worker_done" ]]; then
      cat << 'TXT'
You have 1 orchestration message:
  id: msg_worker_done_1
  subject: worker_done
  from: dispatch:ctx_5cf5176e0772
  payload: taskId=task_aa317c5f8980 dispatchId=ctx_5cf5176e0772 outcome=succeeded
To give this worker more work: orca orchestration send ...
TXT
    elif [[ "${MOCK_SCENARIO}" == "ask" ]]; then
      cat << 'TXT'
You have 1 orchestration message:
  id: msg_ask_2
  subject: ask
  from: dispatch:ctx_abc
  payload: question="Should I migrate casal?"
TXT
    else
      echo "No unread messages for run run_test."
    fi
    ;;
  *)
    echo '{"ok":true}'
    ;;
esac
EOF
chmod +x "$MOCK_ORCA"

# 1. worker_done scenario
OUT_DONE="$(MOCK_SCENARIO="worker_done" ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" check --run run_test)"
echo "$OUT_DONE" | grep -q "\[worker_done\]" || fail "Expected [worker_done] header"
echo "$OUT_DONE" | grep -q "task=task_aa317c5f8980" || fail "Expected task ID"
echo "$OUT_DONE" | grep -q "outcome=succeeded" || fail "Expected outcome=succeeded"

# 2. ask scenario
OUT_ASK="$(MOCK_SCENARIO="ask" ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" check --run run_test)"
echo "$OUT_ASK" | grep -q "\[ask\]" || fail "Expected [ask] header"
echo "$OUT_ASK" | grep -q "Should I migrate casal?" || fail "Expected question text"

# 3. empty scenario
OUT_EMPTY="$(MOCK_SCENARIO="empty" ORCA_CLI_COMMAND="$MOCK_ORCA" bash "$WDD" check --run run_test)"
echo "$OUT_EMPTY" | grep -qi "no unread" || fail "Expected 'no unread' message"

echo "PASS: wdd check verified"
