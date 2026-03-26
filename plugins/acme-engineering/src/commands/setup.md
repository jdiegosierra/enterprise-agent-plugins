---
description: Interactive setup wizard — configure CLI tools and integrations
---

Check the user's environment for required tools and integrations. For each item, report whether it's installed and offer to help configure it.

## Checklist

| Item | Check | Action if missing |
|------|-------|-------------------|
| `gh` (GitHub CLI) | `which gh` | Suggest `brew install gh` and `gh auth login` |
| `kubectl` | `which kubectl` | Suggest `brew install kubectl` |
| `helm` | `which helm` | Suggest `brew install helm` |
| `aws` CLI | `which aws` | Suggest `brew install awscli` |
| AWS SSO config | `grep -q 'sso-session acme' ~/.aws/config` | Help configure AWS SSO profiles |
| Notifications | Check `~/.claude/.acme-notify-config.json` | Ask if they want desktop/Slack notifications |

## Auto-detection

Run all checks silently first, then present a summary showing what's configured and what's pending. Only walk through pending items.

## After setup

Save the setup state to `~/.claude/.acme-setup.json` so the onboarding hook knows what's been configured.
