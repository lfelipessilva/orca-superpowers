#!/usr/bin/env bash
# WDD Configuration and Defaults Engine
# Manages persistent config (.wddrc / ~/.config/wdd/config.json),
# resolves agent models & effort, and sanitizes flags before worker-start.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Global config location
CONFIG_HOME="${WDD_CONFIG_DIR:-$HOME/.config/wdd}"
GLOBAL_CONFIG="$CONFIG_HOME/config.json"

# Local config location
LOCAL_DIR="${WDD_LOCAL_DIR:-$(pwd)}"
LOCAL_CONFIG="$LOCAL_DIR/.wddrc"

python3 - "$GLOBAL_CONFIG" "$LOCAL_CONFIG" "$@" <<'PY'
import json, os, sys
from pathlib import Path

global_file = Path(sys.argv[1])
local_file = Path(sys.argv[2])
args = sys.argv[3:]

BUILTIN_DEFAULTS = {
    "antigravity": {
        "model": "gemini-3.8-flash",
        "effort_flag": True,
        "notes": "Google Antigravity (agy). Requires --model with --effort."
    },
    "cursor": {
        "model": "composer-2.5-fast",
        "effort_flag": False,
        "effort_in_id": True,
        "notes": "Cursor Agent CLI. Model ID encodes effort; strips --effort."
    },
    "claude": {
        "model": "sonnet",
        "effort_flag": True,
        "notes": "Claude Code. Accepts sonnet/opus/haiku."
    },
    "codex": {
        "model": "gpt-5.3-codex",
        "effort_flag": True,
        "notes": "Codex CLI."
    },
    "opencode": {
        "model": "auto",
        "effort_flag": True,
        "notes": "OpenCode CLI."
    }
}

CLASS_EFFORTS = {
    "wiring": "low",
    "scaffold": "medium",
    "dense": "high"
}

def load_json(p: Path) -> dict:
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception:
            return {}
    return {}

def save_json(p: Path, data: dict):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2) + "\n")

def get_nested(d: dict, key: str):
    parts = key.split(".")
    curr = d
    for p in parts:
        if isinstance(curr, dict) and p in curr:
            curr = curr[p]
        else:
            return None
    return curr

def set_nested(d: dict, key: str, val):
    parts = key.split(".")
    curr = d
    for p in parts[:-1]:
        if p not in curr or not isinstance(curr[p], dict):
            curr[p] = {}
        curr = curr[p]
    curr[parts[-1]] = val

def resolve_val(agent: str, field: str, explicit: str = ""):
    if explicit:
        return explicit
    # Check env var: e.g. WDD_MODEL_CURSOR
    env_name = f"WDD_{field.upper()}_{agent.upper()}"
    if env_name in os.environ and os.environ[env_name].strip():
        return os.environ[env_name].strip()
    # Check local config
    local_data = load_json(local_file)
    val = get_nested(local_data, f"{agent}.{field}")
    if val is not None:
        return str(val)
    # Check global config
    global_data = load_json(global_file)
    val = get_nested(global_data, f"{agent}.{field}")
    if val is not None:
        return str(val)
    # Check built-in defaults
    if agent in BUILTIN_DEFAULTS and field in BUILTIN_DEFAULTS[agent]:
        return str(BUILTIN_DEFAULTS[agent][field])
    return ""

cmd = args[0] if args else "help"

if cmd == "set":
    # set <key> <val> [--global|--local]
    if len(args) < 3:
        sys.exit("usage: wdd config set <agent.key> <value> [--global|--local]")
    key, val = args[1], args[2]
    is_local = "--local" in args
    target_file = local_file if is_local else global_file
    data = load_json(target_file)
    set_nested(data, key, val)
    save_json(target_file, data)
    scope = "local" if is_local else "global"
    print(f"Set {key}={val} ({scope})")

elif cmd == "get":
    if len(args) < 2:
        sys.exit("usage: wdd config get <agent.key> [--global|--local]")
    key = args[1]
    is_local = "--local" in args
    is_global = "--global" in args
    val = None
    if is_local:
        val = get_nested(load_json(local_file), key)
    elif is_global:
        val = get_nested(load_json(global_file), key)
    else:
        # resolve with precedence
        parts = key.split(".", 1)
        if len(parts) == 2:
            val = resolve_val(parts[0], parts[1])
        else:
            val = get_nested(load_json(local_file), key) or get_nested(load_json(global_file), key)
    if val is not None:
        print(val)

elif cmd == "list":
    merged = {}
    for a, info in BUILTIN_DEFAULTS.items():
        merged[a] = {"model": info.get("model", ""), "effort_flag": info.get("effort_flag", True)}
    g_data = load_json(global_file)
    for a, info in g_data.items():
        if isinstance(info, dict):
            merged.setdefault(a, {}).update(info)
    l_data = load_json(local_file)
    for a, info in l_data.items():
        if isinstance(info, dict):
            merged.setdefault(a, {}).update(info)
    print(json.dumps(merged, indent=2))

elif cmd == "resolve-model":
    agent = ""
    override = ""
    i = 1
    while i < len(args):
        if args[i] == "--agent" and i + 1 < len(args):
            agent = args[i + 1]
            i += 2
        elif args[i] == "--model" and i + 1 < len(args):
            override = args[i + 1]
            i += 2
        else:
            i += 1
    if not agent:
        sys.exit("missing --agent")
    print(resolve_val(agent, "model", override))

elif cmd == "resolve-effort":
    agent = ""
    override = ""
    cls_hint = ""
    i = 1
    while i < len(args):
        if args[i] == "--agent" and i + 1 < len(args):
            agent = args[i + 1]
            i += 2
        elif args[i] == "--effort" and i + 1 < len(args):
            override = args[i + 1]
            i += 2
        elif args[i] == "--class" and i + 1 < len(args):
            cls_hint = args[i + 1]
            i += 2
        else:
            i += 1
    res = resolve_val(agent, "effort", override)
    if not res and cls_hint:
        res = CLASS_EFFORTS.get(cls_hint.lower(), "")
    print(res)

elif cmd == "sanitize-flags":
    agent = ""
    model = ""
    effort = ""
    i = 1
    while i < len(args):
        if args[i] == "--agent" and i + 1 < len(args):
            agent = args[i + 1]
            i += 2
        elif args[i] == "--model" and i + 1 < len(args):
            model = args[i + 1]
            i += 2
        elif args[i] == "--effort" and i + 1 < len(args):
            effort = args[i + 1]
            i += 2
        else:
            i += 1

    if not agent:
        sys.exit("missing --agent")

    final_model = resolve_val(agent, "model", model)
    final_effort = effort

    # Agent specific rules
    if agent == "cursor":
        # Cursor encodes effort in model ID; strip effort flag
        final_effort = ""
    elif agent == "antigravity":
        # Antigravity requires --model when --effort is passed
        if final_effort and not final_model:
            final_model = resolve_val(agent, "model")

    parts = [f"--agent {agent}"]
    if final_model:
        parts.append(f"--model {final_model}")
    if final_effort:
        parts.append(f"--effort {final_effort}")
    print(" ".join(parts))

else:
    print("wdd-config: set <agent.key> <val> | get <agent.key> | list | resolve-model | resolve-effort | sanitize-flags")
PY
