#!/usr/bin/env bash
# writing-plans must default to Worker-driven when Orca is available,
# and must not steer plan execution to harness subagents by default.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
ORCA_TOOLS="$REPO_ROOT/skills/using-superpowers/references/orca-tools.md"
PARALLEL="$REPO_ROOT/skills/dispatching-parallel-agents/SKILL.md"
REVIEW="$REPO_ROOT/skills/requesting-code-review/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "test-writing-plans-orca-handoff: checking Orca-first execution routing"

[ -f "$PLANS" ] || fail "writing-plans SKILL.md missing"
[ -f "$SDD" ] || fail "subagent-driven-development SKILL.md missing"
[ -f "$ORCA_TOOLS" ] || fail "orca-tools.md missing"

grep -q "Worker-driven" "$PLANS" \
  || fail "writing-plans must offer Worker-driven"
grep -q "worker-driven-development" "$PLANS" \
  || fail "writing-plans must require worker-driven-development"
grep -q "default when Orca is available" "$PLANS" \
  || fail "writing-plans must mark Worker-driven as Orca default"

# Subagent-driven must remain available as fallback, but not be the only path
grep -q "subagent-driven-development" "$PLANS" \
  || fail "writing-plans must still document Subagent-driven fallback"

grep -q "Orca override" "$SDD" \
  || fail "subagent-driven-development must document Orca override"
grep -q "worker-driven-development" "$SDD" \
  || fail "subagent-driven-development must redirect to worker-driven-development"

grep -q "Hard rule: workers, not harness subagents" "$ORCA_TOOLS" \
  || fail "orca-tools.md must ban harness subagents when Orca is available"
grep -q "dispatching-parallel-workers" "$ORCA_TOOLS" \
  || fail "orca-tools.md must route parallel work to workers"
grep -q "cross-agent-review" "$ORCA_TOOLS" \
  || fail "orca-tools.md must route review to cross-agent-review"

grep -q "Orca override" "$PARALLEL" \
  || fail "dispatching-parallel-agents must document Orca override"
grep -q "dispatching-parallel-workers" "$PARALLEL" \
  || fail "dispatching-parallel-agents must redirect to parallel workers"

grep -q "Orca override" "$REVIEW" \
  || fail "requesting-code-review must document Orca override"
grep -q "cross-agent-review" "$REVIEW" \
  || fail "requesting-code-review must redirect to cross-agent-review"

echo "PASS: writing-plans Orca handoff and subagent overrides are wired"
