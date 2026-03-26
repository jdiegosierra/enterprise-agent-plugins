#!/bin/bash
# Task-completion notification — runs on Stop hook
# Uses terminal-notifier if available, falls back to osascript (macOS) or notify-send (Linux)
#
# Configuration: ~/.claude/.acme-notify-config.json
#   - channels: ["desktop"] — which channels to notify

INPUT=$(cat)

# Prevent infinite loops if this hook triggers another Stop
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

# --- Read notification config ---
CONFIG_FILE="$HOME/.claude/.acme-notify-config.json"
if [ -f "$CONFIG_FILE" ]; then
  CHANNELS=$(jq -r '.channels // ["desktop"] | join(",")' "$CONFIG_FILE" 2>/dev/null)
else
  CHANNELS="desktop"
fi

[ -z "$CHANNELS" ] && exit 0
echo "$CHANNELS" | grep -q "desktop" || exit 0

# Extract project name from working directory
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
PROJECT=$(basename "${CWD:-$PWD}")

# Try to extract the first real user message as conversation topic
TOPIC=""
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  TOPIC=$(head -30 "$TRANSCRIPT" \
    | jq -r 'select(.type == "user")
      | .message.content
      | if type == "array" then map(select(.type == "text")) | .[0].text
        else .
        end
      // empty' 2>/dev/null \
    | grep -v '<command-' \
    | grep -v '^null$' \
    | grep -v '^\s*$' \
    | head -1)
  if [ "${#TOPIC}" -gt 80 ]; then
    TOPIC="${TOPIC:0:77}..."
  fi
fi

TITLE="Claude Code · $PROJECT"
if [ -n "$TOPIC" ]; then
  MESSAGE="$TOPIC"
else
  MESSAGE="Response complete"
fi

# Send desktop notification
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$TITLE" -message "$MESSAGE" -group "claude-$$-$(date +%s)"
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MESSAGE"
fi
