#!/bin/bash
# Test suite for hooks/check-update.sh
# Run: bash tests/test-check-update.sh
#
# Mocks `gh` to control version comparison without network access.
# Sets CLAUDE_PLUGIN_ROOT to a fake plugin directory with a known version.

PLUGIN_ROOT="$(dirname "$0")/../claude"
CHECK_UPDATE="$PLUGIN_ROOT/hooks/check-update.sh"
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

# Create a mock bin directory and a fake plugin root
MOCK_BIN=$(mktemp -d)
FAKE_PLUGIN_ROOT=$(mktemp -d)
ORIGINAL_PATH="$PATH"

# Create fake plugin.json with version 1.0.0
mkdir -p "$FAKE_PLUGIN_ROOT/.claude-plugin"
echo '{"version":"1.0.0"}' > "$FAKE_PLUGIN_ROOT/.claude-plugin/plugin.json"

cleanup() {
  rm -rf "$MOCK_BIN" "$FAKE_PLUGIN_ROOT"
  export PATH="$ORIGINAL_PATH"
}
trap cleanup EXIT

# ========================================================================
echo ""
echo "check-update.sh — versions match (no output)"
echo "------------------------------------------------------------------------"

# Mock gh to return matching version in the expected format
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo 'acme-engineering-v1.0.0'
MOCK
chmod +x "$MOCK_BIN/gh"

export PATH="$MOCK_BIN:$ORIGINAL_PATH"

OUTPUT=$(env CLAUDE_PLUGIN_ROOT="$FAKE_PLUGIN_ROOT" bash "$CHECK_UPDATE" 2>&1)
EXIT_CODE=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE"
expect_true "No output when versions match" "$([ -z "$OUTPUT" ] && echo true || echo false)" "Output: $OUTPUT"

# ========================================================================
echo ""
echo "check-update.sh — update available (outputs JSON)"
echo "------------------------------------------------------------------------"

# Mock gh to return a newer version
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo 'acme-engineering-v2.0.0'
MOCK
chmod +x "$MOCK_BIN/gh"

OUTPUT2=$(env CLAUDE_PLUGIN_ROOT="$FAKE_PLUGIN_ROOT" bash "$CHECK_UPDATE" 2>&1)
EXIT_CODE2=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE2" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE2"

# Should produce output
if [ -n "$OUTPUT2" ]; then
  expect_true "Produces output when update available" "true"
else
  expect_true "Produces output when update available" "false" "No output produced"
fi

# Output should be valid JSON
if echo "$OUTPUT2" | jq '.' >/dev/null 2>&1; then
  expect_true "Output is valid JSON" "true"
else
  expect_true "Output is valid JSON" "false" "Output: $OUTPUT2"
fi

# Should mention both versions
if echo "$OUTPUT2" | grep -q '1.0.0'; then
  expect_true "Output mentions current version" "true"
else
  expect_true "Output mentions current version" "false" "Output: $OUTPUT2"
fi

if echo "$OUTPUT2" | grep -q '2.0.0'; then
  expect_true "Output mentions latest version" "true"
else
  expect_true "Output mentions latest version" "false" "Output: $OUTPUT2"
fi

# ========================================================================
echo ""
echo "check-update.sh — latest older than current (no output)"
echo "------------------------------------------------------------------------"

# Mock gh to return an older version than installed
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo 'acme-engineering-v0.9.0'
MOCK
chmod +x "$MOCK_BIN/gh"

OUTPUT_OLD=$(env CLAUDE_PLUGIN_ROOT="$FAKE_PLUGIN_ROOT" bash "$CHECK_UPDATE" 2>&1)
EXIT_CODE_OLD=$?

expect_true "Exit code is 0" "$([ "$EXIT_CODE_OLD" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE_OLD"
expect_true "No output when latest is older than current" "$([ -z "$OUTPUT_OLD" ] && echo true || echo false)" "Output: $OUTPUT_OLD"

# ========================================================================
echo ""
echo "check-update.sh — gh not available"
echo "------------------------------------------------------------------------"

# Create a gh that fails
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "$MOCK_BIN/gh"

OUTPUT3=$(env CLAUDE_PLUGIN_ROOT="$FAKE_PLUGIN_ROOT" bash "$CHECK_UPDATE" 2>&1)
EXIT_CODE3=$?

expect_true "Exit code is 0 when gh fails" "$([ "$EXIT_CODE3" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE3"
expect_true "No output when gh fails" "$([ -z "$OUTPUT3" ] && echo true || echo false)" "Output: $OUTPUT3"

# ========================================================================
echo ""
echo "check-update.sh — no plugin.json in cache"
echo "------------------------------------------------------------------------"

# Restore working gh mock
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo 'acme-engineering-v2.0.0'
MOCK
chmod +x "$MOCK_BIN/gh"

# Use a fake plugin root with no plugin.json
EMPTY_ROOT=$(mktemp -d)

OUTPUT4=$(env CLAUDE_PLUGIN_ROOT="$EMPTY_ROOT" bash "$CHECK_UPDATE" 2>&1)
EXIT_CODE4=$?

expect_true "Exit code is 0 with no plugin.json" "$([ "$EXIT_CODE4" -eq 0 ] && echo true || echo false)" "Got exit $EXIT_CODE4"
expect_true "No output with no plugin.json" "$([ -z "$OUTPUT4" ] && echo true || echo false)" "Output: $OUTPUT4"

rm -rf "$EMPTY_ROOT"

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
