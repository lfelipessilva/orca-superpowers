#!/usr/bin/env bash
# Dynamic, low-token model listing (queries local CLI or brief fallback).
# Usage: list-models.sh [--agent NAME] [--ids-only]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AGENT=""
IDS_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="${2:?}"; shift 2 ;;
    --ids-only) IDS_ONLY=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--agent antigravity|cursor|claude|codex|opencode] [--ids-only]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

python3 - "$AGENT" "$IDS_ONLY" <<'PY'
import shutil, subprocess, sys
from pathlib import Path

agent = sys.argv[1].lower().strip()
ids_only = sys.argv[2] == "1"

FALLBACK_MODELS = {
    "antigravity": [
        "gemini-3.8-flash",
        "gemini-3.8-flash-high",
        "gemini-3.8-flash-medium",
        "gemini-3.8-flash-low",
        "claude-sonnet-4-6",
        "claude-opus-4-6-thinking",
        "gpt-oss-120b-medium"
    ],
    "cursor": [
        "composer-2.5-fast",
        "composer-2.5",
        "gpt-5.3-codex-high",
        "gpt-5.3-codex-fast",
        "claude-opus-5-thinking-high",
        "auto"
    ],
    "claude": [
        "sonnet",
        "opus",
        "haiku",
        "claude-sonnet-4-6",
        "claude-opus-4-6",
        "claude-haiku-4-5"
    ],
    "codex": [
        "gpt-5.3-codex",
        "gpt-5.2",
        "gpt-5.1-codex"
    ],
    "opencode": [
        "auto",
        "claude-3-7-sonnet",
        "gpt-4o"
    ]
}

def get_live_models(ag: str):
    if ag == "antigravity" and shutil.which("agy"):
        try:
            out = subprocess.check_output(["agy", "models"], text=True, stderr=subprocess.DEVNULL)
            models = []
            for line in out.splitlines():
                parts = line.strip().split("\t")
                if parts and parts[0] and not parts[0].startswith("Fetching"):
                    models.append(parts[0])
            if models:
                return models[:15]
        except Exception:
            pass
    elif ag == "cursor" and shutil.which("agent"):
        try:
            out = subprocess.check_output(["agent", "models"], text=True, stderr=subprocess.DEVNULL)
            models = []
            for line in out.splitlines()[2:]:
                p = line.strip().split()
                if p and p[0] and p[0] != "Available":
                    models.append(p[0])
            if models:
                return models[:15]
        except Exception:
            pass
    return FALLBACK_MODELS.get(ag, [])

agents_to_query = [agent] if agent else list(FALLBACK_MODELS.keys())

for ag in agents_to_query:
    models = get_live_models(ag)
    if not models:
        models = FALLBACK_MODELS.get(ag, [])
    if ids_only:
        for m in models:
            print(m)
    else:
        print(f"{ag} (--agent {ag})  models={len(models)}")
        for m in models:
            print(f"  {m}")
PY
