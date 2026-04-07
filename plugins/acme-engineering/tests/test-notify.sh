#!/bin/bash
# Test suite for hooks/notify.sh
# Run: bash tests/test-notify.sh
#
# Uses a fake HOME and mocked commands to isolate state.
# Overrides PATH to prevent actual desktop notifications.

PLUGIN_ROOT="$(dirname "$0")/../claude"
NOTIFY="$PLUGIN_ROOT/hooks/notify.sh"
PASS=0
FAIL=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[0;90m'
RESET='\033[0m'

expect_true() {
  local desc="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))

  if [ "$result" = "true" ]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${RESET} %s\n" "$desc"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${RESET} %s\n" "$desc"
    [ -n "$3" ] && printf "       ${DIM}%s${RESET}\n" "$3"
  fi
}

# Create mock bin directory with no-op notification commands
# This prevents tests from actually sending desktop notifications
MOCK_BIN=$(mktemp -d)
cat > "$MOCK_BIN/terminal-notifier" << 'MOCK'
#!/bin/bash
# Mock: record arguments instead of sending notification
echo "NOTIFIED: $*" >> "${MOCK_NOTIFY_LOG:-/dev/null}"
MOCK
chmod +x "$MOCK_BIN/terminal-notifier"

# Also mock osascript and notify-send so they don't fire
for cmd in osascript notify-send; do
  cat > "$MOCK_BIN/$cmd" << 'MOCK'
#!/bin/bash
echo "NOTIFIED: $*" >> "${MOCK_NOTIFY_LOG:-/dev/null}"
MOCK
  chmod +x "$MOCK_BIN/$cmd"
done

# Prepend mock bin to PATH so mocks are found first
ORIGINAL_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

cleanup() {
  rm -rf "$MOCK_BIN" "$TMPDIR_N"
  export PATH="$ORIGINAL_PATH"
}
trap cleanup EXIT

TMPDIR_N=$(mktemp -d)

# ========================================================================
echo ""
echo "notify.sh — stop_hook_active=true (skip)"
echo "------------------------------------------------------------------------"

OUTPUT=$(echo '{"stop_hook_active":true,"cwd":"/tmp/project"}' | env HOME="$TMPDIR_N" bash "$NOTIFY" 2>&1)
EXIT_CODE=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"
expect_true "No notification when stop_hook_active" "$([ -z "$OUTPUT" ] && echo true || echo false)" "Output: $OUTPUT"

# ========================================================================
echo ""
echo "notify.sh — desktop channel with project name"
echo "------------------------------------------------------------------------"

mkdir -p "$TMPDIR_N/.claude"
echo '{"channels":["desktop"]}' > "$TMPDIR_N/.claude/.acme-notify-config.json"

NOTIFY_LOG="$TMPDIR_N/notify.log"
export MOCK_NOTIFY_LOG="$NOTIFY_LOG"

echo '{"cwd":"/home/user/projects/my-awesome-app"}' | env HOME="$TMPDIR_N" bash "$NOTIFY" 2>&1
EXIT_CODE=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"

# Check notification was "sent" (logged by mock)
if [ -f "$NOTIFY_LOG" ]; then
  LOGGED=$(cat "$NOTIFY_LOG")
  # Should contain the project name
  if echo "$LOGGED" | grep -q "my-awesome-app"; then
    expect_true "Notification includes project name" "true"
  else
    expect_true "Notification includes project name" "false" "Logged: $LOGGED"
  fi
else
  expect_true "Notification includes project name" "false" "No notification log found"
fi

rm -f "$NOTIFY_LOG"

# ========================================================================
echo ""
echo "notify.sh — no config file (defaults to desktop)"
echo "------------------------------------------------------------------------"

TMPDIR_D=$(mktemp -d)
NOTIFY_LOG2="$TMPDIR_D/notify.log"
export MOCK_NOTIFY_LOG="$NOTIFY_LOG2"

echo '{"cwd":"/tmp/test-project"}' | env HOME="$TMPDIR_D" bash "$NOTIFY" 2>&1
EXIT_CODE=$?

expect_true "Exit code is 0 (no config)" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"

# Should still send a notification (default channel is desktop)
if [ -f "$NOTIFY_LOG2" ]; then
  expect_true "Sends notification with default config" "true"
else
  expect_true "Sends notification with default config" "false" "No notification log"
fi

rm -rf "$TMPDIR_D"

# ========================================================================
echo ""
echo "notify.sh — topic extraction from transcript"
echo "------------------------------------------------------------------------"

TMPDIR_T=$(mktemp -d)
mkdir -p "$TMPDIR_T/.claude"
echo '{"channels":["desktop"]}' > "$TMPDIR_T/.claude/.acme-notify-config.json"

# Create a fake transcript JSONL
TRANSCRIPT="$TMPDIR_T/transcript.jsonl"
echo '{"type":"user","message":{"content":"Fix the login bug in auth service"}}' > "$TRANSCRIPT"
echo '{"type":"assistant","message":{"content":"Sure, I will fix it"}}' >> "$TRANSCRIPT"

NOTIFY_LOG3="$TMPDIR_T/notify.log"
export MOCK_NOTIFY_LOG="$NOTIFY_LOG3"

echo "{\"cwd\":\"/tmp/my-project\",\"transcript_path\":\"$TRANSCRIPT\"}" | env HOME="$TMPDIR_T" bash "$NOTIFY" 2>&1

if [ -f "$NOTIFY_LOG3" ]; then
  LOGGED3=$(cat "$NOTIFY_LOG3")
  if echo "$LOGGED3" | grep -q "Fix the login bug"; then
    expect_true "Topic extracted from transcript" "true"
  else
    expect_true "Topic extracted from transcript" "false" "Logged: $LOGGED3"
  fi
else
  expect_true "Topic extracted from transcript" "false" "No notification log"
fi

rm -rf "$TMPDIR_T"

# ========================================================================
echo ""
echo "notify.sh — long topic truncation (>80 chars)"
echo "------------------------------------------------------------------------"

TMPDIR_L=$(mktemp -d)
mkdir -p "$TMPDIR_L/.claude"
echo '{"channels":["desktop"]}' > "$TMPDIR_L/.claude/.acme-notify-config.json"

# Create transcript with a very long message (120+ chars)
LONG_MSG="This is a very long message that exceeds eighty characters and should be truncated by the notification hook to fit in a notification bubble nicely"
TRANSCRIPT_L="$TMPDIR_L/transcript.jsonl"
echo "{\"type\":\"user\",\"message\":{\"content\":\"$LONG_MSG\"}}" > "$TRANSCRIPT_L"

NOTIFY_LOG4="$TMPDIR_L/notify.log"
export MOCK_NOTIFY_LOG="$NOTIFY_LOG4"

echo "{\"cwd\":\"/tmp/proj\",\"transcript_path\":\"$TRANSCRIPT_L\"}" | env HOME="$TMPDIR_L" bash "$NOTIFY" 2>&1

if [ -f "$NOTIFY_LOG4" ]; then
  LOGGED4=$(cat "$NOTIFY_LOG4")
  # Should contain "..." indicating truncation
  if echo "$LOGGED4" | grep -q '\.\.\.'; then
    expect_true "Long topic is truncated with ..." "true"
  else
    expect_true "Long topic is truncated with ..." "false" "Logged: $LOGGED4"
  fi
  # Should NOT contain the full message
  if echo "$LOGGED4" | grep -q "notification bubble nicely"; then
    expect_true "Full long message is NOT present" "false" "Full message found — not truncated"
  else
    expect_true "Full long message is NOT present" "true"
  fi
else
  expect_true "Long topic is truncated with ..." "false" "No notification log"
  expect_true "Full long message is NOT present" "false" "No notification log"
fi

rm -rf "$TMPDIR_L"

# ========================================================================
echo ""
echo "notify.sh — only slack channel (no desktop)"
echo "------------------------------------------------------------------------"

TMPDIR_S=$(mktemp -d)
mkdir -p "$TMPDIR_S/.claude"
echo '{"channels":["slack"]}' > "$TMPDIR_S/.claude/.acme-notify-config.json"

NOTIFY_LOG5="$TMPDIR_S/notify.log"
export MOCK_NOTIFY_LOG="$NOTIFY_LOG5"

echo '{"cwd":"/tmp/proj"}' | env HOME="$TMPDIR_S" bash "$NOTIFY" 2>&1
EXIT_CODE_S=$?

expect_true "Exit code is 0 (slack only)" "$([ "$EXIT_CODE_S" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE_S"

# Should NOT send a desktop notification (desktop not in channels)
if [ -f "$NOTIFY_LOG5" ]; then
  expect_true "No desktop notification for slack-only config" "false" "Desktop notification was sent"
else
  expect_true "No desktop notification for slack-only config" "true"
fi

rm -rf "$TMPDIR_S"

# ========================================================================
echo ""
echo "========================================================================"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}All %d tests passed${RESET}\n" "$TOTAL"
else
  printf "${RED}%d/%d tests failed${RESET}\n" "$FAIL" "$TOTAL"
fi
echo "========================================================================"
echo ""
exit "$FAIL"
