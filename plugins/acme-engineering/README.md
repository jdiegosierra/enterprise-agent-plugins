# acme-engineering

Acme Corp's Engineering plugin for Claude Code, opencode, and OpenClaw. Developer tools, standards, and integrations.

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

Pick your platform — you only need to install on the one(s) you use.

### Claude Code

```bash
# From a Claude Code session:
/plugin marketplace add jdiegosierra/enterprise-agent-plugins
/plugin install acme-engineering@jdiegosierra-enterprise-agent-plugins
```

Start a new session and run `/acme-engineering:setup` to configure your environment.

### opencode

```bash
# 1. Clone the repo
git clone https://github.com/jdiegosierra/enterprise-agent-plugins.git ~/repos/enterprise-agent-plugins

# 2. Symlink agents into opencode's config directory
bash ~/repos/enterprise-agent-plugins/plugins/acme-engineering/scripts/setup-opencode-agents.sh

# 3. Use an agent
opencode run --agent sre "describe the current cluster state"
```

### OpenClaw

Add the skills directory to `openclaw.json` under `skills.load.extraDirs`:

```json
{
  "skills": {
    "load": {
      "extraDirs": [
        "/path/to/repos/enterprise-agent-plugins/plugins/acme-engineering/src/skills"
      ],
      "watch": true
    }
  }
}
```

Point `extraDirs` to `src/skills/` directly — OpenClaw does not resolve symlinks inside extraDirs.

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
