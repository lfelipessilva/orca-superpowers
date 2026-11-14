#!/usr/bin/env bash
# Brief model id list from the checked-in catalog (no Orca/agy/agent discovery).
# Usage: list-model-catalog.sh [--agent NAME] [--ids-only]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$SKILL_DIR/references/model-catalog.yaml"

AGENT=""
IDS_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="${2:?}"; shift 2 ;;
    --ids-only) IDS_ONLY=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--agent antigravity|claude|cursor|opencode] [--ids-only]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$CATALOG" ]] || { echo "missing catalog: $CATALOG" >&2; exit 1; }

python3 - "$CATALOG" "$AGENT" "$IDS_ONLY" <<'PY'
import sys
from pathlib import Path

path, want, ids_only = Path(sys.argv[1]), sys.argv[2], sys.argv[3] == "1"
text = path.read_text()

# Minimal YAML subset parser for this file shape (no PyYAML dependency).
agents = {}
cur = None
in_models = False
in_compound = False
for raw in text.splitlines():
    line = raw.rstrip()
    if not line or line.lstrip().startswith("#"):
        continue
    if line.startswith("defaults:"):
        cur = None
        in_models = in_compound = False
        continue
    if line.endswith(":") and not line.startswith(" ") and line[:-1] != "defaults":
        cur = line[:-1]
        agents[cur] = {"models": [], "compound": [], "agent": cur, "notes": ""}
        in_models = in_compound = False
        continue
    if cur is None:
        continue
    s = line.strip()
    if s.startswith("agent:"):
        agents[cur]["agent"] = s.split(":", 1)[1].strip()
    elif s.startswith("notes:"):
        agents[cur]["notes"] = s.split(":", 1)[1].strip().strip('"')
    elif s == "models:":
        in_models, in_compound = True, False
    elif s == "compound_model_ids:":
        in_models, in_compound = False, True
    elif s.startswith("- id:"):
        agents[cur]["models"].append(s.split(":", 1)[1].strip())
    elif s.startswith("- ") and in_compound:
        agents[cur]["compound"].append(s[2:].strip())
    elif s.startswith("efforts:") or s.startswith("notes:") or s.startswith("effort_"):
        pass

names = [want] if want else list(agents)
for name in names:
    if name not in agents:
        print(f"unknown agent: {name}", file=sys.stderr)
        sys.exit(1)
    block = agents[name]
    if ids_only:
        for mid in block["models"] + block["compound"]:
            print(mid)
        continue
    print(f"{name} (--agent {block['agent']})  models={len(block['models'])}")
    if block["notes"]:
        print(f"  # {block['notes']}")
    for mid in block["models"]:
        print(f"  {mid}")
    if block["compound"]:
        print("  # compound ids:")
        for mid in block["compound"]:
            print(f"  {mid}")
PY
