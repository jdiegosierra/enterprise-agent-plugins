#!/bin/bash
# Run all test suites
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for test in "$SCRIPT_DIR"/test-*.sh; do
  [ -f "$test" ] || continue
  name=$(basename "$test")
  echo "--- Running $name ---"
  if bash "$test"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAILED: $name"
  fi
  echo ""
done

echo "=== All suites: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
