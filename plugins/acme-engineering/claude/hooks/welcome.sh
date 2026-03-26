#!/bin/bash
# Welcome message for first-time users or after plugin update — runs on SessionStart
# Uses a version-stamped marker file to show only once per version
# Exit 0 always — informational only, never blocks session

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CURRENT_VERSION=$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)

if [ -z "$CURRENT_VERSION" ]; then
  exit 0
fi

SKILL_COUNT=$(ls -d "$PLUGIN_ROOT/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
[ -z "$SKILL_COUNT" ] || [ "$SKILL_COUNT" -eq 0 ] && SKILL_COUNT="many"

MARKER_DIR="$HOME/.claude"
MARKER_FILE="$MARKER_DIR/.acme-welcomed-${CURRENT_VERSION}"

# Already welcomed for this version
if [ -f "$MARKER_FILE" ]; then
  exit 0
fi

# Create marker so we don't show again
mkdir -p "$MARKER_DIR"
touch "$MARKER_FILE"

# Clean up old markers from previous versions
find "$MARKER_DIR" -name ".acme-welcomed-*" ! -name ".acme-welcomed-${CURRENT_VERSION}" -delete 2>/dev/null

# Generate properly escaped JSON output via Python
python3 -c "
import json

version = '$CURRENT_VERSION'
skill_count = '$SKILL_COUNT'

welcome = '''Welcome to the Acme engineering plugin v{version}!

The plugin includes specialized agents, {skill_count} skills, CLI safety guards, and commands to streamline your workflow.

Run \`/acme-engineering:setup\` to configure your environment:
- **CLI tools** — GitHub (gh), Kubernetes (kubectl/helm), AWS CLI
- **Notifications** — desktop alerts when long tasks finish

Type \`/acme-engineering:help\` to see everything the plugin can do.'''.format(version=version, skill_count=skill_count)

context = (
    'IMPORTANT: This is the user\\'s first session with the Acme plugin v{version}. '
    'Welcome them briefly and present the following guide:\\n\\n'
    '{welcome}'
).format(version=version, welcome=welcome)

output = {
    'systemMessage': f'Acme plugin v{version} installed — show welcome guide to user',
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}

print(json.dumps(output))
"

exit 0
