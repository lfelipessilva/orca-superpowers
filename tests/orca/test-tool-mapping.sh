#!/usr/bin/env bash
# Validate the Orca tool mapping: worker dispatch via orca orchestration worker-start,
# task DAG tracking via task-create, decision gates via gate-create, worktrees via orca worktree,
# and SKILL.md pointing at the mapping.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MAPPING="$REPO_ROOT/skills/using-superpowers/references/orca-tools.md"
SKILL="$REPO_ROOT/skills/using-superpowers/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-tool-mapping: checking Orca tool mapping"

# --- Mapping exists ---------------------------------------------------------
[ -f "$MAPPING" ] || fail "tool mapping missing at $MAPPING"

# --- Core action->tool mappings are documented -------------------------------
for tool in "orca orchestration worker-start" "orca orchestration task-create" "orca orchestration gate-create" "orca orchestration send" "orca worktree"; do
  grep -q "$tool" "$MAPPING" \
    || fail "mapping does not document '$tool'"
done

# --- Cross-agent orchestration is documented ---------------------------------
for agent in "codex" "claude" "antigravity"; do
  grep -iq "$agent" "$MAPPING" \
    || fail "mapping does not document '$agent' agent support"
done

# --- Decision gates documented -----------------------------------------------
grep -qE 'gate-create|gate-resolve' "$MAPPING" \
  || fail "mapping does not document decision gates (gate-create / gate-resolve)"

# --- SKILL.md Platform Adaptation links the mapping -------------------------
grep -q "orca-tools.md" "$SKILL" \
  || fail "SKILL.md Platform Adaptation does not reference orca-tools.md"

echo "PASS: Orca tool mapping valid (workers, tasks, decision gates, cross-agent, SKILL.md link)"
