#!/usr/bin/env bash
# Regenerate skills/worker-driven-development/references/model-catalog.yaml
# from local CLIs / Orca catalog DB. Run only when refreshing — not on every dispatch.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$SKILL_DIR/references/model-catalog.yaml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "refresh-model-catalog: collecting…"

if command -v agent >/dev/null 2>&1; then
  agent models 2>/dev/null | awk 'NR>2 && $1!="" {print $1}' >"$TMP/cursor.txt" || true
fi
if command -v agy >/dev/null 2>&1; then
  agy models 2>/dev/null | awk -F'\t' 'NF>=1 && $1!~/^Fetching/ && $1!="" {print $1}' >"$TMP/agy.txt" || true
fi

python3 - "$OUT" "$TMP" <<'PY'
import datetime, json, sqlite3, sys
from pathlib import Path

out = Path(sys.argv[1])
tmp = Path(sys.argv[2])
cursor_ids = (tmp / "cursor.txt").read_text().splitlines() if (tmp / "cursor.txt").exists() else []
agy_ids = (tmp / "agy.txt").read_text().splitlines() if (tmp / "agy.txt").exists() else []

db = Path.home() / "Library/Application Support/orca/agent-model-catalog.db"
best = {}
if db.exists():
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    for k, seq, v in con.execute("SELECT key, seq, value FROM rows"):
        agent = k.split("\0")[0] if "\0" in k else k
        if agent not in best or seq > best[agent][0]:
            best[agent] = (seq, json.loads(v))

def efforts_of(m):
    return [x.get("value") for x in (m.get("efforts") or []) if isinstance(x, dict) and x.get("value")]

def live_models(agent):
    if agent not in best:
        return []
    block = best[agent][1]
    return (block.get("live") or {}).get("models") or (block.get("discovered") or {}).get("models") or []

opencode_models = []
for m in live_models("opencode"):
    item = {"id": m["id"]}
    ef = efforts_of(m)
    if ef:
        item["efforts"] = ef
    opencode_models.append(item)

anti_live = []
for m in live_models("antigravity"):
    item = {"id": m["id"]}
    ef = efforts_of(m)
    if ef:
        item["efforts"] = ef
    anti_live.append(item)

# Preserve prior claude section if present; else seed aliases.
prev_claude = []
if out.exists():
    cur = None
    for line in out.read_text().splitlines():
        if line == "claude:":
            cur = "claude"
            continue
        if cur == "claude" and line and not line.startswith(" ") and line.endswith(":"):
            break
        if cur == "claude" and line.strip().startswith("- id:"):
            prev_claude.append({"id": line.split(":", 1)[1].strip()})
claude_models = prev_claude or [
    {"id": "sonnet", "notes": "alias → latest sonnet"},
    {"id": "opus", "notes": "alias → latest opus"},
    {"id": "haiku", "notes": "alias → latest haiku"},
    {"id": "claude-sonnet-4-6"},
    {"id": "claude-opus-4-6"},
    {"id": "claude-haiku-4-5"},
]

lines = []
a = lines.append
a("# Model catalog for Orca worker-start --agent / --model / --effort")
a("# Edit by hand, or: bash scripts/wdd refresh-models")
a("# Brief print: bash scripts/wdd models [--agent NAME] [--ids-only]")
a("# Agents auth brief: bash scripts/wdd agents")
a("#")
a("# Upstream wish: `orca models list --agent <id> --ids-only`")
a("#")
a(f"# refreshed: {datetime.date.today().isoformat()}")
a("")
a("defaults:")
a("  effort:")
a("    wiring: low")
a("    scaffold: medium")
a("    dense: high")
a("")

def dump_agent(key, agent_id, *, effort_flag=False, effort_in_id=False, compound_ids=None, models=None, notes=None):
    a(f"{key}:")
    a(f"  agent: {agent_id}")
    if notes:
        a(f"  notes: \"{notes}\"")
    if effort_flag:
        a("  effort_flag: true")
    if effort_in_id:
        a("  effort_in_id: true")
    if compound_ids:
        a("  compound_model_ids:")
        for cid in compound_ids:
            a(f"    - {cid}")
    a("  models:")
    for m in models or []:
        if isinstance(m, str):
            a(f"    - id: {m}")
            continue
        a(f"    - id: {m['id']}")
        if m.get("efforts"):
            a(f"      efforts: [{', '.join(m['efforts'])}]")
        if m.get("notes"):
            a(f"      notes: \"{m['notes']}\"")
    a("")

compound = [x for x in agy_ids if "flash-" in x]
dump_agent(
    "antigravity", "antigravity", effort_flag=True, compound_ids=compound,
    models=anti_live or [{"id": x} for x in agy_ids],
    notes="Google Antigravity (agy). Prefer --model <base> --effort <level>; compound ids also work.",
)
dump_agent(
    "claude", "claude", effort_flag=True, models=claude_models,
    notes="Claude Code. Aliases sonnet/opus/haiku accepted. Refresh when Anthropic ships new ids.",
)
if not cursor_ids and out.exists():
    # keep previous cursor block ids
    cur = None
    for line in out.read_text().splitlines():
        if line == "cursor:":
            cur = "cursor"
            continue
        if cur == "cursor" and line and not line.startswith(" ") and line.endswith(":"):
            break
        if cur == "cursor" and line.strip().startswith("- id:"):
            cursor_ids.append(line.split(":", 1)[1].strip())
dump_agent(
    "cursor", "cursor", effort_in_id=True,
    models=[{"id": x} for x in cursor_ids],
    notes="Cursor Agent CLI. Most ids encode effort (-low/-high/-fast). Pass --model only.",
)
dump_agent(
    "opencode", "opencode", effort_flag=True, models=opencode_models,
    notes="OpenCode (aka openbot). Same ids for --agent opencode2. Omit --effort if host refuses it.",
)

out.write_text("\n".join(lines) + "\n")
print(f"wrote {out} ({out.stat().st_size} bytes)")
print("antigravity", len(anti_live or agy_ids), "claude", len(claude_models), "cursor", len(cursor_ids), "opencode", len(opencode_models))
PY
