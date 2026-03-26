---
description: Show everything the Acme engineering plugin can do — commands, agents, skills, and integrations
---

Present the following reference to the user in a friendly, organized way. Do not omit any section.

## Commands

| Command | Description |
|---------|-------------|
| `/acme-engineering:help` | Show this reference |
| `/acme-engineering:setup` | Interactive setup wizard |
| `/acme-engineering:lint-fix` | Auto-fix linting issues in the current project |
| `/acme-engineering:run-tests` | Run the project test suite |

## Agents

| Agent | Description |
|-------|-------------|
| `sre` | Infrastructure, K8s ops, monitoring, incidents, runbook execution |
| `backend-developer` | PRs, linting, testing for Go/Python services |
| `frontend-developer` | PRs, linting, testing for TypeScript/React/Vue projects |

## Skills (auto-loaded when relevant)

| Skill | Description |
|-------|-------------|
| `acme-platform` | Repository inventory, microservice architecture, service dependencies |
| `kubernetes` | K8s cluster management, RBAC, workloads, networking, troubleshooting |
| `sre-runbook` | SRE runbook executor for operational tasks |

## Integration tools

| Integration | Type | Description |
|-------------|------|-------------|
| `gh` | CLI | GitHub — issues, PRs, code search, repository management |
| `kubectl` / `helm` | CLI | Kubernetes — pods, deployments, Helm, scaling |
| `aws` | CLI | AWS — all services |

> CLI tools are always preferred over MCPs.
