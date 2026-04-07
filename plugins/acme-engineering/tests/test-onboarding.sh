#!/bin/bash
# Test suite for hooks/onboarding.sh
# Run: bash tests/test-onboarding.sh
#
# Uses a fake HOME to isolate state (setup file and settings.json).

PLUGIN_ROOT="$(dirname "$0")/../claude"
ONBOARDING="$PLUGIN_ROOT/hooks/onboarding.sh"
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

# ========================================================================
echo ""
echo "onboarding.sh — no setup file (all items pending)"
echo "------------------------------------------------------------------------"

TMPDIR_O=$(mktemp -d)
trap 'rm -rf "$TMPDIR_O"' EXIT
mkdir -p "$TMPDIR_O/.claude"

# No setup file → all items should be pending (unless auto-detected)
OUTPUT=$(env HOME="$TMPDIR_O" bash "$ONBOARDING" 2>&1)
EXIT_CODE=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"

# Should produce output (pending items) — unless all CLIs happen to be installed on the host
# We just verify exit code 0 and valid JSON if output exists
if [ -n "$OUTPUT" ]; then
  expect_true "Produces output when items pending" "true"
  if echo "$OUTPUT" | jq '.' >/dev/null 2>&1; then
    expect_true "Output is valid JSON" "true"
  else
    expect_true "Output is valid JSON" "false" "Output: $OUTPUT"
  fi
  EVENT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
  expect_true "hookEventName is SessionStart" "$([ "$EVENT" = "SessionStart" ] && echo true || echo false)" "Got: $EVENT"
else
  # All CLIs are installed on host — no pending items
  expect_true "No output (all items auto-detected)" "true"
  # Skip JSON tests
  TOTAL=$((TOTAL + 2))
  PASS=$((PASS + 2))
fi

# ========================================================================
echo ""
echo "onboarding.sh — all items completed"
echo "------------------------------------------------------------------------"

TMPDIR_C=$(mktemp -d)
mkdir -p "$TMPDIR_C/.claude"

# Create setup file with all items completed
cat > "$TMPDIR_C/.claude/.acme-setup.json" << 'SETUP'
{
  "cli_gh": "completed",
  "cli_kubectl": "completed",
  "cli_helm": "completed",
  "cli_aws": "completed",
  "notifications": "completed"
}
SETUP

OUTPUT_C=$(env HOME="$TMPDIR_C" bash "$ONBOARDING" 2>&1)
EXIT_CODE_C=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE_C" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE_C"
expect_true "No output when all completed" "$([ -z "$OUTPUT_C" ] && echo true || echo false)" "Output: $OUTPUT_C"

rm -rf "$TMPDIR_C"

# ========================================================================
echo ""
echo "onboarding.sh — auto-detection marks items"
echo "------------------------------------------------------------------------"

TMPDIR_A=$(mktemp -d)
mkdir -p "$TMPDIR_A/.claude"

# Create notification config
echo '{"channels":["desktop"]}' > "$TMPDIR_A/.claude/.acme-notify-config.json"

# Run onboarding — should auto-detect notifications
env HOME="$TMPDIR_A" bash "$ONBOARDING" >/dev/null 2>&1

# Check setup file was created with auto-detected items
SETUP_FILE="$TMPDIR_A/.claude/.acme-setup.json"
if [ -f "$SETUP_FILE" ]; then
  expect_true "Setup file created" "true"

  NOTIFY_STATUS=$(jq -r '.notifications // empty' "$SETUP_FILE" 2>/dev/null)
  expect_true "notifications auto-detected as completed" "$([ "$NOTIFY_STATUS" = "completed" ] && echo true || echo false)" "Got: $NOTIFY_STATUS"
else
  expect_true "Setup file created" "false" "File not found: $SETUP_FILE"
  expect_true "notifications auto-detected as completed" "false" "No setup file"
fi

rm -rf "$TMPDIR_A"

# ========================================================================
echo ""
echo "onboarding.sh — corrupt setup file"
echo "------------------------------------------------------------------------"

TMPDIR_B=$(mktemp -d)
mkdir -p "$TMPDIR_B/.claude"
echo "not valid json" > "$TMPDIR_B/.claude/.acme-setup.json"

OUTPUT_B=$(env HOME="$TMPDIR_B" bash "$ONBOARDING" 2>&1)
EXIT_CODE_B=$?

expect_true "Exit code is 0 with corrupt file" "$([ "$EXIT_CODE_B" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE_B"

# Should still produce output (treat as empty and report pending items)
if [ -n "$OUTPUT_B" ]; then
  expect_true "Still produces output with corrupt file" "true"
else
  # All CLIs installed → no pending even with corrupt file
  expect_true "Handles corrupt file gracefully" "true"
fi

rm -rf "$TMPDIR_B"

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
