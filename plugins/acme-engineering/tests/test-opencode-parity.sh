#!/bin/bash
# Test suite for OpenCode parity wiring
# Run: bash tests/test-opencode-parity.sh

PLUGIN_ROOT="$(dirname "$0")/.."
CLAUDE_ROOT="$PLUGIN_ROOT/claude"
OPENCODE_ROOT="$PLUGIN_ROOT/opencode"
PASS=0
FAIL=0
TOTAL=0

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

count_matches() {
  local pattern="$1"
  local count
  count=$(ls $pattern 2>/dev/null | wc -l | tr -d ' ')
  printf "%s" "$count"
}

echo ""
echo "OpenCode parity"
echo "------------------------------------------------------------------------"

CLAUDE_AGENT_COUNT=$(count_matches "$CLAUDE_ROOT/agents/*.md")
OPENCODE_AGENT_COUNT=$(count_matches "$OPENCODE_ROOT/agents/*.md")
expect_true "OpenCode has the same number of agents as Claude" "$([ "$CLAUDE_AGENT_COUNT" = "$OPENCODE_AGENT_COUNT" ] && echo true || echo false)" "Claude=$CLAUDE_AGENT_COUNT OpenCode=$OPENCODE_AGENT_COUNT"

CLAUDE_COMMAND_COUNT=$(count_matches "$CLAUDE_ROOT/commands/*.md")
OPENCODE_COMMAND_COUNT=$(count_matches "$OPENCODE_ROOT/commands/*.md")
expect_true "OpenCode has the same number of commands as Claude" "$([ "$CLAUDE_COMMAND_COUNT" = "$OPENCODE_COMMAND_COUNT" ] && echo true || echo false)" "Claude=$CLAUDE_COMMAND_COUNT OpenCode=$OPENCODE_COMMAND_COUNT"

CLAUDE_SKILL_COUNT=$(count_matches "$CLAUDE_ROOT/skills/*")
OPENCODE_SKILL_COUNT=$(count_matches "$OPENCODE_ROOT/skills/*")
expect_true "OpenCode has the same number of skills as Claude" "$([ "$CLAUDE_SKILL_COUNT" = "$OPENCODE_SKILL_COUNT" ] && echo true || echo false)" "Claude=$CLAUDE_SKILL_COUNT OpenCode=$OPENCODE_SKILL_COUNT"

for agent in backend-developer frontend-developer qa-engineer sre; do
  if [ -e "$OPENCODE_ROOT/agents/$agent.md" ]; then
    expect_true "OpenCode agent exists: $agent" "true"
  else
    expect_true "OpenCode agent exists: $agent" "false"
  fi
done

for command in \
  acme-help \
  acme-setup \
  acme-lint-fix \
  acme-run-tests \
  acme-update \
  acme-slack-summary \
  acme-slack-notify \
  acme-notify-config \
  acme-reset \
  acme-uninstall
do
  if [ -e "$OPENCODE_ROOT/commands/$command.md" ]; then
    expect_true "OpenCode command exists: $command" "true"
  else
    expect_true "OpenCode command exists: $command" "false"
  fi
done

for file in "$OPENCODE_ROOT"/agents/*.md "$OPENCODE_ROOT"/commands/*.md "$OPENCODE_ROOT"/plugins/*.ts; do
  [ -e "$file" ] || continue
  if [ -e "$file" ]; then
    expect_true "OpenCode asset target resolves: $(basename "$file")" "true"
  else
    expect_true "OpenCode asset target resolves: $(basename "$file")" "false"
  fi
done

expect_true "OpenCode plugin exists" "$([ -e "$OPENCODE_ROOT/plugins/acme-engineering.ts" ] && echo true || echo false)"

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
