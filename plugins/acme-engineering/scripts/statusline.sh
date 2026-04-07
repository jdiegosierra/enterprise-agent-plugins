#!/usr/bin/env bash
# Maisa default statusline for Claude Code
# Line 1: model (effort) · project · git branch · context usage · [session name]
# Line 2: plugin version [update hint] · claude code version [update hint]
#
# Installed by /acme-engineering:setup into ~/.claude/settings.json
# Users can customise this script freely after installation.

input=$(cat)

# ── Pastel 256-color palette ─────────────────────────────────────────────────
reset="\e[0m"
pastel_blue="\e[38;5;153m"      # soft sky blue
pastel_green="\e[38;5;157m"     # mint green
pastel_purple="\e[38;5;183m"    # lavender
pastel_pink="\e[38;5;218m"      # rose pink
pastel_yellow="\e[38;5;229m"    # butter yellow
pastel_orange="\e[38;5;216m"    # pastel orange
pastel_dim="\e[38;5;245m"       # muted grey
highlight_bg="\e[48;5;228m\e[38;5;0m"  # yellow background, black text

sep="${pastel_dim} · ${reset}"

# ── Semver comparison ──────────────────────────────────────────────────────
# Returns 0 (true) if $1 is strictly greater than $2 using semantic versioning.
version_gt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# ── Extract fields from JSON ─────────────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // "unknown model"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
session_name=$(echo "$input" | jq -r '.session_name // empty')
cc_version=$(echo "$input" | jq -r '.version // empty')

# ── Git branch ───────────────────────────────────────────────────────────────
git_branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir/.git" ]; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$project_dir" symbolic-ref --short HEAD 2>/dev/null \
               || GIT_OPTIONAL_LOCKS=0 git -C "$project_dir" rev-parse --short HEAD 2>/dev/null)
fi

# ── Project name ─────────────────────────────────────────────────────────────
project_name=""
if [ -n "$project_dir" ]; then
  project_name=$(basename "$project_dir")
fi

# ── Context usage ────────────────────────────────────────────────────────────
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_str=""
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  context_str="${pastel_yellow}ctx ${used_int}%${reset}"
fi

# ── Effort level (from settings.json) ────────────────────────────────────────
effort=""
if [ -f "$HOME/.claude/settings.json" ]; then
  effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

# ── Maisa plugin version ────────────────────────────────────────────────────
plugin_version=""
plugin_name=""
_installed="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$_installed" ]; then
  plugin_version=$(jq -r '.plugins["acme-engineering@your-org-enterprise-agent-plugins"][0].version // empty' "$_installed" 2>/dev/null)
  if [ -n "$plugin_version" ]; then
    plugin_json="$HOME/.claude/plugins/cache/your-org-enterprise-agent-plugins/acme-engineering/${plugin_version}/.claude-plugin/plugin.json"
    if [ -f "$plugin_json" ]; then
      plugin_name=$(jq -r '.name // empty' "$plugin_json")
    else
      plugin_name="acme-engineering"
    fi
  fi
fi

# ── Session label ────────────────────────────────────────────────────────────
session_label=""
if [ -n "$session_name" ]; then
  session_label="${pastel_dim}[${session_name}]${reset}"
fi

# ── Version cache (refreshed by check-update.sh on SessionStart) ─────────────
CACHE_FILE="$HOME/.claude/.statusline-version-cache.json"

# Read cached latest versions
latest_plugin=""
latest_cc=""
if [ -f "$CACHE_FILE" ]; then
  latest_plugin=$(jq -r '.latest_plugin // empty' "$CACHE_FILE" 2>/dev/null)
  latest_cc=$(jq -r '.latest_cc // empty' "$CACHE_FILE" 2>/dev/null)
fi

# ── Assemble line 1 ─────────────────────────────────────────────────────────
line1="${pastel_purple}${model}${reset}"

if [ -n "$effort" ]; then
  line1+=" ${pastel_purple}(${effort})${reset}"
fi

if [ -n "$project_name" ]; then
  line1+="${sep}${pastel_blue}${project_name}${reset}"
fi

if [ -n "$git_branch" ]; then
  line1+="${sep}${pastel_green}${git_branch}${reset}"
fi

if [ -n "$context_str" ]; then
  line1+="${sep}${context_str}"
fi

if [ -n "$session_label" ]; then
  line1+="${sep}${session_label}"
fi

# ── Assemble line 2 ─────────────────────────────────────────────────────────
line2=""
if [ -n "$plugin_version" ]; then
  line2="${pastel_pink}${plugin_name} v${plugin_version}${reset}"
  if [ -n "$latest_plugin" ] && version_gt "$latest_plugin" "$plugin_version"; then
    line2+=" ${highlight_bg} v${latest_plugin} available ${reset}"
  fi
else
  line2="${pastel_dim}plugin not found${reset}"
fi

if [ -n "$cc_version" ]; then
  line2+="${sep}${pastel_orange}claude code v${cc_version}${reset}"
  if [ -n "$latest_cc" ] && version_gt "$latest_cc" "$cc_version"; then
    line2+=" ${highlight_bg} v${latest_cc} available ${reset}"
  fi
fi

# ── Print ────────────────────────────────────────────────────────────────────
printf "%b\n%b\n" "$line1" "$line2"
