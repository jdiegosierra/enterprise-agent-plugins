---
name: acme-platform
description: >
  Acme Corp platform map — repository inventory, microservice architecture,
  service dependencies, and naming conventions. Consult this skill when you
  need to find which repo owns a service or understand the system topology.
---

# Acme Corp Platform Map

## Repository inventory

| Repository | Domain | Language | Description |
|-----------|--------|----------|-------------|
| `acme-corp/api-gateway` | Platform | Go | API gateway — routes traffic to backend services |
| `acme-corp/user-service` | Users | Go | User management, authentication, profiles |
| `acme-corp/billing-service` | Billing | Python | Subscription management, invoicing, payments |
| `acme-corp/notification-service` | Comms | Go | Email, SMS, push notifications |
| `acme-corp/web-app` | Frontend | TypeScript/React | Customer-facing web application |
| `acme-corp/admin-portal` | Frontend | TypeScript/Vue | Internal admin dashboard |
| `acme-corp/infra` | Platform | Terraform | Infrastructure as Code — AWS resources |
| `acme-corp/helm-charts` | Platform | Helm | Helm charts for all services |
| `acme-corp/ci-cd` | Platform | TypeScript | GitHub org management, team sync |

## Service dependencies

```
web-app → api-gateway → user-service → PostgreSQL
                      → billing-service → PostgreSQL, Stripe API
                      → notification-service → SES, SNS
```

## Environments

| Environment | AWS Account | EKS Cluster | Purpose |
|------------|-------------|-------------|---------|
| Development | `123456789012` | `acme-dev` | Development and testing |
| Staging | `123456789013` | `acme-staging` | Pre-production validation |
| Production | `123456789014` | `acme-prod` | Production workloads |

## Naming conventions

- **Repositories**: `acme-corp/<service-name>` (kebab-case)
- **Docker images**: `<account>.dkr.ecr.<region>.amazonaws.com/<service-name>:<tag>`
- **Helm releases**: `<service-name>` in namespace `<service-name>`
- **K8s namespaces**: one per service (`user-service`, `billing-service`, etc.)
- **Branches**: `<type>/<ticket-or-description>` (e.g., `feat/ACME-123-add-auth`)
