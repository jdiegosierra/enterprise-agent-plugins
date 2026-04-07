# Testing Frameworks Guide

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## Static Analysis

**Always do this first.** Zero cost, catches 40%+ of issues.

```yaml
# .pre-commit-config.yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  hooks:
    - id: terraform_fmt
    - id: terraform_validate
    - id: terraform_tflint
```

## Native Terraform Tests (1.6+)

### Basic Structure

```hcl
# tests/s3_bucket.tftest.hcl
run "create_bucket" {
  command = apply

  assert {
    condition     = aws_s3_bucket.main.bucket != ""
    error_message = "S3 bucket name must be set"
  }
}
```

### command = plan vs command = apply

| Check | Mode | Why |
|-------|------|-----|
| Input values | `plan` | Known at plan time |
| Computed values (IDs, ARNs) | `apply` | Only known after create |
| Set-type blocks | `apply` | Cannot index sets with `[0]` |
| Fast feedback | `plan` | No resource creation |

### Working with Set-Type Blocks

**Problem:** Cannot index sets with `[0]`

```hcl
# WRONG — will fail
condition = aws_s3_bucket_server_side_encryption_configuration.this.rule[0].bucket_key_enabled

# CORRECT — use for expressions in apply mode
run "test_encryption" {
  command = apply

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule.bucket_key_enabled == true
    ])
    error_message = "Bucket key should be enabled"
  }
}
```

**Common set-type blocks in AWS:**
- `rule` in `aws_s3_bucket_server_side_encryption_configuration`
- `transition` in `aws_s3_bucket_lifecycle_configuration`
- IAM policy `statement` blocks

### With Mocking (1.7+)

```hcl
mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = {
      id  = "i-mock123"
      arn = "arn:aws:ec2:us-east-1:123456789:instance/i-mock123"
    }
  }
}
```

### Complete Example: S3 Tests

```hcl
# tests/unit/s3_bucket.tftest.hcl
mock_provider "aws" {}

run "validate_bucket_name" {
  command = plan
  variables { bucket = "my-test-bucket" }

  assert {
    condition     = aws_s3_bucket.this.bucket == "my-test-bucket"
    error_message = "Bucket name should match input"
  }
}

run "verify_default_encryption" {
  command = apply
  variables { bucket = "encrypted-bucket" }

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      alltrue([
        for config in rule.apply_server_side_encryption_by_default :
        config.sse_algorithm == "AES256"
      ])
    ])
    error_message = "Default encryption should be AES256"
  }
}
```

## Terratest (Go-based)

### When to Use

- Team has Go experience
- Complex integration testing needed
- Multi-provider or cross-account tests
- Pre-1.6 Terraform

### Basic Structure

```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestS3Module(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/complete",
        Vars: map[string]interface{}{
            "bucket_name": "test-bucket-" + random.UniqueId(),
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    bucketName := terraform.Output(t, terraformOptions, "bucket_name")
    assert.NotEmpty(t, bucketName)
}
```

### Test Stages (Faster Iteration)

```go
stage := test_structure.RunTestStage

stage(t, "setup", func() {
    terraform.InitAndApply(t, opts)
})
stage(t, "validate", func() {
    // Assertions here
})
stage(t, "teardown", func() {
    terraform.Destroy(t, opts)
})

// Skip during development:
// SKIP_setup=true SKIP_teardown=true go test
```

### Cost Management

| Module Size | Cost per Run |
|-------------|-------------|
| Small (S3, IAM) | $0-5 |
| Medium (VPC, EC2) | $5-20 |
| Large (RDS, ECS) | $20-100 |

**Tag test resources for tracking and automated cleanup:**

```go
Vars: map[string]interface{}{
    "tags": map[string]string{
        "Environment": "test",
        "TTL":         "2h",
        "CreatedBy":   "CI",
    },
}
```

## Framework Selection Summary

```
Quick syntax check?           → terraform validate + fmt
Security scan?                → trivy + checkov
Terraform 1.6+, simple logic? → Native tests
Pre-1.6 or complex?          → Terratest
```

### Cost Optimization

1. Mock providers for unit tests (1.7+)
2. Resource TTL tags + auto-cleanup
3. Integration tests only on main branch
4. Smaller instance types in tests
5. Share test resources when safe (VPCs, SGs)
