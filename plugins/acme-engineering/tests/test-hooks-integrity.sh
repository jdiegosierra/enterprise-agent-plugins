#!/bin/bash
# Test suite for plugin structural integrity
# Run: bash tests/test-hooks-integrity.sh
#
# Validates that all plugin resources are consistent:
# - hooks.json is valid JSON and all referenced scripts exist
# - Agent files have valid YAML frontmatter
# - Skill directories contain SKILL.md
# - plugin.json is valid and has required fields

PLUGIN_ROOT="$(dirname "$0")/../claude"
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
echo "hooks.json validation"
echo "------------------------------------------------------------------------"

HOOKS_FILE="$PLUGIN_ROOT/hooks/hooks.json"

# Valid JSON
if jq '.' "$HOOKS_FILE" >/dev/null 2>&1; then
  expect_true "hooks.json is valid JSON" "true"
else
  expect_true "hooks.json is valid JSON" "false" "jq parse failed"
fi

# Has expected top-level keys
for event in SessionStart PreToolUse Stop; do
  if jq -e ".hooks.$event" "$HOOKS_FILE" >/dev/null 2>&1; then
    expect_true "hooks.json has $event event" "true"
  else
    expect_true "hooks.json has $event event" "false"
  fi
done

# All referenced scripts in hook commands exist on disk
echo ""
echo "Hook script references"
echo "------------------------------------------------------------------------"

# Extract script paths from hook commands that reference bash scripts
# Pattern: bash "${CLAUDE_PLUGIN_ROOT}/hooks/some-script.sh" or bash "path/to/script.sh"
SCRIPT_REFS=$(jq -r '
  [.hooks[][] | .hooks[]? | .command // empty]
  | map(capture("bash\\s+\"?\\$\\{CLAUDE_PLUGIN_ROOT\\}/(?<path>[^\"\\s]+)\"?") | .path)
  | .[]
' "$HOOKS_FILE" 2>/dev/null)

if [ -n "$SCRIPT_REFS" ]; then
  while IFS= read -r ref; do
    full_path="$PLUGIN_ROOT/$ref"
    if [ -f "$full_path" ]; then
      expect_true "Referenced script exists: $ref" "true"
    else
      expect_true "Referenced script exists: $ref" "false" "File not found: $full_path"
    fi
  done <<< "$SCRIPT_REFS"
else
  expect_true "Found script references in hooks.json" "false" "No script references extracted"
fi

# ========================================================================
echo ""
echo "Agent files validation"
echo "------------------------------------------------------------------------"

for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
  [ -f "$agent_file" ] || continue
  basename=$(basename "$agent_file")

  # Check YAML frontmatter exists (starts with ---)
  first_line=$(head -1 "$agent_file")
  if [ "$first_line" = "---" ]; then
    expect_true "Agent $basename has YAML frontmatter" "true"
  else
    expect_true "Agent $basename has YAML frontmatter" "false" "First line: $first_line"
    continue
  fi

  # Check frontmatter has 'name' field
  # Extract frontmatter (between first and second ---)
  frontmatter=$(sed -n '2,/^---$/p' "$agent_file" | sed '$d')
  if echo "$frontmatter" | grep -qE '^name:'; then
    expect_true "Agent $basename has 'name' field" "true"
  else
    expect_true "Agent $basename has 'name' field" "false"
  fi

  # Check frontmatter has 'description' field
  if echo "$frontmatter" | grep -qE '^description:'; then
    expect_true "Agent $basename has 'description' field" "true"
  else
    expect_true "Agent $basename has 'description' field" "false"
  fi
done

# ========================================================================
echo ""
echo "Skill directories validation"
echo "------------------------------------------------------------------------"

for skill_dir in "$PLUGIN_ROOT"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")

  if [ -f "$skill_dir/SKILL.md" ]; then
    expect_true "Skill $skill_name has SKILL.md" "true"
  else
    expect_true "Skill $skill_name has SKILL.md" "false"
  fi
done

# ========================================================================
echo ""
echo "plugin.json validation"
echo "------------------------------------------------------------------------"

PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

if jq '.' "$PLUGIN_JSON" >/dev/null 2>&1; then
  expect_true "plugin.json is valid JSON" "true"
else
  expect_true "plugin.json is valid JSON" "false" "jq parse failed"
fi

if jq -e '.name' "$PLUGIN_JSON" >/dev/null 2>&1; then
  expect_true "plugin.json has 'name' field" "true"
else
  expect_true "plugin.json has 'name' field" "false"
fi

if jq -e '.version' "$PLUGIN_JSON" >/dev/null 2>&1; then
  expect_true "plugin.json has 'version' field" "true"
else
  expect_true "plugin.json has 'version' field" "false"
fi

# ========================================================================
echo ""
echo "Command files validation"
echo "------------------------------------------------------------------------"

for cmd_file in "$PLUGIN_ROOT"/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  basename=$(basename "$cmd_file")

  # Check YAML frontmatter exists
  first_line=$(head -1 "$cmd_file")
  if [ "$first_line" = "---" ]; then
    expect_true "Command $basename has YAML frontmatter" "true"
  else
    expect_true "Command $basename has YAML frontmatter" "false" "First line: $first_line"
    continue
  fi

  # Check frontmatter has 'description' field
  frontmatter=$(sed -n '2,/^---$/p' "$cmd_file" | sed '$d')
  if echo "$frontmatter" | grep -qE '^description:'; then
    expect_true "Command $basename has 'description' field" "true"
  else
    expect_true "Command $basename has 'description' field" "false"
  fi
done

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
