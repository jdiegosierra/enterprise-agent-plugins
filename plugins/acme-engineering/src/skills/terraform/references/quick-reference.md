# Quick Reference

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## Command Cheat Sheet

### Static Analysis

```bash
terraform fmt -recursive -check    # or: tofu fmt -recursive -check
terraform validate                 # or: tofu validate
tflint --init && tflint
trivy config .
checkov -d .
```

### Native Tests (1.6+)

```bash
terraform test                              # Run all tests
terraform test -test-directory=tests/unit/  # Specific directory
terraform test -verbose                     # Verbose output
```

### Plan Validation

```bash
terraform plan -out tfplan
terraform show -json tfplan | jq -r '.' > tfplan.json
terraform show tfplan | grep "will be created"
```

## Decision Flowcharts

### Testing Approach

```
Need to test Terraform/OpenTofu code?
│
├─ Just syntax/format?
│  └─ terraform validate + fmt
│
├─ Static security scan?
│  └─ trivy + checkov
│
├─ Terraform 1.6+?
│  ├─ Simple logic test?
│  │  └─ Native terraform test
│  └─ Complex integration?
│     └─ Terratest
│
└─ Pre-1.6?
   └─ Terratest (or upgrade Terraform)
```

### Module Development Workflow

```
1. Plan    → Define inputs, outputs, document purpose
2. Implement → Create resources, pin versions, add examples
3. Test    → Static analysis → unit tests → integration tests
4. Document → README, inputs/outputs, CHANGELOG
5. Publish → Tag version, push to registry
```

## Version-Specific Guidance

| Version | Key Features |
|---------|-------------|
| 1.0-1.5 | No native testing. Use Terratest + static analysis |
| 1.6+ | Native `terraform test` / `tofu test` |
| 1.7+ | Mock providers for unit testing |
| 1.8+ | Provider-defined functions |
| 1.9+ | Cross-variable validation |
| 1.11+ | Write-only arguments (secrets out of state) |

### Terraform vs OpenTofu

| Factor | Terraform | OpenTofu |
|--------|-----------|----------|
| License | BSL 1.1 | MPL 2.0 |
| Governance | HashiCorp | Linux Foundation |
| Native Testing | 1.6+ | 1.6+ |
| Mock Providers | 1.7+ | 1.7+ |
| Migration | N/A | Drop-in for TF ≤1.5 |

## Troubleshooting

### Tests fail in CI but pass locally

Pin versions explicitly in `versions.tf`. Different Terraform/provider versions are the usual cause.

### Parallel tests conflict

Use unique identifiers:
```go
uniqueId := random.UniqueId()
bucketName := fmt.Sprintf("test-bucket-%s", uniqueId)
```

### High test costs

1. Mock providers for unit tests (1.7+)
2. Resource TTL tags + auto-cleanup
3. Integration tests only on main branch
4. Smaller instance types (`t3.micro`)

## Pre-Commit Checklist

### Formatting & Validation
- [ ] `terraform fmt -recursive`
- [ ] `terraform validate`

### Naming
- [ ] All identifiers use `_` not `-`
- [ ] No resource names repeat resource type
- [ ] Variables have `description`
- [ ] Outputs have `description`

### Code Structure
- [ ] `count`/`for_each` at top of resource blocks
- [ ] `tags` as last real argument
- [ ] `lifecycle` at end of resource
- [ ] Variables ordered: description → type → default → validation

### Modern Features
- [ ] Using `try()` not `element(concat())`
- [ ] `nullable = false` on non-null variables
- [ ] `optional()` in object types (1.3+)
- [ ] Validation blocks where constraints needed

## Version Constraint Syntax

| Syntax | Meaning | Use Case |
|--------|---------|----------|
| `"5.0.0"` | Exact | Avoid (inflexible) |
| `"~> 5.0"` | 5.0.x only | Recommended |
| `">= 5.0, < 6.0"` | Any 5.x | Range |
| `">= 5.0"` | Minimum | Risky |

### Strategy by Component

| Component | Strategy | Example |
|-----------|----------|---------|
| Terraform | Pin minor | `~> 1.9` |
| Providers | Pin major | `~> 5.0` |
| Modules (prod) | Pin exact | `5.1.2` |
| Modules (dev) | Allow patch | `~> 5.1` |

## Refactoring Patterns

### Count → For_Each Migration

1. Add `for_each`, keep `count` commented
2. Add `moved` blocks for each resource
3. `terraform plan` — should show "moved" not "destroy/create"
4. Apply, then remove old `count`

### Legacy → Modern (0.12 → 1.x)

- [ ] `element(concat(...))` → `try()`
- [ ] Add `nullable = false`
- [ ] Use `optional()` in object types (1.3+)
- [ ] Migrate secrets to write-only arguments (1.11+)
- [ ] Use `moved` blocks for refactoring (1.1+)
