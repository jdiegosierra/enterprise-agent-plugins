# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this repo is

A coding agent plugin (`acme-engineering`) that provides Acme Corp's developer tools: CLI integrations, agents, commands, skills, and hooks. Compatible with Claude Code, opencode, and OpenClaw.

## Architecture

This is a **coding agent plugin**, not a traditional application. There is no build step, no dependencies to install. The "code" is markdown files and JSON configs that the host tool loads at runtime.

| Directory | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest — name, version, metadata |
| `agents/` | Subagent definitions (markdown with YAML frontmatter) |
| `commands/` | Slash commands invoked via `/acme-engineering:<name>` |
| `skills/` | Knowledge bases (each is a folder with `SKILL.md`) |
| `hooks/` | Lifecycle hooks (JSON config for PreToolUse, SessionStart, etc.) |

### Agents

| Agent | File | Purpose |
|-------|------|---------|
| `sre` | `agents/sre.md` | Infrastructure, K8s ops, monitoring, incidents, runbook execution |
| `backend-developer` | `agents/backend-developer.md` | PRs, lint, test for Go/Python services |
| `frontend-developer` | `agents/frontend-developer.md` | PRs, lint, test for TypeScript/React/Vue |

## Commit conventions

This repo uses **Conventional Commits**. Release-please parses them for version bumps.

- `feat:` → minor bump
- `fix:` → patch bump
- `feat!:` or `BREAKING CHANGE` → major bump

## When modifying this plugin

### How to add resources

All content lives in `src/` at the plugin root (`plugins/acme-engineering/src/`). The `claude/`, `opencode/`, and `openclaw/` directories contain symlinks — do not edit files there directly.

- **Adding a command**: Create `src/commands/<name>.md` with YAML frontmatter. Add a symlink in `claude/commands/`.
- **Adding a skill**: Create `src/skills/<name>/SKILL.md` with YAML frontmatter. Add a symlink in `claude/skills/`.
- **Adding an agent**: Create `src/agents/<name>.md` with YAML frontmatter. Add a symlink in `claude/agents/`.
- **Adding a hook**: Edit `claude/hooks/hooks.json` and add the hook script.
- **Adding a runbook**: Create `src/runbooks/<agent>/<name>.md`. Update the agent's runbook table.

### Change propagation

| What changed | Files to update |
|---|---|
| **Agent added/removed** | `src/agents/<name>.md`, symlink in `claude/agents/`, `claude/hooks/welcome.sh`, `claude/AGENTS.md`, `README.md` |
| **Command added/removed** | `src/commands/<name>.md`, symlink in `claude/commands/`, `src/commands/help.md`, `claude/AGENTS.md`, `README.md` |
| **Skill added/removed** | `src/skills/<name>/SKILL.md`, symlink in `claude/skills/`, agent files that reference it, `README.md` |
| **Hook added/removed** | `claude/hooks/hooks.json`, hook script, `claude/AGENTS.md`, `README.md` |
| **Runbook added/removed** | `src/runbooks/<agent>/<name>.md`, update agent runbook table |
