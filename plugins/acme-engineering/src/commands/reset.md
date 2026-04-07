---
name: reset
description: Reset all plugin configuration to start fresh
audience: employee
---

You must guide the user through a configuration reset of the plugin. This removes all plugin-generated settings and state files so the user can reconfigure from scratch with `/acme-engineering:setup`. The plugin itself stays installed.

## Steps

### 1. Detect plugin state

Scan for all configuration state the plugin may have created. Check each item silently (no output yet):

**Files in `~/.claude/`:**

| File | How to detect |
|------|---------------|
| `.acme-welcomed-*` | `ls ~/.claude/.acme-welcomed-* 2>/dev/null` |
| `.acme-setup.json` | `test -f ~/.claude/.acme-setup.json` |
| `.acme-notify-config.json` | `test -f ~/.claude/.acme-notify-config.json` |

**Legacy MCP keys in `~/.claude/settings.json`:**

| Key | How to detect |
|-----|---------------|
| `mcpServers["acme:drawio"]` | `jq -e '.mcpServers["acme:drawio"]' ~/.claude/settings.json 2>/dev/null` |

**MCPs in `~/.claude.json`:**

| MCP | How to detect |
|-----|---------------|
| `acme-drawio` | `claude mcp get acme-drawio 2>/dev/null` |
| `acme-playwright` | `claude mcp get acme-playwright 2>/dev/null` |

### 2. Show what will be reset

Display a clear summary of everything that was detected. Only list items that actually exist — skip items that aren't present.

Format:

```
## Plugin configuration detected

**Files:**
- ~/.claude/.acme-welcomed-0.X.Y
- ~/.claude/.acme-setup.json
- ~/.claude/.acme-notify-config.json

**Settings (in ~/.claude/settings.json):**
- mcpServers["acme:drawio"]

**MCPs (in ~/.claude.json):**
- acme-drawio
```

If nothing is detected, tell the user there's no configuration to reset and suggest running `/acme-engineering:setup`.

### 3. Ask for confirmation

Use `AskUserQuestion` with a single yes/no question:

> This will remove all plugin configuration listed above. The plugin stays installed — you can reconfigure with `/acme-engineering:setup`. Proceed?

Options: **Yes, reset everything** / **Cancel**

If the user cancels, stop immediately with a message that nothing was changed.

### 4. Clean up

Perform the cleanup in this order:

#### 4a. Clean `~/.claude/settings.json`

Read the current file, then use `jq` to produce the cleaned version in a single pass:

1. Remove all `acme:*` keys from `mcpServers` — use `jq` with `del(.mcpServers["acme:drawio"])`
2. If `mcpServers` is now empty (`{}`), remove the `mcpServers` key entirely

Write the result back to `~/.claude/settings.json`. **Preserve all other settings unchanged.**

Use a single `jq` pipeline to do all removals atomically. Write to a temp file first, then move it into place to avoid corruption. Always remove stale `.tmp` files before writing to avoid `file exists` errors from a previous failed attempt.

```bash
rm -f ~/.claude/settings.json.tmp
jq '
  del(.mcpServers["acme:drawio"])
  | if (.mcpServers | length) == 0 then del(.mcpServers) else . end
' ~/.claude/settings.json > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

#### 4b. Remove MCPs from `~/.claude.json`

Remove any plugin-registered MCPs:

```bash
claude mcp remove -s user "acme-drawio" 2>/dev/null
claude mcp remove -s user "acme-playwright" 2>/dev/null
```

Run these sequentially. Each command is safe to run even if the MCP doesn't exist — the `2>/dev/null` suppresses "not found" errors.

#### 4c. Delete configuration files

```bash
rm -f ~/.claude/.acme-welcomed-* ~/.claude/.acme-setup.json ~/.claude/.acme-notify-config.json
```

#### 4d. Remove ai-commit git alias

If the global `git ci` alias points to `ai-commit`, remove it:

```bash
if git config --global alias.ci 2>/dev/null | grep -q "ai-commit"; then
  git config --global --unset alias.ci
fi
```

Only remove the alias if it contains `ai-commit` — leave it alone if the user has a custom `ci` alias.

#### 4e. Show results

After cleanup, confirm what was removed with a brief summary, then tell the user:

> **Restart Claude Code** for the changes to take effect. Then run `/acme-engineering:setup` to reconfigure your environment.

## Important

- **Never delete `~/.claude/settings.json`** — only remove specific keys. The file contains other settings the user needs.
- **Never touch `~/.aws/config`** — AWS CLI profiles are shared infrastructure and may be used by other tools.
- **Never delete the plugin cache** — the plugin must remain functional after reset.
- **Never delete `.acme-admin`** — it's an admin flag, not a user configuration.
- **Atomic writes** — always write to a temp file and `mv` into place to avoid leaving a corrupt `settings.json` if something fails mid-write.
