# CI/CD Workflows for Terraform

> **Part of:** [terraform skill](../SKILL.md) | **Source:** [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill)

## GitHub Actions Workflow

### Complete Example

```yaml
# .github/workflows/terraform.yml
name: Terraform

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2

      - name: Terraform Format
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: TFLint
        run: |
          curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
          tflint --init
          tflint

  test:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Terraform Tests
        run: terraform test

  plan:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Terraform Init
        run: terraform init
      - name: Terraform Plan
        run: terraform plan -out=tfplan
      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan
          path: tfplan

  apply:
    needs: plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Download Plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan
      - name: Terraform Apply
        run: terraform apply tfplan
```

### With Cost Estimation (Infracost)

```yaml
  cost-estimate:
    needs: plan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Infracost
        uses: infracost/actions/setup@v2
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}
      - name: Generate Cost Estimate
        run: |
          infracost breakdown --path . \
            --format json \
            --out-file /tmp/infracost.json
      - name: Post Cost Comment
        uses: infracost/actions/comment@v1
        with:
          path: /tmp/infracost.json
          behavior: update
```

## GitLab CI Template

```yaml
stages:
  - validate
  - test
  - plan
  - apply

variables:
  TF_ROOT: ${CI_PROJECT_DIR}

.terraform_template:
  image: hashicorp/terraform:latest
  before_script:
    - cd ${TF_ROOT}
    - terraform init

validate:
  extends: .terraform_template
  stage: validate
  script:
    - terraform fmt -check -recursive
    - terraform validate

test:
  extends: .terraform_template
  stage: test
  script:
    - terraform test
  only:
    - merge_requests
    - main

plan:
  extends: .terraform_template
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
    expire_in: 1 week

apply:
  extends: .terraform_template
  stage: apply
  script:
    - terraform apply tfplan
  dependencies:
    - plan
  only:
    - main
  when: manual
  environment:
    name: production
```

## Automated Cleanup

### Cleanup Script

```bash
#!/bin/bash
# cleanup-test-resources.sh
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=test \
  --output text | \
  while read arn; do
    instance_id=$(echo $arn | grep -oP 'instance/\K[^/]+')
    if [ ! -z "$instance_id" ]; then
      echo "Terminating instance: $instance_id"
      aws ec2 terminate-instances --instance-ids $instance_id
    fi
  done
```

### Scheduled Cleanup (GitHub Actions)

```yaml
name: Cleanup Test Resources
on:
  schedule:
    - cron: '0 */2 * * *'
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Run Cleanup Script
        run: ./scripts/cleanup-test-resources.sh
```

## Security Scanning in CI

```yaml
security-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Run Trivy
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: '.'
    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
```

## Atlantis Integration

```yaml
# atlantis.yaml
version: 3
projects:
  - name: production
    dir: environments/prod
    workspace: default
    terraform_version: v1.6.0
    workflow: custom

workflows:
  custom:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-lock", "false"]
    apply:
      steps:
        - apply
```

## Best Practices

- Separate environments into different workflows or use reusable workflows
- Require manual approvals for production applies
- Cache Terraform plugins with `actions/cache`
- Use `-lock-timeout=10m` in CI to handle concurrent runs
- Run integration tests only on main branch to control costs
