#!/usr/bin/env bash
set -euo pipefail

# Usage: setup-opencode-plugin.sh [PLUGIN_ROOT] [--audience bot|employee]
#
# --audience bot       Link only bot + all skills (for EC2 bot deployment)
# --audience employee  Link only employee + all skills (default for local dev)
# No --audience flag   Link only employee + all skills (same as employee)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POSITIONAL_ARGS=()
AUDIENCE="employee"

while [[ $# -gt 0 ]]; do
  case $1 in
    --audience)
      AUDIENCE="$2"
      shift 2
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

PLUGIN_ROOT="${POSITIONAL_ARGS[0]:-$SCRIPT_DIR/..}"
PLUGIN_ROOT="$(cd "$PLUGIN_ROOT" && pwd)"

OPENCODE_ROOT="${HOME}/.config/opencode"
PLUGIN_LINK="$OPENCODE_ROOT/acme-engineering"

mkdir -p "$OPENCODE_ROOT/agents" "$OPENCODE_ROOT/commands" "$OPENCODE_ROOT/skills" "$OPENCODE_ROOT/plugins"

link_path() {
  local source="$1"
  local target="$2"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -s "$source" "$target"
}

# Read the audience field from a SKILL.md frontmatter.
# Returns "bot", "employee", or "all" (default if field is missing).
get_skill_audience() {
  local skill_path="$1"
  local skill_md=""

  # Resolve the SKILL.md — it may be a directory (with SKILL.md inside) or a symlink to one
  if [ -d "$skill_path" ]; then
    skill_md="$skill_path/SKILL.md"
  elif [ -f "$skill_path/SKILL.md" ]; then
    skill_md="$skill_path/SKILL.md"
  else
    echo "all"
    return
  fi

  [ -f "$skill_md" ] || { echo "all"; return; }

  # Read audience from YAML frontmatter (between first two --- lines)
  local value
  value=$(awk '/^---$/{n++; next} n==1 && /^audience:/{print $2; exit}' "$skill_md" 2>/dev/null)
  echo "${value:-all}"
}

# Check if a skill should be linked for the current audience.
# A skill matches if: skill_audience == "all", or skill_audience == target_audience
should_link_skill() {
  local skill_audience="$1"
  local target_audience="$2"

  if [ "$skill_audience" = "all" ]; then
    return 0
  fi
  if [ "$skill_audience" = "$target_audience" ]; then
    return 0
  fi
  return 1
}

link_path "$PLUGIN_ROOT" "$PLUGIN_LINK"

for agent in "$PLUGIN_ROOT"/opencode/agents/*.md; do
  [ -f "$agent" ] || continue
  link_path "$agent" "$OPENCODE_ROOT/agents/$(basename "$agent")"
done

for command in "$PLUGIN_ROOT"/opencode/commands/*.md; do
  [ -f "$command" ] || continue
  link_path "$command" "$OPENCODE_ROOT/commands/$(basename "$command")"
done

# Skills: filter by audience using src/skills/*/SKILL.md metadata
linked=0
skipped=0
for skill in "$PLUGIN_ROOT"/src/skills/*; do
  [ -d "$skill" ] || continue
  skill_name="$(basename "$skill")"
  skill_audience="$(get_skill_audience "$skill")"

  if should_link_skill "$skill_audience" "$AUDIENCE"; then
    link_path "$skill" "$OPENCODE_ROOT/skills/$skill_name"
    linked=$((linked + 1))
  else
    # Remove stale symlink if audience no longer matches
    target="$OPENCODE_ROOT/skills/$skill_name"
    if [ -L "$target" ] || [ -e "$target" ]; then
      rm -rf "$target"
      skipped=$((skipped + 1))
    else
      skipped=$((skipped + 1))
    fi
  fi
done

for plugin in "$PLUGIN_ROOT"/opencode/plugins/*; do
  [ -f "$plugin" ] || continue
  link_path "$plugin" "$OPENCODE_ROOT/plugins/$(basename "$plugin")"
done

echo "OpenCode plugin root: $PLUGIN_ROOT"
echo "OpenCode config root: $OPENCODE_ROOT"
echo "Audience: $AUDIENCE"
echo "Linked install root: $PLUGIN_LINK -> $(readlink "$PLUGIN_LINK")"
echo "Agents linked: $(ls -1 "$PLUGIN_ROOT/opencode/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "Commands linked: $(ls -1 "$PLUGIN_ROOT/opencode/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "Skills linked: $linked (skipped: $skipped)"
echo "Plugins linked: $(ls -1 "$PLUGIN_ROOT/opencode/plugins" 2>/dev/null | wc -l | tr -d ' ')"
