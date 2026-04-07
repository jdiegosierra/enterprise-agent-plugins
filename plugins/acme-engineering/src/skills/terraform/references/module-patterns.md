# Module Development Patterns

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## Module Hierarchy

| Type | When to Use | Scope | Example |
|------|-------------|-------|---------|
| **Resource Module** | Single logical group of connected resources | Tightly coupled resources | VPC + subnets, SG + rules |
| **Infrastructure Module** | Collection of resource modules | One region/account | Complete networking stack |
| **Composition** | Complete infrastructure | Multi-region/account | Production environment |

**Hierarchy:** Resource → Resource Module → Infrastructure Module → Composition

### Decision Tree

```
Is this environment-specific configuration?
├─ YES → Composition (environments/prod/)
└─ NO  → Does it combine multiple infrastructure concerns?
         ├─ YES → Infrastructure Module (modules/web-application/)
         └─ NO  → Resource Module (modules/vpc/)
```

## Architecture Principles

### 1. Smaller Scopes = Better

- Faster plan/apply
- Isolated failures
- Easier to reason about
- Parallel development

### 2. Always Use Remote State

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 3. Use terraform_remote_state as Glue

```hcl
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "prod/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

module "ec2" {
  source     = "../../modules/ec2"
  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
}
```

### 4. Keep Resource Modules Simple

```hcl
# BAD — hardcoded
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.large"
}

# GOOD — parameterized
resource "aws_instance" "web" {
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  tags          = var.tags
}
```

## Standard Module Structure

```
my-module/
├── README.md           # Usage documentation
├── main.tf             # Primary resources
├── variables.tf        # Input variables with descriptions
├── outputs.tf          # Output values
├── versions.tf         # Provider version constraints
├── examples/
│   ├── simple/         # Minimal working example
│   └── complete/       # Full-featured example
└── tests/
    └── module_test.tftest.hcl
```

**Conditional files:**
- `terraform.tfvars` — ONLY at composition level (NEVER in modules)
- `locals.tf` — for complex local value calculations
- `data.tf` — if main.tf gets too large
- `backend.tf` — ONLY at composition level

## Variable Best Practices

```hcl
variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
  }
}
```

**Key principles:**
- Always include `description`
- Use explicit `type` constraints
- Provide sensible `default` values
- Add `validation` blocks for constraints
- Use `sensitive = true` for secrets
- Context-specific names: `vpc_cidr_block` not `cidr`

## Output Best Practices

```hcl
output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.this.id
}

output "connection_info" {
  description = "Connection information for the instance"
  value = {
    id         = aws_instance.this.id
    private_ip = aws_instance.this.private_ip
    public_dns = aws_instance.this.public_dns
  }
}
```

- Always include `description`
- Mark sensitive outputs with `sensitive = true`
- Return objects for related values
- Pattern: `{name}_{type}_{attribute}`

## Dynamic Blocks

```hcl
resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
}
```

## Conditional Resources

```hcl
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.this]
}
```

## Module Versioning

```hcl
# Pin to specific version (production)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
}

# Pessimistic constraint (development)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
}

# Git tag reference
module "custom" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.3"
}
```

## Anti-patterns to Avoid

### God Modules
Break monolithic modules into focused ones: networking, compute, database.

### Hardcoded Values
Make everything configurable with variables and data sources.

### count When Order Matters
Use `for_each` when items may be reordered or removed.

### terraform.tfvars in Modules
Only at composition level (environments/prod/), never in reusable modules.

## Module Naming

```
# Public (Terraform Registry)
terraform-<PROVIDER>-<NAME>     # terraform-aws-vpc

# Private (organization)
<ORG>-terraform-<PROVIDER>-<NAME>  # acme-terraform-aws-vpc
```

## Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.92.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_docs
```
