# acme-finance

Acme Corp's Finance plugin. Budgeting, reporting, and compliance tools.

**Status:** Placeholder — add your own agents, skills, and commands here.

## Getting started

Follow the same structure as [acme-engineering](../acme-engineering/README.md):

1. Create `src/` with your agents, skills, and commands
2. Create `claude/` with symlinks to `src/` and a `hooks/` directory
3. Register the plugin in the root `marketplace.json` (already done)

## Example content ideas

- **Agents**: `financial-analyst` (budget analysis, forecasting), `compliance-reviewer` (policy validation)
- **Skills**: `expense-policy` (approval rules, limits), `reporting-standards` (quarterly reports, KPIs)
- **Runbooks**: `month-end-close` (reconciliation steps), `vendor-onboarding` (payment setup)
- **Commands**: `/acme-finance:expense-check`, `/acme-finance:budget-status`
