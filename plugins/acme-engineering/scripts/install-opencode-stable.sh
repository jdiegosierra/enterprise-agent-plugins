#!/usr/bin/env bash
# install-opencode-stable.sh — Install a stable copy of enterprise-agent-plugins for local OpenCode usage.
#
# This avoids pointing ~/.config/opencode/acme-engineering at a working tree
# that changes when you switch branches locally.
#
# This is the recommended script for normal local installation and updates.
#
# Usage:
#   bash install-opencode-stable.sh [git-ref]
#
# If git-ref is omitted, the script installs the latest acme-engineering tag.
# If no matching tag exists, it falls back to origin/main.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEFAULT_REMOTE_URL="git@github.com:your-org/enterprise-agent-plugins.git"
STABLE_DIR="${HOME}/.local/share/enterprise-agent-plugins-stable"
TAG_PATTERN="acme-engineering-v*"

resolve_remote_url() {
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true
  fi
}

REMOTE_URL="$(resolve_remote_url)"
REMOTE_URL="${REMOTE_URL:-$DEFAULT_REMOTE_URL}"

if [ ! -d "$STABLE_DIR/.git" ]; then
  mkdir -p "$(dirname "$STABLE_DIR")"
  git clone "$REMOTE_URL" "$STABLE_DIR"
fi

git -C "$STABLE_DIR" fetch origin --tags --prune

TARGET_REF="${1:-}"
if [ -z "$TARGET_REF" ]; then
  TARGET_REF="$(git -C "$STABLE_DIR" tag --list "$TAG_PATTERN" --sort=-version:refname | head -n 1)"
fi
if [ -z "$TARGET_REF" ]; then
  TARGET_REF="origin/main"
fi

if [[ "$TARGET_REF" == origin/* ]]; then
  git -C "$STABLE_DIR" checkout -B main "$TARGET_REF"
else
  git -C "$STABLE_DIR" checkout --detach "$TARGET_REF"
fi

bash "$STABLE_DIR/plugins/acme-engineering/scripts/setup-opencode-plugin.sh" \
  "$STABLE_DIR/plugins/acme-engineering"

echo
echo "stable clone: $STABLE_DIR"
echo "installed ref: $(git -C "$STABLE_DIR" describe --tags --always --dirty)"
echo "install root target: $(readlink "$HOME/.config/opencode/acme-engineering")"
