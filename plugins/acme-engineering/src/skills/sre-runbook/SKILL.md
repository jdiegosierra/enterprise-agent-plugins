---
name: sre-runbook
description: >
  Execute SRE runbooks for operational tasks: GitHub access, employee onboarding,
  credential rotation. Invoke when an SRE ticket requires an operational procedure.
  Triggers: github access, onboarding, grant access, credential rotation.
user-invocable: true
---

# SRE Runbook Executor

You must execute the matching SRE runbook for the given ticket or request.

## Step 1 — Find the runbook

Available runbooks and their triggers:

| Trigger keywords | File |
|-----------------|------|
| github access, add to github org, grant access | `github-access.md` |

Runbook location: `runbooks/sre/` (relative to plugin root)

## Step 2 — Read the runbook

Read the matched runbook file to get the full step-by-step procedure.

## Step 3 — Collect inputs

The runbook specifies required inputs. Collect them from:
- The Jira ticket description (if triggered from Jira)
- Ask the user (if triggered interactively)

If required inputs are missing, ask before proceeding.

## Step 4 — Execute

Follow the runbook steps in order. Report progress as you go.

## Step 5 — Report result

After completion:
- Report the PR URL and actions taken
- If triggered from Jira, add a comment with the result
- If any step failed, report the error clearly
