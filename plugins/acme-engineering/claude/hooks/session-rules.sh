#!/bin/bash
# Session rules — runs on SessionStart
# Injects common rules that apply to ALL agents and the main conversation.
# Exit 0 always — informational only, never blocks session

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PLUGIN_VERSION=$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
SKILL_COUNT=$(ls -d "$PLUGIN_ROOT/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
[ -z "$SKILL_COUNT" ] || [ "$SKILL_COUNT" -eq 0 ] && SKILL_COUNT="many"
export ACME_PLUGIN_VERSION="$PLUGIN_VERSION"
export ACME_SKILL_COUNT="$SKILL_COUNT"

python3 << 'PYTHON_EOF'
import json, os

plugin_version = os.environ.get('ACME_PLUGIN_VERSION', 'unknown')
skill_count = os.environ.get('ACME_SKILL_COUNT', 'many')

context = '''IMPORTANT — these rules apply to ALL work in this session (main conversation and subagents).

## Acme Engineering Plugin (v$VERSION$)

The user has the `acme-engineering` plugin installed (source: `jdiegosierra/enterprise-agent-plugins`).

**Commands** (invoke via `/acme-engineering:<name>`): help, setup, lint-fix, run-tests

**Agents**: sre (infra, monitoring, incidents, runbooks), backend-developer (Go/Python, PRs), frontend-developer (TS/React/Vue)

**Skills**: $SKILLS$ skills — platform map, Kubernetes, SRE runbooks

## Language rule

All code artifacts must be in **English**: code comments, commit messages, PR titles/descriptions, variable/function names, documentation, log messages, error messages.

## CLI preference

**Always prefer CLI tools** over MCPs — they are faster and have the full API surface:
- **GitHub**: `gh`
- **Kubernetes**: `kubectl` and `helm`
- **AWS**: `aws` CLI

## Development guidelines

- **Always ask for explicit user confirmation before running git commit or git push.**
- Never push to main or master directly. Always work through PRs.
- **Always use squash merge** when merging PRs via `gh pr merge` — use the `--squash` flag.
- When in doubt about the base branch, ask the user.
- **Always sync before working on any project** — run `git fetch origin` and check if behind upstream.
- **Never use cd in Bash commands** — use absolute paths or tool flags (git -C, gh --repo).'''

context = context.replace('$VERSION$', plugin_version).replace('$SKILLS$', skill_count)

output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}

print(json.dumps(output))
PYTHON_EOF

exit 0
