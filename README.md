# Enterprise Agent Plugins

A scaffold for building **multi-platform AI coding agent plugins** that work across Claude Code, opencode, and OpenClaw. Use this as a starting point for your own enterprise engineering plugins.

This repository demonstrates a production-ready plugin architecture where `src/` is the single source of truth, and each AI platform reads from it via symlinks.

## Quick start

Pick your platform — you only need to install on the one(s) you use.

### Claude Code

```bash
# From a Claude Code session:
/plugin marketplace add jdiegosierra/enterprise-agent-plugins
/plugin install acme-engineering@jdiegosierra-enterprise-agent-plugins
```

Updates are automatic — Claude Code checks for new versions on each session start.

Test locally without installing:

```bash
claude --plugin-dir ./plugins/acme-engineering/claude
```

### opencode

```bash
# 1. Clone the repo
git clone https://github.com/jdiegosierra/enterprise-agent-plugins.git ~/repos/enterprise-agent-plugins

# 2. Run the setup script to symlink agents into opencode's config
bash ~/repos/enterprise-agent-plugins/plugins/acme-engineering/scripts/setup-opencode-agents.sh

# 3. Verify agents are registered
ls -la ~/.config/opencode/agents/
```

Updates: `git pull` in the repo and re-run the setup script.

### OpenClaw

OpenClaw loads skills via `extraDirs` in `openclaw.json`. Point it to the `src/skills/` directory (not `openclaw/skills/` — OpenClaw doesn't resolve symlinks inside extraDirs).

```bash
# 1. Clone the repo into the OpenClaw workspace
git clone https://github.com/jdiegosierra/enterprise-agent-plugins.git /path/to/repos/enterprise-agent-plugins

# 2. Add to openclaw.json
cat <<EOF >> /dev/null
Add this to your openclaw.json under "skills.load":
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
EOF

# 3. Restart OpenClaw (or wait — watch mode picks up changes automatically)
```

Updates: `git pull` in the repo. With `watch: true`, OpenClaw detects changes automatically.

## What's included

The `acme-engineering` plugin is a fully functional example with:

- **2 agents** — SRE (infrastructure, runbooks) and backend-developer (PRs, testing)
- **4 commands** — help, setup, lint-fix, run-tests
- **3 skills** — platform map, Kubernetes best practices, SRE runbook executor
- **1 runbook** — GitHub access provisioning (end-to-end: Jira ticket to PR)
- **6 hooks** — bash safety guard, welcome message, session rules, update checker, onboarding, notifications
- **Multi-platform support** — Claude Code, opencode, and OpenClaw with symlinks

## Architecture

```
enterprise-agent-plugins/
├── .claude-plugin/marketplace.json     # Claude Code marketplace definition
├── release-please-config.json          # Automated versioning
├── .release-please-manifest.json
├── .github/workflows/                  # CI/CD
│   └── release-please.yml
└── plugins/
    └── acme-engineering/               # One plugin per department
        ├── src/                        # Source of truth — all content lives here
        │   ├── agents/                 # Agent definitions (markdown + YAML frontmatter)
        │   ├── commands/               # Slash commands
        │   ├── skills/                 # Knowledge bases (SKILL.md per topic)
        │   └── runbooks/              # Operational procedures
        ├── claude/                     # Claude Code plugin root (symlinks to src/)
        │   ├── .claude-plugin/        # Plugin manifest
        │   ├── agents/                # → src/agents/
        │   ├── commands/              # → src/commands/
        │   ├── skills/                # → src/skills/
        │   └── hooks/                 # Lifecycle hooks (bash scripts)
        ├── opencode/                  # opencode agents (symlinks to src/)
        │   └── agents/
        ├── openclaw/                  # OpenClaw skills (symlinks to src/)
        │   └── skills/
        ├── scripts/                   # Setup and utility scripts
        └── tests/                     # Hook and integrity tests
```

### Platform hierarchy

**Claude Code and opencode are at the same level** — both are coding tools. Everything implemented for Claude Code should be implemented for opencode so teams can choose either tool.

**OpenClaw is at a higher level** — it's a gateway/orchestrator that receives requests (Slack, Jira) and delegates coding work to opencode.

```
                    OpenClaw (gateway/orchestrator)
                    ├── Receives Slack DMs, Jira tickets
                    ├── Triages requests
                    └── Delegates coding work ↓

        ┌───────────────────┬───────────────────┐
        │   Claude Code     │     opencode       │
        │   (local CLI)     │   (server runtime) │
        ├───────────────────┼───────────────────┤
        │ agents            │ agents             │
        │ skills            │ (via file read)    │
        │ commands          │ (via prompt)       │
        │ hooks             │ plugins (.ts)      │
        │ marketplace       │ symlinks + setup   │
        └───────────────────┴───────────────────┘
```

### How it works

1. **Content lives in `src/`** — agents, skills, commands, and runbooks are plain markdown files
2. **Each platform has its own directory** with symlinks pointing to `src/`
3. **Claude Code** discovers content via the marketplace (`.claude-plugin/marketplace.json` points to `claude/`)
4. **opencode** uses symlinks from `~/.config/opencode/agents/` (created by `scripts/setup-opencode-agents.sh`)
5. **OpenClaw** loads skills via `extraDirs` in `openclaw.json` (points directly to `src/skills/` — OpenClaw doesn't resolve symlinks)

### Versioning

Only Claude Code has formal versioning via release-please. opencode and OpenClaw load files directly from `git pull`.

## Customizing for your organization

1. **Fork this repo** or use it as a template
2. **Rename** `acme-engineering` to `<your-org>-engineering` everywhere:
   - `plugins/acme-engineering/` directory
   - `.claude-plugin/marketplace.json`
   - `release-please-config.json` and `.release-please-manifest.json`
   - `plugins/acme-engineering/claude/.claude-plugin/plugin.json`
   - All hook scripts and command files that reference `acme-engineering`
3. **Replace placeholder content**:
   - `acme-platform` skill → your org's repository inventory and service map
   - `github-access.md` runbook → your actual provisioning steps
   - AWS profiles, team names, Jira project keys → your real values
4. **Add your skills** — create `src/skills/<topic>/SKILL.md` and symlink in `claude/skills/`
5. **Add your agents** — create `src/agents/<role>.md` and symlink in `claude/agents/`

## Key concepts

### Agents

Markdown files with YAML frontmatter that define specialized roles. Each agent has:
- A description (used for routing)
- Available commands and skills
- Core workflows
- Safety rules

### Skills

Knowledge bases that agents consult. Each skill is a directory with a `SKILL.md` file. Skills are loaded on-demand (2% of context window), so they scale well.

### Runbooks

Step-by-step operational procedures stored as plain markdown. Unlike skills (which are reference knowledge), runbooks are executable instructions. Agents have routing tables that map trigger keywords to runbook files.

**Why not commands?** Commands load their description at session start. With hundreds of runbooks, this would consume too much context budget. Runbooks are loaded on-demand when triggered.

### Hooks

Lifecycle scripts that run on events:
- **SessionStart** — welcome messages, update checks, onboarding, session rules
- **PreToolUse** — safety guards that intercept dangerous commands
- **Stop** — notifications when tasks complete

### Multi-platform symlinks

Git preserves symlinks. When Claude Code clones the repo via marketplace install, symlinks in `claude/` resolve to `src/` correctly. This means one source of truth, zero duplication.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
