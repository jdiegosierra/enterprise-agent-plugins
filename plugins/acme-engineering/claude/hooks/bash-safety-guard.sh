#!/bin/bash
# Bash safety guard — runs as PreToolUse hook on every Bash tool call
# Reads tool input from stdin (JSON), inspects the command, and blocks
# destructive operations unless the user has confirmed (ACME_GUARD_CONFIRMED=yes).
#
# Guarded categories:
# 1. Destructive git commands (force push, reset --hard, etc.)
# 2. Destructive shell commands (rm -rf, kill -9, etc.)
# 3. AWS destructive operations (terminate-instances, delete-stack, etc.)
# 4. IaC destroy (terraform destroy, pulumi destroy)
# 5. Docker data-loss operations (system prune, volume rm, etc.)
# 6. Destructive kubectl commands (delete, drain, cordon, etc.)
# 7. Destructive GitHub CLI commands (repo delete, pr merge, etc.)
#
# Exit codes:
#   0 = allow the command
#   2 = block the command (message shown to the LLM via stderr)

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# If we can't parse the command, allow it (don't break other tools)
[ -z "$CMD" ] && exit 0

# Helper: block unless ACME_GUARD_CONFIRMED=yes is present
block_unless_confirmed() {
  if echo "$CMD" | grep -q 'ACME_GUARD_CONFIRMED=yes'; then
    exit 0
  fi
  echo "$1" >&2
  exit 2
}

# --- Destructive git commands ---
if echo "$CMD" | grep -qE '\bgit\b'; then
  if echo "$CMD" | grep -qiE 'push\s+.*--force|push\s+.*-f\b|push\s+.*--delete|push\s+origin\s+:[a-zA-Z]|reset\s+--hard|clean\s+-[a-zA-Z]*f|branch\s+-D|worktree\s+remove|checkout\s+\.\s*$|checkout\s+--\s+\.|restore\s+--staged\s+\.|restore\s+\.|stash\s+(drop|clear)\b|tag\s+-d\b'; then
    block_unless_confirmed '[DESTRUCTIVE GIT] You MUST confirm with the user before proceeding. Show: (1) the exact command, (2) what will be lost or overwritten, (3) the affected branch/worktree. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed.'
  fi
fi

# --- Destructive shell commands (rm -rf, find -delete) ---
if echo "$CMD" | grep -qE '\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r|\brm\s+-rf|\brm\s+-fr|\brm\s+-r\s+-f|\brm\s+-f\s+-r|\brm\s+--recursive|\bfind\b.*\s-delete\b'; then
  block_unless_confirmed '[DESTRUCTIVE SHELL] Recursive delete detected. You MUST confirm with the user before proceeding. Show: (1) the exact paths, (2) whether this is reversible. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed.'
fi

# --- Process killing ---
if echo "$CMD" | grep -qE '\bkill\s+-9|\bkill\s+-SIGKILL|\bkillall\b|\bpkill\b'; then
  block_unless_confirmed '[DESTRUCTIVE PROCESS] kill -9/killall/pkill detected. You MUST confirm with the user. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed.'
fi

# --- AWS destructive operations ---
if echo "$CMD" | grep -qE '\baws\b'; then
  if echo "$CMD" | grep -qiE 's3\s+(rm|rb)\s+.*--recursive|s3\s+rb\b|ec2\s+terminate-instances|rds\s+delete-db|cloudformation\s+delete-stack|ecs\s+delete-service|lambda\s+delete-function|dynamodb\s+delete-table|eks\s+delete-cluster|eks\s+delete-nodegroup'; then
    block_unless_confirmed '[DESTRUCTIVE AWS] Destructive AWS operation detected. You MUST confirm with the user. Show: (1) the AWS profile/account, (2) the resource, (3) whether reversible. For PRODUCTION: require the user to type YES. After user confirms, prefix with ACME_GUARD_CONFIRMED=yes.'
  fi
fi

# --- IaC destroy (Terraform / Pulumi) ---
if echo "$CMD" | grep -qiE '\bterraform\s+destroy|\bterraform\s+apply\s+.*-destroy|\bterraform\s+state\s+rm|\bpulumi\s+destroy|\btofu\s+destroy'; then
  block_unless_confirmed '[DESTRUCTIVE IAC] Infrastructure destroy detected. You MUST confirm with the user. Show: (1) stack/workspace, (2) environment, (3) resources affected. For PRODUCTION: require YES. After user confirms, prefix with ACME_GUARD_CONFIRMED=yes.'
fi

# --- Docker data-loss operations ---
if echo "$CMD" | grep -qE '\bdocker\b|\bdocker-compose\b'; then
  if echo "$CMD" | grep -qiE 'system\s+prune|volume\s+prune|volume\s+rm|compose\s+down\s+.*-v|compose\s+down\s+.*--volumes'; then
    block_unless_confirmed '[DESTRUCTIVE DOCKER] Docker data-loss operation detected. You MUST confirm with the user. After user confirms, prefix with ACME_GUARD_CONFIRMED=yes.'
  fi
fi

# --- Destructive kubectl commands ---
if echo "$CMD" | grep -qE '\bkubectl\b'; then
  if echo "$CMD" | grep -qiE '\bkubectl\s+(delete|drain|cordon)\b|\bkubectl\s+apply\s+.*--prune|\bkubectl\s+replace\s+.*--force'; then
    block_unless_confirmed '[DESTRUCTIVE KUBECTL] You MUST confirm with the user. Show: (1) cluster context, (2) namespace, (3) resource. For PRODUCTION: require YES. After user confirms, prefix with ACME_GUARD_CONFIRMED=yes.'
  fi
fi

# --- Destructive GitHub CLI commands ---
if echo "$CMD" | grep -qE '\bgh\b'; then
  if echo "$CMD" | grep -qiE '\bgh\s+(repo\s+delete|repo\s+archive|release\s+delete|issue\s+close|pr\s+merge|pr\s+close)|\bgh\s+api\s+.*-X\s+DELETE'; then
    block_unless_confirmed '[DESTRUCTIVE GITHUB] Destructive gh operation detected. You MUST confirm with the user. After user confirms, prefix with ACME_GUARD_CONFIRMED=yes.'
  fi
fi

exit 0
