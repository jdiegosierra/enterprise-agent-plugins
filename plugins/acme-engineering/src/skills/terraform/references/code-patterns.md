# Code Patterns & Structure

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## Block Ordering & Structure

### Resource Block

```hcl
resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0    # 1. count/for_each FIRST

  allocation_id = aws_eip.this[0].id        # 2. Arguments
  subnet_id     = aws_subnet.public[0].id

  tags = {                                   # 3. tags last
    Name = "${var.name}-nat"
  }

  depends_on = [aws_internet_gateway.this]   # 4. depends_on after tags

  lifecycle {                                # 5. lifecycle at the very end
    create_before_destroy = true
  }
}
```

### Variable Block

```hcl
variable "environment" {
  description = "Environment name for resource tagging"   # 1. description (ALWAYS)
  type        = string                                     # 2. type
  default     = "dev"                                      # 3. default
  nullable    = false                                      # 4. nullable

  validation {                                             # 5. validation
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}
```

### Variable Type Preferences

- Prefer simple types (`string`, `number`, `list()`, `map()`) over `object()` unless strict validation needed
- Use `optional()` for optional object attributes (1.3+)

```hcl
variable "database_config" {
  description = "Database configuration"
  type = object({
    name             = string
    engine           = string
    instance_class   = string
    backup_retention = optional(number, 7)
    tags             = optional(map(string), {})
  })
}
```

### Output Naming

Pattern: `{name}_{type}_{attribute}`

```hcl
output "security_group_id" {        # No "this_" prefix
  description = "The ID of the security group"
  value       = try(aws_security_group.this[0].id, "")
}

output "private_subnet_ids" {       # Plural for lists
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}
```

## Count vs For_Each

### Quick Decision

| Scenario | Use | Why |
|----------|-----|-----|
| Boolean condition | `count = condition ? 1 : 0` | Simple on/off toggle |
| Simple numeric replication | `count = 3` | Fixed identical resources |
| Items may be reordered/removed | `for_each = toset(list)` | Stable addresses |
| Reference by key | `for_each = map` | Named access |

### Why For_Each Is Safer

```hcl
# BAD with count — removing middle item recreates subsequent resources
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
}

# GOOD with for_each — removal only affects that one resource
resource "aws_subnet" "private" {
  for_each          = toset(var.availability_zones)
  availability_zone = each.key
}
```

### Migration with Moved Blocks

```hcl
# Prevents resource recreation during count → for_each migration
moved {
  from = aws_subnet.private[0]
  to   = aws_subnet.private["us-east-1a"]
}

moved {
  from = aws_subnet.private[1]
  to   = aws_subnet.private["us-east-1b"]
}
```

## Modern Terraform Features (1.0+)

### try() (0.13+)

```hcl
# Modern
output "sg_id" {
  value = try(aws_security_group.this[0].id, "")
}

# Legacy — avoid
output "sg_id" {
  value = element(concat(aws_security_group.this.*.id, [""]), 0)
}
```

### optional() with Defaults (1.3+)

```hcl
variable "config" {
  type = object({
    name    = string
    timeout = optional(number, 300)
  })
}
```

### Cross-Variable Validation (1.9+)

```hcl
variable "backup_retention" {
  type = number
  validation {
    condition     = var.environment == "prod" ? var.backup_retention >= 7 : true
    error_message = "Production requires backup_retention >= 7"
  }
}
```

### Write-Only Arguments (1.11+)

```hcl
# Secret sent to AWS then forgotten — never in state
resource "aws_db_instance" "this" {
  password_wo = data.aws_secretsmanager_secret_version.db.secret_string
}
```

## Locals for Dependency Management

```hcl
# Forces correct deletion order: subnets before CIDR association
locals {
  vpc_id = try(
    aws_vpc_ipv4_cidr_block_association.this[0].vpc_id,
    aws_vpc.this.id,
    ""
  )
}

resource "aws_subnet" "public" {
  vpc_id = local.vpc_id  # Implicit dependency on CIDR association
}
```

## Version Management

### versions.tf Template

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
```

### Update Workflow

```bash
terraform init                # Lock versions
terraform init -upgrade       # Update within constraints
terraform plan                # Review changes
git add .terraform.lock.hcl   # Commit lock file
```

## Refactoring Patterns

### 0.12/0.13 → 1.x Checklist

- [ ] `element(concat(...))` → `try()`
- [ ] Add `nullable = false` where appropriate
- [ ] Use `optional()` in object types (1.3+)
- [ ] Add `validation` blocks
- [ ] Migrate secrets to write-only arguments (1.11+)
- [ ] Use `moved` blocks for refactoring (1.1+)

### Secrets Remediation

```hcl
# Before — secret in state
resource "aws_db_instance" "this" {
  password = var.db_password  # Stored in state!
}

# After — external secret management
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod-database-password"
}

resource "aws_db_instance" "this" {
  password_wo = data.aws_secretsmanager_secret_version.db.secret_string
}
```
