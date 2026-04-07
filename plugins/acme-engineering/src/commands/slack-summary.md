---
name: slack-summary
description: Summarize recent messages from a Slack channel
audience: employee
---

You must summarize recent messages from a Slack channel. This is a direct action — execute immediately.

## Prerequisites

The Slack MCP tools must be available (enabled via the Maisa setup command). If no Slack tools are found, tell the user to run the setup command to add the Slack MCP server.

## Steps

1. **Determine the channel.** If the user specified a channel name or ID, use it. If not, ask which channel to summarize.

2. **Resolve the channel ID.** Consult `/acme-engineering:acme-platform` for the channel map — if the channel is listed there, use the ID directly. Otherwise, use the Slack MCP `slack_search_channels` tool to find it (strip the `#` prefix if present, search both public and private). Look for tools matching the name regardless of prefix.

3. **Read recent messages.** Use the Slack MCP `slack_read_channel` tool with the channel ID. Default to the last 50 messages unless the user specifies a different amount or time range.

4. **Produce a summary.** Organize the summary by:
   - **Key topics discussed** — group related messages into topics
   - **Decisions made** — any conclusions or agreements
   - **Action items** — tasks mentioned or assigned
   - **Links shared** — PRs, docs, dashboards, or external URLs

5. **Mention active threads.** If messages have thread replies (indicated by thread metadata), mention them briefly and offer to dive into specific threads if the user wants more detail. Do not automatically read every thread — that would be too many API calls.

## Error handling

- **Channel not found** — suggest similar channel names from `/acme-engineering:acme-platform` or run a broader `slack_search_channels` query.
- **No messages in range** — tell the user the channel has no recent activity and suggest expanding the time range.
- **Auth error** — tell the user to run the setup command to configure the Slack MCP.
