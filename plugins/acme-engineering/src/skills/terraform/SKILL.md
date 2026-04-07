---
name: terraform
description: Use when working with Terraform or OpenTofu — creating modules, writing tests, setting up CI/CD pipelines, reviewing configurations, debugging state issues, implementing security scanning, or making IaC architecture decisions. For Pulumi see pulumi-best-practices, for general CI/CD see devops.
metadata:
  based_on: antonbabenko/terraform-skill, jeffallan/claude-skills
---

# Terraform & OpenTofu Skill

Comprehensive Terraform and OpenTofu guidance covering testing, modules, CI/CD, security, and production patterns.

## When to Use This Skill

**Activate when:**
- Creating new Terraform or OpenTofu configurations or modules
- Setting up testing infrastructure for IaC code
- Deciding between testing approaches (validate, plan, frameworks)
- Structuring multi-environment deployments
- Implementing CI/CD for infrastructure-as-code
- Reviewing or refactoring existing Terraform/OpenTofu projects

**Don't use for:**
- Basic Terraform syntax questions (Claude knows this)
- Provider-specific API reference (link to docs instead)
- Cloud platform questions unrelated to Terraform/OpenTofu

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Code Patterns | `references/code-patterns.md` | Block ordering, count vs for_each, modern features, refactoring |
| Module Patterns | `references/module-patterns.md` | Module hierarchy, variable/output best practices, anti-patterns |
| State Management | `references/state-management.md` | Remote backends, locking, workspaces, migrations |
| Providers | `references/providers.md` | AWS/Azure/GCP configuration, authentication, Kubernetes/Helm |
| Testing Frameworks | `references/testing-frameworks.md` | Native tests (1.6+), Terratest, set-type blocks, mocking |
| Testing | `references/testing.md` | Plan validation, OPA/Sentinel policy, TFLint, pre-commit |
| CI/CD Workflows | `references/ci-cd-workflows.md` | GitHub Actions, GitLab CI, Infracost, Atlantis, cleanup |
| Security & Compliance | `references/security-compliance.md` | Trivy, Checkov, secrets management, compliance checklists |
| Best Practices | `references/best-practices.md` | DRY patterns, naming, cost optimization, tagging |
| Quick Reference | `references/quick-reference.md` | Cheat sheets, decision flowcharts, troubleshooting, migration |

## Core Principles

### Module Hierarchy

| Type | When to Use | Scope |
|------|-------------|-------|
| **Resource Module** | Single logical group of connected resources | VPC + subnets, Security group + rules |
| **Infrastructure Module** | Collection of resource modules for a purpose | Multiple resource modules in one region/account |
| **Composition** | Complete infrastructure | Spans multiple regions/accounts |

**Hierarchy:** Resource → Resource Module → Infrastructure Module → Composition

### Naming Conventions

```hcl
# Descriptive, contextual names
resource "aws_instance" "web_server" { }
resource "aws_s3_bucket" "application_logs" { }

# "this" for singleton resources in modules
resource "aws_vpc" "this" { }

# Variables: context-specific, snake_case
var.vpc_cidr_block          # Not just "cidr"
var.database_instance_class # Not just "instance_class"
```

### Code Structure Standards

**Resource block ordering:**
1. `count` or `for_each` FIRST (blank line after)
2. Other arguments
3. `tags` as last real argument
4. `depends_on` after tags (if needed)
5. `lifecycle` at the very end (if needed)

**Variable block ordering:**
1. `description` (ALWAYS required)
2. `type`
3. `default`
4. `sensitive` / `nullable`
5. `validation`

## Testing Strategy

### Decision Matrix

| Situation | Approach | Tools | Cost |
|-----------|----------|-------|------|
| Quick syntax check | Static analysis | `terraform validate`, `fmt` | Free |
| Pre-commit validation | Static + lint | `validate`, `tflint`, `trivy`, `checkov` | Free |
| Terraform 1.6+, simple logic | Native test framework | Built-in `terraform test` | Free-Low |
| Pre-1.6, or Go expertise | Integration testing | Terratest | Low-Med |
| Security/compliance focus | Policy as code | OPA, Sentinel | Free |
| Cost-sensitive workflow | Mock providers (1.7+) | Native tests + mocking | Free |

### Testing Pyramid

```
        /\
       /  \          End-to-End (Expensive)
      /____\         Full environment deployment
     /      \
    /________\       Integration (Moderate)
   /          \      Module testing in isolation
  /____________\
 /              \    Static Analysis (Cheap)
/________________\   validate, fmt, lint, security scanning
```

## Modern Terraform Features

| Feature | Version | Use Case |
|---------|---------|----------|
| `try()` function | 0.13+ | Safe fallbacks |
| `nullable = false` | 1.1+ | Prevent null values |
| `moved` blocks | 1.1+ | Refactor without destroy |
| `optional()` with defaults | 1.3+ | Optional object attributes |
| Native testing | 1.6+ | Built-in test framework |
| Mock providers | 1.7+ | Cost-free unit testing |
| Provider functions | 1.8+ | Provider-specific transforms |
| Cross-variable validation | 1.9+ | Validate between variables |
| Write-only arguments | 1.11+ | Secrets never stored in state |

## Version Verification

**CRITICAL**: Before proposing any Terraform configuration, you MUST:

1. **Check the Terraform version**:
   ```bash
   terraform version -json | python3 -c "import json,sys; print(json.load(sys.stdin)['terraform_version'])"
   ```
2. **Check provider versions**: `terraform providers`
3. **Never assume feature availability from training data**
4. **Search official documentation if in doubt**

## CI/CD Integration

### Recommended Stages

1. **Validate** — format + syntax + linting + security scanning
2. **Test** — automated tests (native or Terratest)
3. **Plan** — generate and review execution plan
4. **Apply** — execute changes (with approvals for production)

### Cost Optimization

1. Use mocking for PR validation (free)
2. Run integration tests only on main branch (controlled cost)
3. Implement auto-cleanup (prevent orphaned resources)
4. Tag all test resources (track spending)

## Security Essentials

```bash
# Static security scanning
trivy config .
checkov -d .
```

**Avoid:** secrets in variables, default VPC, missing encryption, open security groups.
**Use:** AWS Secrets Manager, dedicated VPCs, encryption at rest, least-privilege SGs.

## Constraints

### MUST DO
- Use semantic versioning for modules
- Enable remote state with locking
- Validate inputs with validation blocks
- Use consistent naming conventions
- Tag all resources for cost tracking
- Pin provider versions
- Run terraform fmt and validate
- Include `description` on all variables and outputs

### MUST NOT DO
- Store secrets in plain text or state
- Use local state for production
- Skip state locking
- Hardcode environment-specific values
- Create circular module dependencies
- Commit .terraform directories
- Use `count` when items may be reordered (use `for_each`)

## Attribution

Based on [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill) and [jeffallan/claude-skills](https://github.com/jeffallan/claude-skills). Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com).
