#!/bin/bash
# Test suite for bash-safety-guard.sh
# Usage: bash tests/test-bash-safety-guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="$SCRIPT_DIR/../claude/hooks/bash-safety-guard.sh"

PASS=0
FAIL=0

assert_blocked() {
  local desc="$1" cmd="$2"
  local input=$(jq -n --arg cmd "$cmd" '{"tool_input": {"command": $cmd}}')
  if echo "$input" | bash "$GUARD" >/dev/null 2>&1; then
    echo "FAIL: expected BLOCKED but was ALLOWED — $desc"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: blocked — $desc"
    PASS=$((PASS + 1))
  fi
}

assert_allowed() {
  local desc="$1" cmd="$2"
  local input=$(jq -n --arg cmd "$cmd" '{"tool_input": {"command": $cmd}}')
  if echo "$input" | bash "$GUARD" >/dev/null 2>&1; then
    echo "PASS: allowed — $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: expected ALLOWED but was BLOCKED — $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Bash Safety Guard Tests ==="

# Git
assert_blocked "git push --force" "git push --force origin main"
assert_blocked "git reset --hard" "git reset --hard HEAD~1"
assert_blocked "git branch -D" "git branch -D feature/test"
assert_allowed "git push (safe)" "git push origin feature/test"
assert_allowed "git status" "git status"

# Shell
assert_blocked "rm -rf" "rm -rf /tmp/test"
assert_allowed "rm single file" "rm /tmp/test.txt"

# AWS
assert_blocked "aws terminate instances" "aws ec2 terminate-instances --instance-ids i-123"
assert_blocked "aws delete stack" "aws cloudformation delete-stack --stack-name test"
assert_allowed "aws describe" "aws ec2 describe-instances --profile dev"

# kubectl
assert_blocked "kubectl delete" "kubectl delete pod my-pod -n default"
assert_blocked "kubectl drain" "kubectl drain node-1"
assert_allowed "kubectl get pods" "kubectl get pods -n default"

# gh
assert_blocked "gh repo delete" "gh repo delete acme-corp/test --yes"
assert_blocked "gh pr merge" "gh pr merge 123"
assert_allowed "gh pr create" "gh pr create --title test --body test"

# Docker
assert_blocked "docker system prune" "docker system prune -af"
assert_allowed "docker ps" "docker ps"

# Terraform
assert_blocked "terraform destroy" "terraform destroy"
assert_allowed "terraform plan" "terraform plan"

# Confirmed commands should be allowed
assert_allowed "confirmed rm -rf" "ACME_GUARD_CONFIRMED=yes rm -rf /tmp/test"
assert_allowed "confirmed kubectl delete" "ACME_GUARD_CONFIRMED=yes kubectl delete pod my-pod"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

[ "$FAIL" -eq 0 ] || exit 1
