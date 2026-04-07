---
name: notify-config
description: Configure notification channels (desktop, Slack, or both) for task completion alerts
audience: employee
---

You must help the user configure where Claude Code task-completion notifications are sent. This is an interactive setup — walk the user through each step.

## Config file

All settings persist in `~/.claude/.acme-notify-config.json`. The schema is:

```json
{
  "channels": ["desktop", "slack"],
  "slack_channel_id": "C09MTT0PA4B",
  "slack_channel_name": "#sre-private"
}
```

- `channels` — array of enabled notification targets. Valid values: `"desktop"`, `"slack"`.
- `slack_channel_id` — required when `"slack"` is in channels. The Slack channel ID.
- `slack_channel_name` — display name for the channel.

## Steps

### 1. Show current configuration

Read `~/.claude/.acme-notify-config.json`. If it exists, display the current settings:

- **Desktop notifications:** enabled/disabled
- **Slack notifications:** enabled/disabled
  - If enabled, show the channel name

If the file does not exist, tell the user: **"No notification config found. Currently using desktop-only notifications (default)."**

### 2. Ask what to configure

Ask the user which notification channels they want:

1. **Desktop only** (default) — macOS/Linux desktop notifications via the Stop hook
2. **Slack only** — notifications sent to a Slack channel via MCP (requires Slack MCP enabled via `/acme-engineering:setup`)
3. **Both desktop and Slack**
4. **Disable all notifications**

### 3. If Slack is selected — choose the channel

If the user chose Slack (option 2 or 3):

1. Check if a Slack channel is already configured. If yes, ask: **"Keep the current channel (#channel-name), or pick a different one?"**
2. If choosing a new channel:
   - Consult `/acme-engineering:acme-platform` for the company channel map. Show the available channels and let the user pick.
   - If the user wants a channel not in the map, use the Slack MCP `slack_search_channels` tool to find it (look for tools matching the name regardless of prefix).
   - Store both the channel ID and the display name.

### 4. Write the config file

Write the JSON config to `~/.claude/.acme-notify-config.json`:

```bash
mkdir -p ~/.claude
```

Example for "both" with Slack to `#sre-private`:

```json
{
  "channels": ["desktop", "slack"],
  "slack_channel_id": "C09MTT0PA4B",
  "slack_channel_name": "#sre-private"
}
```

For "desktop only":

```json
{
  "channels": ["desktop"],
  "slack_channel_id": "",
  "slack_channel_name": ""
}
```

For "disabled":

```json
{
  "channels": [],
  "slack_channel_id": "",
  "slack_channel_name": ""
}
```

### 5. Test the configuration

Offer to send a test notification: **"Want to send a test notification to verify the setup?"**

If yes:

- **Desktop test:** Run the appropriate notification command:
  ```bash
  terminal-notifier -title "Claude Code · Test" -message "Notifications are working!" -group "claude-test" 2>/dev/null \
    || osascript -e 'display notification "Notifications are working!" with title "Claude Code · Test"' 2>/dev/null \
    || notify-send "Claude Code · Test" "Notifications are working!" 2>/dev/null
  ```

- **Slack test:** Send a test message using the Slack MCP `slack_send_message` tool (look for tools matching the name regardless of prefix) to the configured channel:
  > `:bell: *Claude Code notification test*`
  > `This channel will receive task completion alerts from Claude Code.`

  If the Slack send fails, tell the user to verify the Slack MCP is enabled (`/acme-engineering:setup`).

### 6. Confirm

Summarize the final configuration:

- **Desktop notifications:** enabled/disabled
- **Slack notifications:** enabled/disabled (channel: #channel-name)

Tell the user: **"Configuration saved. Notifications will use these settings starting now."**
