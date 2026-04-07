#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# CLAUDE_PLUGIN_ROOT works in plugin cache (flattened layout); relative path works in source repo
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/src/runtime/claude-hooks.ts" ]; then
  RUNTIME="${CLAUDE_PLUGIN_ROOT}/src/runtime/claude-hooks.ts"
else
  RUNTIME="$SCRIPT_DIR/../../src/runtime/claude-hooks.ts"
fi

exec node --disable-warning=ExperimentalWarning --experimental-strip-types \
  "$RUNTIME" project-context
