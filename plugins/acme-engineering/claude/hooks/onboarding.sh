#!/bin/bash
# Progressive onboarding — runs on SessionStart
# Checks ~/.claude/.acme-setup.json for pending setup items
# Auto-detects already-installed tools
# Exit 0 always — informational only, never blocks session

SETUP_FILE="$HOME/.claude/.acme-setup.json"

# Known setup items
ITEMS=("cli_gh" "cli_kubectl" "cli_helm" "cli_aws" "notifications")

# Load existing setup file or start empty
if [ -f "$SETUP_FILE" ]; then
  SETUP=$(jq '.' "$SETUP_FILE" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$SETUP" ]; then
    SETUP="{}"
  fi
else
  SETUP="{}"
fi

get_status() {
  echo "$SETUP" | jq -r --arg key "$1" '.[$key] // empty' 2>/dev/null
}

mark_item() {
  local key="$1" status="$2"
  SETUP=$(echo "$SETUP" | jq --arg key "$key" --arg status "$status" '.[$key] = $status')
  mkdir -p "$(dirname "$SETUP_FILE")"
  echo "$SETUP" | jq '.' > "$SETUP_FILE" 2>/dev/null
}

autodetect_cli() {
  command -v "$1" >/dev/null 2>&1
}

autodetect_notifications() {
  [ -f "$HOME/.claude/.acme-notify-config.json" ]
}

# Run auto-detection for items not yet in the setup file
for item in "${ITEMS[@]}"; do
  status=$(get_status "$item")
  [ -n "$status" ] && continue

  detected=false
  case "$item" in
    cli_gh)          autodetect_cli "gh" && detected=true ;;
    cli_kubectl)     autodetect_cli "kubectl" && detected=true ;;
    cli_helm)        autodetect_cli "helm" && detected=true ;;
    cli_aws)         autodetect_cli "aws" && detected=true ;;
    notifications)   autodetect_notifications && detected=true ;;
  esac

  if [ "$detected" = true ]; then
    mark_item "$item" "completed"
  fi
done

# Count remaining pending items
PENDING_COUNT=0
for item in "${ITEMS[@]}"; do
  status=$(get_status "$item")
  if [ -z "$status" ]; then
    PENDING_COUNT=$((PENDING_COUNT + 1))
  fi
done

# If nothing pending, exit silently
if [ "$PENDING_COUNT" -eq 0 ]; then
  exit 0
fi

CONTEXT="The Acme plugin has pending items to configure. Briefly suggest the user run /acme-engineering:setup to complete their setup. Keep it to one short sentence."

python3 -c "
import json, sys

context = sys.argv[1]
output = {
    'systemMessage': 'Acme plugin — pending setup items',
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}
print(json.dumps(output))
" "$CONTEXT"

exit 0
