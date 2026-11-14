#!/usr/bin/env bash
# ==============================================================================
# install.sh - Install Superpowers-Orca Skills into Agent Environment
# ==============================================================================
# Usage:
#   ./scripts/install.sh [--global | --local | --help]
#
# Options:
#   --global (default)  Install to ~/.agents/skills (shared by Orca, Codex, Claude, etc.)
#   --local             Install to ./.agents/skills (current project only)
#   --copy              Copy files instead of creating symbolic links
#   --uninstall         Remove installed Superpowers skills from target
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

MODE="global"
USE_SYMLINK=true
UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      MODE="global"
      shift
      ;;
    --local)
      MODE="local"
      shift
      ;;
    --copy)
      USE_SYMLINK=false
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--global | --local | --copy | --uninstall]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ "$MODE" = "global" ]; then
  TARGET_DIR="$HOME/.agents/skills"
else
  TARGET_DIR="$REPO_ROOT/.agents/skills"
fi

if [ "$UNINSTALL" = true ]; then
  echo "Uninstalling Superpowers-Orca skills from $TARGET_DIR..."
  if [ -d "$TARGET_DIR" ]; then
    for skill_path in "$SKILLS_SRC"/*; do
      [ -d "$skill_path" ] || continue
      skill_name="$(basename "$skill_path")"
      dest="$TARGET_DIR/$skill_name"
      if [ -L "$dest" ] || [ -d "$dest" ]; then
        rm -rf "$dest"
        echo "  - Removed $skill_name"
      fi
    done
  fi
  echo "Uninstall complete."
  exit 0
fi

echo "Installing Superpowers-Orca skills to: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

count=0
for skill_path in "$SKILLS_SRC"/*; do
  [ -d "$skill_path" ] || continue
  skill_name="$(basename "$skill_path")"
  dest="$TARGET_DIR/$skill_name"

  # Remove existing link or directory if present
  if [ -L "$dest" ] || [ -d "$dest" ]; then
    rm -rf "$dest"
  fi

  if [ "$USE_SYMLINK" = true ]; then
    ln -s "$skill_path" "$dest"
  else
    cp -R "$skill_path" "$dest"
  fi

  count=$((count + 1))
done

echo ""
echo "Successfully installed $count skills to $TARGET_DIR:"
echo "  - worker-driven-development (Orca DAG & Supervised Workers)"
echo "  - orca-decision-gates (Non-blocking gate-create / gate-resolve)"
echo "  - cross-agent-review (Heterogeneous model review)"
echo "  - using-orca-worktrees (Orca native child worktrees)"
echo "  - dispatching-parallel-workers (Parallel execution without conflicts)"
echo "  - Plus all core disciplines: TDD, brainstorming, systematic debugging, etc."
echo ""
echo "Orca and universal agent sessions will now automatically recognize these skills."
