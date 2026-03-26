# Runbook: Grant GitHub Access

Grant access to the Acme Corp GitHub organization for a new or existing employee.

All changes are made via PR to the `acme-corp/ci-cd` repository. Two files are modified:
- `src/config/employees.ts` — employee registry (GitHub username + ID)
- `src/config/teams.ts` — team membership

## Inputs

Collect these before starting:

| Input | How to obtain |
|-------|---------------|
| **GitHub username** | Ask the user or read from the Jira ticket |
| **Team** | Ask which team. Valid teams: `engineering`, `sre`, `qa`, `product`, `design`, `data`, `security`, `operations` |
| **Jira ticket** (optional) | If triggered from a ticket, use its key (e.g., `SRE-123`) |

## Prerequisites

Before proceeding, confirm:

1. **The user has logged into GitHub at least once.** Their GitHub account must already exist — it is NOT created by this process.

## Steps

### 1. Look up the GitHub user

```bash
gh api users/<github-username> --jq '{login: .login, id: .id, name: .name}'
```

- If the user is not found, stop and report the error.
- Save the `id` (numeric) and `login` for the next steps.

### 2. Generate the employee key

Convert the employee's full name to a camelCase key: `firstNameLastName`.

Examples:
- John Smith → `johnSmith`
- Jane Doe → `janeDoe`

If the full name is not available, derive it from the GitHub profile name returned in step 1.

### 3. Clone and prepare the ci-cd repo

```bash
gh repo clone acme-corp/ci-cd /tmp/acme-ci-cd 2>/dev/null || git -C /tmp/acme-ci-cd fetch origin && git -C /tmp/acme-ci-cd checkout main && git -C /tmp/acme-ci-cd pull origin main
```

Create a feature branch:

```bash
git -C /tmp/acme-ci-cd checkout -b feature/<TICKET-KEY>-github-access-<firstName><lastName>
```

If there is no Jira ticket, use: `feature/github-access-<firstName><lastName>`.

### 4. Add the employee to `src/config/employees.ts`

Add a new entry **before the closing `} as const`** line:

```typescript
  <employeeKey>: {
    githubId: '<github-id>',
    githubUsername: '<github-username>',
  },
```

Follow the existing pattern exactly (2-space indent, trailing comma).

### 5. Add the employee to the team in `src/config/teams.ts`

Find the team object matching the requested team key. Add the employee key to the `members` array.

### 6. Commit and push

```bash
git -C /tmp/acme-ci-cd add src/config/employees.ts src/config/teams.ts
git -C /tmp/acme-ci-cd commit -m "[<TICKET-KEY>] feat: add <employeeKey> to employees and <teamName> team"
git -C /tmp/acme-ci-cd push origin HEAD
```

If there is no Jira ticket, omit the `[<TICKET-KEY>]` prefix.

### 7. Create the PR

```bash
gh pr create --repo acme-corp/ci-cd \
  --title "[<TICKET-KEY>] Grant GitHub access to <full-name>" \
  --body "## Summary

Grant GitHub access to new <teamName> team member <full-name>.

## Changes
- **employees**: Add \`<employeeKey>\` with GitHub username \`<github-username>\` (ID: <github-id>)
- **teams**: Add \`<employeeKey>\` to the \`<teamKey>\` team
"
```

### 8. Update the Jira ticket (if applicable)

If triggered from a Jira ticket, add a comment with the PR URL.

## Verification

After the PR is merged:
- The CI/CD pipeline syncs the configuration to the GitHub organization
- Verify the user appears in the correct team: `gh api orgs/acme-corp/teams/<team-slug>/members --jq '.[].login'`

## Rollback

If the access was granted incorrectly:
1. Open a new PR removing the employee from `employees.ts` and `teams.ts`
2. The pipeline will sync the removal
