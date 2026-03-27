# acme-people

Acme Corp's People/HR plugin. Hiring workflows, onboarding automation, and team management.

**Status:** Placeholder — add your own agents, skills, and commands here.

## Getting started

Follow the same structure as [acme-engineering](../acme-engineering/README.md):

1. Create `src/` with your agents, skills, and commands
2. Create `claude/` with symlinks to `src/` and a `hooks/` directory
3. Register the plugin in the root `marketplace.json` (already done)

## Example content ideas

- **Agents**: `recruiter` (resume screening, interview scheduling), `onboarding-specialist` (new hire setup)
- **Skills**: `hiring-pipeline` (ATS integration), `employee-handbook` (policies and benefits)
- **Runbooks**: `new-hire-setup` (accounts, equipment, access), `offboarding` (revoke access, exit checklist)
- **Commands**: `/acme-people:open-positions`, `/acme-people:onboard`
