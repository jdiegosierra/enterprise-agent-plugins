---
name: slack-notify
description: Send a Slack notification about completed work to a channel
audience: employee
---

You must send a Slack notification to a channel. This is a direct action — execute immediately.

## Prerequisites

The Slack MCP tools must be available (enabled via the Maisa setup command). If no Slack tools are found, tell the user to run the setup command to add the Slack MCP server.

## Steps

1. **Determine what to notify about.** Ask the user or infer from context: a PR just created, a deployment completed, tests passing, an incident update, or a general announcement.

2. **Determine the target channel.** Ask the user, or suggest based on context:
   - PR created → `#release-review`
   - Incident update → `#incidents`
   - Infrastructure question → `#sre-public`
   - General engineering → `#engineering`

   Consult `/acme-engineering:acme-platform` for the full channel map and IDs.

3. **Draft the message.** Include relevant details:
   - PR notifications: PR title, URL, branch, brief description
   - Deployment notifications: service name, environment, version
   - Incident updates: what was found, current status, next steps

   Use Slack markdown formatting. Keep it concise.

4. **Show the draft and target channel to the user.** Ask for explicit confirmation before sending. Display clearly:
   - **Channel:** `#channel-name`
   - **Message:** the full draft

5. **Send the message.** Based on user preference (look for tools matching the name regardless of prefix):
   - If the user confirmed the exact content → use the Slack MCP `slack_send_message` tool
   - If the user wants to review/edit in Slack first → use the Slack MCP `slack_send_message_draft` tool

## Safety

- **Never send without user confirmation** — always show the draft first
- **Never auto-post to `#incidents`** — incident channels are high-visibility
- If in doubt about the target channel, ask the user
