#!/bin/bash
# Check for plugin updates — runs on SessionStart
# Exit 0 always — informational only, never blocks session

LATEST=$(gh release list --repo jdiegosierra/enterprise-agent-plugins --limit 20 --json tagName -q '.[].tagName' 2>/dev/null | grep '^acme-engineering-v' | head -1 | sed 's/^acme-engineering-v//')

if [ -z "$LATEST" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CURRENT=$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)

if [ -z "$CURRENT" ]; then
  exit 0
fi

# Only notify when LATEST is strictly greater than CURRENT (semver)
version_gt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

if version_gt "$LATEST" "$CURRENT"; then
  MSG="Plugin update available: v${CURRENT} → v${LATEST}."
  CONTEXT="IMPORTANT: Inform the user once that an acme-engineering plugin update is available (v${CURRENT} → v${LATEST})."
  echo "{\"systemMessage\":\"${MSG}\",\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"${CONTEXT}\"}}"
fi

exit 0
