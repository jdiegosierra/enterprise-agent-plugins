# acme-engineering

Acme Corp's Engineering plugin for Claude Code. Developer tools, standards, and integrations.

## What's included

### Agents

| Agent | Description |
|-------|-------------|
| `sre` | Infrastructure, K8s ops, monitoring, incidents, runbook execution |
| `backend-developer` | PRs, lint, test for Go/Python services |
| `frontend-developer` | PRs, lint, test for TypeScript/React/Vue projects |

### Commands

| Command | Description |
|---------|-------------|
| `/acme-engineering:help` | Show everything the plugin can do |
| `/acme-engineering:setup` | Interactive setup wizard |
| `/acme-engineering:lint-fix` | Auto-fix linting issues |
| `/acme-engineering:run-tests` | Run the project test suite |

### Skills

| Skill | Description |
|-------|-------------|
| `acme-platform` | Repository inventory, microservice architecture, service dependencies |
| `kubernetes` | K8s cluster management, RBAC, workloads, troubleshooting |
| `sre-runbook` | SRE runbook executor for operational tasks |

### Hooks

| Event | Description |
|-------|-------------|
| SessionStart | Welcome message with available agents, commands, and skills |
| SessionStart | Update check — notifies if a newer plugin version is available |
| SessionStart | Onboarding — detects pending setup items |
| SessionStart | Session rules — language, CLI preference, development guidelines |
| PreToolUse | Bash safety guard — blocks destructive CLI operations |
| Stop | Desktop notification when task completes |

## Installation

Inside a Claude Code session:

```
/plugin marketplace add jdiegosierra/enterprise-agent-plugins
/plugin install acme-engineering@jdiegosierra-enterprise-agent-plugins
```

Start a new session and run `/acme-engineering:setup` to configure your environment.

## Project structure

```
acme-engineering/
├── src/                               # Source of truth
│   ├── agents/
│   │   ├── sre.md                     # Claude Code SRE agent
│   │   ├── sre.opencode.md            # opencode SRE agent
│   │   ├── backend-developer.md       # Go/Python PR workflow
│   │   └── frontend-developer.md      # TypeScript/React/Vue PR workflow
│   ├── skills/
│   │   ├── acme-platform/             # Repository inventory and architecture
│   │   ├── kubernetes/                # K8s best practices
│   │   └── sre-runbook/              # SRE runbook executor
│   ├── commands/
│   │   ├── help.md                    # Plugin reference
│   │   ├── setup.md                   # Setup wizard
│   │   ├── lint-fix.md               # Linter autofix
│   │   └── run-tests.md             # Test runner
│   └── runbooks/
│       └── sre/
│           └── github-access.md       # Grant GitHub org access
├── claude/                            # Claude Code plugin root (symlinks to src/)
│   ├── .claude-plugin/plugin.json
│   ├── agents/                        # → src/agents/
│   ├── skills/                        # → src/skills/
│   ├── commands/                      # → src/commands/
│   ├── hooks/                         # Lifecycle hooks
│   ├── AGENTS.md
│   └── CLAUDE.md → AGENTS.md
├── opencode/                          # opencode agents (symlinks to src/)
│   └── agents/
│       └── sre.md → src/agents/sre.opencode.md
├── openclaw/                          # OpenClaw skills (symlinks to src/)
│   └── skills/
│       └── sre-runbook → src/skills/sre-runbook
├── runbooks → src/runbooks            # Shared runbooks (symlink)
├── scripts/
│   └── setup-opencode-agents.sh       # Symlink opencode agents
└── README.md
```

## Multi-platform architecture

See the [root README](../../README.md) for the full multi-platform architecture documentation.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md).
