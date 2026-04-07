#!/bin/bash
# Test suite for shared project-context loading

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

echo ""
echo "Project context"
echo "------------------------------------------------------------------------"

TMP_DIR="$(mktemp -d)"
HOME_DIR="$TMP_DIR/home"
WORK_DIR="$TMP_DIR/work"
mkdir -p "$HOME_DIR" "$WORK_DIR"

MODULE_RESULTS=$(MODULE_PATH="$PLUGIN_ROOT/src/runtime/common.ts" TEST_DIR="$WORK_DIR" node --disable-warning=ExperimentalWarning --experimental-strip-types --input-type=module <<'NODE'
import fs from 'node:fs';
const moduleUrl = `file://${process.env.MODULE_PATH}`;
const { readProjectInstruction, buildOpenCodeProjectContextText } = await import(moduleUrl);
const dir = process.env.TEST_DIR;

fs.writeFileSync(`${dir}/AGENTS.md`, '# Repo rules\nUse AGENTS first.\n');
fs.writeFileSync(`${dir}/CLAUDE.md`, '# Claude rules\nUse CLAUDE second.\n');
const first = readProjectInstruction(dir);

fs.unlinkSync(`${dir}/AGENTS.md`);
const second = readProjectInstruction(dir);
const openCodeText = buildOpenCodeProjectContextText(dir);

fs.unlinkSync(`${dir}/CLAUDE.md`);
const none = readProjectInstruction(dir);

console.log(JSON.stringify({
  prefersAgents: first?.filePath.endsWith('AGENTS.md') && first?.content.includes('Use AGENTS first.'),
  fallsBackToClaude: second?.filePath.endsWith('CLAUDE.md') && second?.content.includes('Use CLAUDE second.'),
  openCodeContextIncludesFileName: Boolean(openCodeText && openCodeText.includes('CLAUDE.md') && openCodeText.includes('Use CLAUDE second.')),
  returnsNullWithoutFile: none === null,
}));
NODE
)

expect_true "Prefers AGENTS.md when both files exist" "$(echo "$MODULE_RESULTS" | jq -r '.prefersAgents')"
expect_true "Falls back to CLAUDE.md when AGENTS.md is missing" "$(echo "$MODULE_RESULTS" | jq -r '.fallsBackToClaude')"
expect_true "OpenCode project context text includes file name and content" "$(echo "$MODULE_RESULTS" | jq -r '.openCodeContextIncludesFileName')"
expect_true "Returns null when no project instruction file exists" "$(echo "$MODULE_RESULTS" | jq -r '.returnsNullWithoutFile')"

printf '# Repo rules\nKeep this repo synced.\n' > "$WORK_DIR/AGENTS.md"
CLAUDE_OUTPUT=$(cd "$WORK_DIR" && HOME="$HOME_DIR" bash "$PLUGIN_ROOT/claude/hooks/project-context.sh")

if [ -n "$CLAUDE_OUTPUT" ] && echo "$CLAUDE_OUTPUT" | jq '.' >/dev/null 2>&1; then
  expect_true "Claude project-context hook returns valid JSON" "true"
else
  expect_true "Claude project-context hook returns valid JSON" "false" "$CLAUDE_OUTPUT"
fi

if echo "$CLAUDE_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'Keep this repo synced.'; then
  expect_true "Claude project-context hook includes repo instructions" "true"
else
  expect_true "Claude project-context hook includes repo instructions" "false"
fi

rm -rf "$TMP_DIR"

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
