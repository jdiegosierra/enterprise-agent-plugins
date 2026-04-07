---
name: uninstall
description: Remove all Maisa plugin state and uninstall cleanly
audience: employee
---

You must guide the user through a clean uninstall of the Maisa plugin. This removes all plugin-generated files and settings, then tells the user how to remove the plugin itself.

## Steps

### 1. Detect plugin state

Scan for all state the plugin may have created. Check each item silently (no output yet):

**Files in `~/.claude/`:**

| File | How to detect |
|------|---------------|
| `.acme-welcomed-*` | `ls ~/.claude/.acme-welcomed-* 2>/dev/null` |
| `.acme-setup.json` | `test -f ~/.claude/.acme-setup.json` |
| `.acme-notify-config.json` | `test -f ~/.claude/.acme-notify-config.json` |
| `.acme-admin` | `test -f ~/.claude/.acme-admin` |

**Plugin cache (all versions):**

Claude Code caches multiple plugin versions under `~/.claude/plugins/cache/your-org-enterprise-agent-plugins/acme-engineering/`. Each version contains bundled MCPs, hooks, agents, and skills that persist even after `claude plugin uninstall`. List cached versions:

```bash
ls ~/.claude/plugins/cache/your-org-enterprise-agent-plugins/acme-engineering/ 2>/dev/null
```

**Legacy MCP keys in `~/.claude/settings.json`:**

| Key | How to detect |
|-----|---------------|
| `mcpServers["acme:github"]` | `jq -e '.mcpServers["acme:github"]' ~/.claude/settings.json 2>/dev/null` |
| `mcpServers["acme:documentdb"]` | `jq -e '.mcpServers["acme:documentdb"]' ~/.claude/settings.json 2>/dev/null` |
| `mcpServers["acme:kubernetes"]` | `jq -e '.mcpServers["acme:kubernetes"]' ~/.claude/settings.json 2>/dev/null` |
| `mcpServers["acme:drawio"]` | `jq -e '.mcpServers["acme:drawio"]' ~/.claude/settings.json 2>/dev/null` |

**MCPs in `~/.claude.json`:**

| MCP | How to detect |
|-----|---------------|
| `acme-drawio` | `claude mcp get acme-drawio 2>/dev/null` |
| `acme-playwright` | `claude mcp get acme-playwright 2>/dev/null` |

**Legacy MCPs (from old MCP-first approach):**

| MCP | How to detect |
|-----|---------------|
| `acme-github` | `claude mcp get acme-github 2>/dev/null` |
| `acme-documentdb` | `claude mcp get acme-documentdb 2>/dev/null` |
| `acme-kubernetes` | `claude mcp get acme-kubernetes 2>/dev/null` |

### 2. Show what will be removed

Display a clear summary of everything that was detected. Only list items that actually exist — skip items that aren't present.

Format:

```
## Maisa plugin state detected

**Files:**
- ~/.claude/.acme-welcomed-0.X.Y
- ~/.claude/.acme-setup.json
- ~/.claude/.acme-notify-config.json

**Plugin cache:**
- ~/.claude/plugins/cache/your-org-enterprise-agent-plugins/ (3 cached versions)

**Settings (in ~/.claude/settings.json):**
- mcpServers["acme:drawio"]

**MCPs (in ~/.claude.json):**
- acme-drawio
```

If nothing is detected, tell the user there's no plugin state to clean up and they can just run the uninstall command directly (skip to step 5).

### 3. Ask for confirmation

Use `AskUserQuestion` with a single yes/no question:

> This will remove all the items listed above. Proceed?

Options: **Yes, remove everything** / **Cancel**

If the user cancels, stop immediately with a message that nothing was changed.

### 4. Clean up

Perform the cleanup in this order:

#### 4a. Clean `~/.claude/settings.json`

Read the current file, then use `jq` to produce the cleaned version in a single pass:

1. Remove all `acme:*` keys from `mcpServers` — use `jq` with `del(.mcpServers["acme:github"], .mcpServers["acme:documentdb"], .mcpServers["acme:kubernetes"], .mcpServers["acme:drawio"])`
2. If `mcpServers` is now empty (`{}`), remove the `mcpServers` key entirely

Write the result back to `~/.claude/settings.json`. **Preserve all other settings unchanged.**

Use a single `jq` pipeline to do all removals atomically. Write to a temp file first, then move it into place to avoid corruption. Always remove stale `.tmp` files before writing to avoid `file exists` errors from a previous failed attempt.

```bash
rm -f ~/.claude/settings.json.tmp
jq '
  del(.mcpServers["acme:github"], .mcpServers["acme:documentdb"], .mcpServers["acme:kubernetes"], .mcpServers["acme:drawio"])
  | if (.mcpServers | length) == 0 then del(.mcpServers) else . end
' ~/.claude/settings.json > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

#### 4b. Remove MCPs from `~/.claude.json`

Remove the Draw.io MCP and any legacy MCPs that may still be registered:

```bash
claude mcp remove -s user "acme-drawio" 2>/dev/null
claude mcp remove -s user "acme-playwright" 2>/dev/null
claude mcp remove -s user "acme-github" 2>/dev/null
claude mcp remove -s user "acme-documentdb" 2>/dev/null
claude mcp remove -s user "acme-kubernetes" 2>/dev/null
```

Run these sequentially. Each command is safe to run even if the MCP doesn't exist — the `2>/dev/null` suppresses "not found" errors.

#### 4c. Delete plugin cache

Remove the entire plugin cache directory. This eliminates all cached versions along with their bundled MCPs, hooks, agents, and skills:

```bash
rm -rf ~/.claude/plugins/cache/your-org-enterprise-agent-plugins
```

This is safe because the user is uninstalling the plugin. Without the cache, Claude Code cannot load any bundled resources from previous versions.

#### 4d. Delete plugin files

```bash
rm -f ~/.claude/.acme-welcomed-* ~/.claude/.acme-setup.json ~/.claude/.acme-notify-config.json ~/.claude/.acme-admin
```

#### 4e. Remove ai-commit git alias

If the global `git ci` alias points to `ai-commit`, remove it:

```bash
if git config --global alias.ci 2>/dev/null | grep -q "ai-commit"; then
  git config --global --unset alias.ci
fi
```

Only remove the alias if it contains `ai-commit` — leave it alone if the user has a custom `ci` alias.

#### 4f. Show results

After cleanup, confirm what was removed with a brief summary.

### 5. Tell the user to uninstall the plugin

The plugin itself cannot be uninstalled from within the current session because it's currently loaded. Tell the user:

> To complete the uninstall, run this command **in a new Claude Code session** or from the terminal:
>
> ```
> claude plugin uninstall acme-engineering@your-org-enterprise-agent-plugins
> ```
>
> This removes the plugin code itself. The cleanup above already removed all configuration and state files.

## Important

- **Never delete `~/.claude/settings.json`** — only remove specific keys. The file contains other settings the user needs.
- **Never touch `~/.aws/config`** — AWS CLI profiles are shared infrastructure and may be used by other tools. Only clean up plugin-specific state.
- **Atomic writes** — always write to a temp file and `mv` into place to avoid leaving a corrupt `settings.json` if something fails mid-write.
