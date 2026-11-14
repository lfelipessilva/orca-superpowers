#!/usr/bin/env bash
# Brief agent auth map from `orca account list --json` — no rate-limit blobs / emails dump.
# Usage: agents-brief.sh [--json] [--ok-only]
set -euo pipefail

ORCA_BIN="${ORCA_CLI_COMMAND:-orca}"
AS_JSON=0
OK_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) AS_JSON=1; shift ;;
    --ok-only) OK_ONLY=1; shift ;;
    -h|--help) echo "Usage: $0 [--json] [--ok-only]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

"$ORCA_BIN" account list --json | WDD_AS_JSON="$AS_JSON" WDD_OK_ONLY="$OK_ONLY" python3 -c '
import json, os, sys
as_json = os.environ.get("WDD_AS_JSON") == "1"
ok_only = os.environ.get("WDD_OK_ONLY") == "1"
d = json.load(sys.stdin)
result = d.get("result", d)
agents = {}
for k, v in result.items():
    if k == "rateLimits" or not isinstance(v, dict):
        continue
    accts = v.get("accounts") or []
    has_system = bool((v.get("systemDefault") or {}).get("hasAuth"))
    auth = bool(accts) or has_system
    agents[k] = {"ok": auth, "accounts": len(accts) if isinstance(accts, list) else 0}

rl = result.get("rateLimits") or {}
extra = {}
for name, block in rl.items():
    if not isinstance(block, dict):
        continue
    if name in agents:
        st = block.get("status")
        if st:
            agents[name]["status"] = st
    elif name in ("cursor", "muse", "grok", "gemini", "minimax", "zcode"):
        st = block.get("status")
        extra[name] = {"ok": st == "ok", "status": st}

merged = {**agents, **extra}
if ok_only:
    merged = {k: v for k, v in merged.items() if v.get("ok")}

if as_json:
    print(json.dumps(merged, indent=2, sort_keys=True))
else:
    for name in sorted(merged):
        v = merged[name]
        flag = "ok" if v.get("ok") else "no"
        st = v.get("status") or ("auth" if v.get("ok") else "missing")
        print(f"{name}\t{flag}\t{st}")
'
