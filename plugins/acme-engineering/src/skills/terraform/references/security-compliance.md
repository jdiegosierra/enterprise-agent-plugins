# Security & Compliance

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## Security Scanning Tools

### Trivy (successor to tfsec)

```bash
# Install
brew install trivy

# Scan Terraform configs
trivy config .
```

### Checkov

```bash
# Run Checkov
checkov -d . --framework terraform

# Skip specific checks
checkov -d . --skip-check CKV_AWS_23

# JSON report
checkov -d . -o json > checkov-report.json
```

## Common Security Issues

### Secrets in Variables

```hcl
# BAD
variable "database_password" {
  default = "SuperSecret123!"  # Never do this
}

# GOOD — use Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "this" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

### Missing Encryption

```hcl
# GOOD — enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### Open Security Groups

```hcl
# BAD
cidr_blocks = ["0.0.0.0/0"]  # Never for ingress on sensitive ports

# GOOD — restrict to specific sources
cidr_blocks = ["10.0.0.0/16"]  # Internal only
```

## Compliance Testing

### terraform-compliance

```gherkin
# compliance/aws-encryption.feature
Feature: AWS Resources must be encrypted

  Scenario: S3 buckets must have encryption
    Given I have aws_s3_bucket defined
    When it has aws_s3_bucket_server_side_encryption_configuration
    Then it must contain rule
    And it must contain apply_server_side_encryption_by_default

  Scenario: RDS instances must be encrypted
    Given I have aws_db_instance defined
    Then it must contain storage_encrypted
    And its value must be true
```

```bash
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
terraform-compliance -f compliance/ -p tfplan.json
```

### Open Policy Agent (OPA)

```rego
# policy/s3_encryption.rego
package terraform.s3

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  not resource.change.after.server_side_encryption_configuration
  msg := sprintf("S3 bucket '%s' must have encryption enabled", [resource.address])
}
```

## Secrets Management

### AWS Secrets Manager Pattern

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}
```

### Write-Only Arguments (Terraform 1.11+)

```hcl
# Secret never stored in state
resource "aws_db_instance" "this" {
  password_wo = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

## State File Security

```hcl
# Always encrypt state at rest
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

- Enable versioning on state bucket
- Block public access
- Restrict access via IAM policies
- Use KMS encryption for sensitive workloads

## IAM Best Practices

```hcl
# GOOD — specific permissions only
resource "aws_iam_policy" "app_policy" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-app-bucket/*"
    }]
  })
}

# BAD — never use wildcards
# Action = "*", Resource = "*"
```

## Compliance Checklists

### SOC 2
- [ ] Encryption at rest for all data stores
- [ ] Encryption in transit (TLS/SSL)
- [ ] IAM policies follow least privilege
- [ ] Logging enabled for all resources
- [ ] MFA required for privileged access

### HIPAA
- [ ] PHI encrypted at rest and in transit
- [ ] Access logs enabled
- [ ] Dedicated VPC with private subnets
- [ ] Regular backup and retention policies

### PCI-DSS
- [ ] Network segmentation (separate VPCs)
- [ ] No default passwords
- [ ] Strong encryption algorithms
- [ ] Regular security scanning
