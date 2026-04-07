#!/bin/bash
# Test suite for hooks/welcome.sh
# Run: bash tests/test-welcome.sh
#
# Uses a fake HOME and CLAUDE_PLUGIN_ROOT to isolate state.

PLUGIN_ROOT="$(dirname "$0")/../claude"
WELCOME="$PLUGIN_ROOT/hooks/welcome.sh"
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

# Get current version from plugin.json
CURRENT_VERSION=$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)

# ========================================================================
echo ""
echo "welcome.sh — first run (no marker file)"
echo "------------------------------------------------------------------------"

TMPDIR_W=$(mktemp -d)
trap 'rm -rf "$TMPDIR_W"' EXIT

# First run: should output JSON
OUTPUT=$(env HOME="$TMPDIR_W" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$WELCOME" 2>&1)
EXIT_CODE=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"

# Should produce output (JSON)
if [ -n "$OUTPUT" ]; then
  expect_true "Produces output on first run" "true"
else
  expect_true "Produces output on first run" "false" "No output produced"
fi

# Output should be valid JSON
if echo "$OUTPUT" | jq '.' >/dev/null 2>&1; then
  expect_true "Output is valid JSON" "true"
else
  expect_true "Output is valid JSON" "false" "Output: $OUTPUT"
fi

# JSON should contain hookSpecificOutput
if echo "$OUTPUT" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
  expect_true "JSON has hookSpecificOutput" "true"
else
  expect_true "JSON has hookSpecificOutput" "false"
fi

# hookSpecificOutput should have hookEventName = SessionStart
EVENT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
expect_true "hookEventName is SessionStart" "$([ "$EVENT" = "SessionStart" ] && echo true || echo false)" "Got: $EVENT"

# hookSpecificOutput should have additionalContext
if echo "$OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  expect_true "JSON has additionalContext" "true"
else
  expect_true "JSON has additionalContext" "false"
fi

# Should have systemMessage
if echo "$OUTPUT" | jq -e '.systemMessage' >/dev/null 2>&1; then
  expect_true "JSON has systemMessage" "true"
else
  expect_true "JSON has systemMessage" "false"
fi

# Marker file should be created
MARKER="$TMPDIR_W/.claude/.acme-welcomed-${CURRENT_VERSION}"
expect_true "Marker file created" "$([ -f "$MARKER" ] && echo true || echo false)" "Expected: $MARKER"

# ========================================================================
echo ""
echo "welcome.sh — second run (marker exists)"
echo "------------------------------------------------------------------------"

# Second run: should produce no output
OUTPUT2=$(env HOME="$TMPDIR_W" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$WELCOME" 2>&1)
EXIT_CODE2=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE2" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE2"
expect_true "No output on second run" "$([ -z "$OUTPUT2" ] && echo true || echo false)" "Output: $OUTPUT2"

# ========================================================================
echo ""
echo "welcome.sh — old marker cleanup"
echo "------------------------------------------------------------------------"

# Create fake old markers
TMPDIR_C=$(mktemp -d)
mkdir -p "$TMPDIR_C/.claude"
touch "$TMPDIR_C/.claude/.acme-welcomed-0.0.1"
touch "$TMPDIR_C/.claude/.acme-welcomed-0.0.2"
touch "$TMPDIR_C/.claude/.acme-welcomed-99.99.99"

# Run welcome (should create new marker and clean up old ones)
env HOME="$TMPDIR_C" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$WELCOME" >/dev/null 2>&1

# Old markers should be gone
expect_true "Old marker 0.0.1 removed" "$([ ! -f "$TMPDIR_C/.claude/.acme-welcomed-0.0.1" ] && echo true || echo false)"
expect_true "Old marker 0.0.2 removed" "$([ ! -f "$TMPDIR_C/.claude/.acme-welcomed-0.0.2" ] && echo true || echo false)"
expect_true "Old marker 99.99.99 removed" "$([ ! -f "$TMPDIR_C/.claude/.acme-welcomed-99.99.99" ] && echo true || echo false)"

# Current marker should exist
expect_true "Current marker created" "$([ -f "$TMPDIR_C/.claude/.acme-welcomed-${CURRENT_VERSION}" ] && echo true || echo false)"

rm -rf "$TMPDIR_C"

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
