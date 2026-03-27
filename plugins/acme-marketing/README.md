# acme-marketing

Acme Corp's Marketing plugin. Campaign management, content workflows, and analytics.

**Status:** Placeholder — add your own agents, skills, and commands here.

## Getting started

Follow the same structure as [acme-engineering](../acme-engineering/README.md):

1. Create `src/` with your agents, skills, and commands
2. Create `claude/` with symlinks to `src/` and a `hooks/` directory
3. Register the plugin in the root `marketplace.json` (already done)

## Example content ideas

- **Agents**: `content-creator` (copywriting, social media), `campaign-analyst` (A/B testing, metrics)
- **Skills**: `brand-guidelines` (tone, visual identity), `analytics-playbook` (attribution, funnel analysis)
- **Runbooks**: `campaign-launch` (checklist, approvals, go-live), `content-review` (editorial workflow)
- **Commands**: `/acme-marketing:campaign-status`, `/acme-marketing:content-brief`
