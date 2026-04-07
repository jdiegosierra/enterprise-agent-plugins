---
name: update
description: Check for acme-engineering plugin updates and install the latest version
audience: employee
---

You must check if there is a newer version of the acme-engineering plugin and update it if needed. This is a direct action.

## Steps

### 1. Sync the local marketplace

The plugin system resolves versions from the local marketplace clone. If this clone is stale, `claude plugin update` will reinstall the old version even when a newer release exists. Always sync before checking versions:

```bash
git -C "${HOME}/.claude/plugins/marketplaces/YOUR_ORG-enterprise-agent-plugins" fetch origin && git -C "${HOME}/.claude/plugins/marketplaces/YOUR_ORG-enterprise-agent-plugins" pull origin main
```

### 2. Get the current installed version

Read the plugin's own manifest:

```bash
jq -r .version "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
```

### 3. Get the latest available version

```bash
gh release list --repo YOUR_ORG/enterprise-agent-plugins --limit 20 --json tagName -q '.[].tagName' | grep '^acme-engineering-v' | head -1
```

Strip the `acme-engineering-v` prefix (e.g., `acme-engineering-v0.2.0` → `0.2.0`).

If there are no matching releases yet, tell the user and stop.

### 4. Compare versions

- If the installed version matches the latest, tell the user: **"acme-engineering plugin is up to date (vX.Y.Z)"**.
- If the latest version is newer, tell the user: **"Update available: vCURRENT → vLATEST"** and proceed to step 5.
- If you cannot determine the installed version, proceed to step 5 anyway.

### 5. Clear the plugin cache and reinstall

The plugin cache can hold stale artifacts. Remove it before reinstalling:

```bash
rm -rf "${HOME}/.claude/plugins/cache/YOUR_ORG-enterprise-agent-plugins"
```

Then reinstall the plugin:

```bash
claude plugin uninstall acme-engineering@YOUR_ORG-enterprise-agent-plugins 2>/dev/null
claude plugin install acme-engineering@YOUR_ORG-enterprise-agent-plugins
```

> **Note**: `claude plugin update acme-engineering@YOUR_ORG-enterprise-agent-plugins` relies on the local marketplace state and may report "already at latest" when the marketplace clone is stale. The uninstall+install approach is more reliable after syncing the marketplace.

### 6. Verify the update

```bash
jq -r .version "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
```

Confirm the version matches the expected latest. Then tell the user to restart their Claude Code session to pick up the changes.
