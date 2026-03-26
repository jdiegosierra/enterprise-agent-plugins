#!/bin/bash
# setup-opencode-agents.sh — Symlink plugin agents into opencode's config directory.
#
# Creates symlinks from ~/.config/opencode/agents/ pointing to the agent
# files in this repo. Run after cloning or syncing the repo so opencode
# discovers the agents automatically.
#
# Usage:
#   bash setup-opencode-agents.sh [repo-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_AGENTS="${1:-$SCRIPT_DIR/../opencode/agents}"
REPO_AGENTS="$(cd "$REPO_AGENTS" && pwd)"

OPENCODE_AGENTS="${HOME}/.config/opencode/agents"

mkdir -p "$OPENCODE_AGENTS"

created=0
updated=0
skipped=0

for agent in "$REPO_AGENTS"/*.md; do
  [ -f "$agent" ] || continue
  name="$(basename "$agent")"
  target="$OPENCODE_AGENTS/$name"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$agent" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ -L "$target" ] || [ -e "$target" ]; then
    rm "$target"
    updated=$((updated + 1))
  else
    created=$((created + 1))
  fi

  ln -s "$agent" "$target"
done

echo "opencode agents: ${created} created, ${updated} updated, ${skipped} unchanged"
echo "source: $REPO_AGENTS"
echo "target: $OPENCODE_AGENTS"
