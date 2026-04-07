import { spawnSync } from "node:child_process"
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs"
import os from "node:os"
import path from "node:path"

type JsonObject = Record<string, any>

export type NotificationConfig = {
  channels?: string[]
  slack_channel_id?: string
  slack_channel_name?: string
}

type MessagingGuardInput = {
  toolName: string
  args?: Record<string, any>
  latestUserMessage?: unknown
}

export type ProjectInstruction = {
  filePath: string
  content: string
}

type ClaudeHookOutput = {
  systemMessage?: string
  hookSpecificOutput: Record<string, any>
}

function safeJsonParse<T>(input: string, fallback: T): T {
  try {
    return JSON.parse(input) as T
  } catch {
    return fallback
  }
}

export function readStdin(): string {
  try {
    return readFileSync(0, "utf8")
  } catch {
    return ""
  }
}

export function readJsonFile<T>(filePath: string, fallback: T): T {
  if (!existsSync(filePath)) return fallback
  try {
    return JSON.parse(readFileSync(filePath, "utf8")) as T
  } catch {
    return fallback
  }
}

export function writeJsonFile(filePath: string, value: unknown) {
  mkdirSync(path.dirname(filePath), { recursive: true })
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`)
}

export function writeTextFile(filePath: string, value: string) {
  mkdirSync(path.dirname(filePath), { recursive: true })
  writeFileSync(filePath, value)
}

export function countDirectories(dirPath: string): number {
  if (!existsSync(dirPath)) return 0
  return readdirSync(dirPath)
    .map((entry) => path.join(dirPath, entry))
    .filter((entry) => {
      try {
        return statSync(entry).isDirectory()
      } catch {
        return false
      }
    }).length
}

export function basenameSafe(value: string): string {
  if (!value) return ""
  return path.basename(value)
}

export function commandExists(command: string, env: NodeJS.ProcessEnv = process.env): boolean {
  const result = spawnSync("bash", ["-lc", `command -v ${command} >/dev/null 2>&1`], {
    env,
    encoding: "utf8",
  })
  return result.status === 0
}

export function runCommand(
  command: string,
  args: string[],
  options?: { env?: NodeJS.ProcessEnv; cwd?: string },
) {
  return spawnSync(command, args, {
    encoding: "utf8",
    env: options?.env,
    cwd: options?.cwd,
  })
}

export function versionGreater(a: string, b: string): boolean {
  if (!a || !b || a === b) return false
  const left = a.split(/[^0-9]+/).filter(Boolean).map(Number)
  const right = b.split(/[^0-9]+/).filter(Boolean).map(Number)
  const length = Math.max(left.length, right.length)
  for (let index = 0; index < length; index += 1) {
    const l = left[index] ?? 0
    const r = right[index] ?? 0
    if (l > r) return true
    if (l < r) return false
  }
  return false
}

export function currentClaudeVersion(pluginRoot: string): string {
  const pluginJson = path.join(pluginRoot, ".claude-plugin", "plugin.json")
  return readJsonFile<JsonObject>(pluginJson, {}).version ?? ""
}

export function currentOpenCodeVersion(pluginRoot: string): string {
  const pluginJson = path.join(pluginRoot, "claude", ".claude-plugin", "plugin.json")
  return readJsonFile<JsonObject>(pluginJson, {}).version ?? ""
}

export function latestAcmePluginVersion(env: NodeJS.ProcessEnv = process.env): string {
  const result = runCommand(
    "gh",
    [
      "release",
      "list",
      "--repo",
      "jdiegosierra/enterprise-agent-plugins",
      "--limit",
      "20",
      "--json",
      "tagName",
      "-q",
      ".[].tagName",
    ],
    { env },
  )

  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`
  const lines = output.split(/\r?\n/).map((line) => line.trim()).filter(Boolean)
  const tag = lines.find((line) => line.startsWith("acme-engineering-v"))
  return tag?.replace(/^acme-engineering-v/, "") ?? ""
}

export function refreshClaudeStatuslineCache(home: string, latestPlugin: string, env: NodeJS.ProcessEnv = process.env) {
  const cacheFile = path.join(home, ".claude", ".statusline-version-cache.json")
  const latestClaudeCode = runCommand("npm", ["view", "@anthropic-ai/claude-code", "version"], {
    env,
  }).stdout?.trim() ?? ""

  writeJsonFile(cacheFile, {
    latest_plugin: latestPlugin,
    latest_cc: latestClaudeCode,
  })
}

export function createClaudeHookOutput(output: ClaudeHookOutput): string {
  return JSON.stringify(output)
}

export function cleanupMarkers(markerDir: string, prefix: string, currentName: string) {
  if (!existsSync(markerDir)) return
  for (const entry of readdirSync(markerDir)) {
    if (!entry.startsWith(prefix) || entry === currentName) continue
    try {
      unlinkSync(path.join(markerDir, entry))
    } catch {
      // Ignore cleanup failures.
    }
  }
}

export function topicFromTranscript(transcriptPath: string): string {
  if (!transcriptPath || !existsSync(transcriptPath)) return ""

  const lines = readFileSync(transcriptPath, "utf8").split(/\r?\n/).slice(0, 30)
  for (const line of lines) {
    if (!line.trim()) continue
    const payload = safeJsonParse<any>(line, null)
    if (!payload || payload.type !== "user") continue

    const content = payload.message?.content
    let text = ""
    if (typeof content === "string") text = content
    if (Array.isArray(content)) {
      const firstText = content.find((item) => item?.type === "text" && typeof item?.text === "string")
      text = firstText?.text ?? ""
    }

    text = text.trim()
    if (!text || text.includes("<command-") || text === "null") continue
    if (text.length > 80) return `${text.slice(0, 77)}...`
    return text
  }

  return ""
}

export function sendDesktopNotification(title: string, message: string, iconPath?: string, env: NodeJS.ProcessEnv = process.env) {
  if (commandExists("terminal-notifier", env)) {
    const args = ["-title", title, "-message", message, "-group", `acme-${Date.now()}`]
    if (iconPath && existsSync(iconPath)) {
      args.push("-appIcon", iconPath, "-contentImage", iconPath)
    }
    runCommand("terminal-notifier", args, { env })
    return
  }

  if (commandExists("osascript", env)) {
    runCommand("osascript", ["-e", `display notification \"${message}\" with title \"${title}\"`], { env })
    return
  }

  if (commandExists("notify-send", env)) {
    runCommand("notify-send", [title, message], { env })
  }
}

export function readNotificationConfig(filePath: string): NotificationConfig {
  return readJsonFile<NotificationConfig>(filePath, {})
}

export function readProjectInstruction(directory?: string): ProjectInstruction | null {
  if (!directory) return null

  for (const name of ["AGENTS.md", "CLAUDE.md"]) {
    const filePath = path.join(directory, name)
    if (!existsSync(filePath)) continue

    const content = readFileSync(filePath, "utf8").trim()
    if (!content) continue
    return { filePath, content }
  }

  return null
}

function projectInstructionContext(directory?: string): string | null {
  const instruction = readProjectInstruction(directory)
  if (!instruction) return null

  return `IMPORTANT: The current repository contains project instructions in \`${path.basename(instruction.filePath)}\`. These instructions apply to all work in this repo:\n\n${instruction.content}`
}

export function plainTextFromValue(value: unknown): string {
  if (!value) return ""
  if (typeof value === "string") return value
  if (Array.isArray(value)) return value.map((item) => plainTextFromValue(item)).filter(Boolean).join(" ")
  if (typeof value === "object") {
    const record = value as Record<string, any>
    if (typeof record.text === "string") return record.text
    if (typeof record.content === "string") return record.content
    if (Array.isArray(record.content)) return plainTextFromValue(record.content)
    if (Array.isArray(record.parts)) return plainTextFromValue(record.parts)
    if (record.message) return plainTextFromValue(record.message)
  }
  return ""
}

function looksLikeExplicitConfirmation(value: string): boolean {
  const normalized = value.trim().toLowerCase()
  if (!normalized) return false
  return /\b(yes|yep|yeah|ok|okay|confirm|confirmed|go ahead|proceed|send it|ship it|create it|do it|dale|si|sí|adelante|hazlo|envialo|envíalo|confirma|confirmado|crealo|créalo|creala|créala)\b/i.test(normalized)
}

function summarizeField(value: unknown, maxLength = 60): string {
  const text = plainTextFromValue(value).trim()
  if (!text) return ""
  if (text.length <= maxLength) return text
  return `${text.slice(0, maxLength - 3)}...`
}

export function evaluateMessagingToolGuard(input: MessagingGuardInput): string | null {
  const toolName = String(input.toolName || "")
  const latestUserMessage = summarizeField(input.latestUserMessage, 200)
  const confirmed = looksLikeExplicitConfirmation(latestUserMessage)
  if (confirmed) return null

  const args = input.args || {}

  if (/slack_(send_message|schedule_message)/i.test(toolName)) {
    const channelName = summarizeField(args.channel_name ?? args.channelName ?? args.channel)
    const channelId = summarizeField(args.channel_id ?? args.channelId ?? args.conversation_id ?? args.conversationId)
    const renderedChannel = [channelName, channelId && channelId !== channelName ? channelId : ""].filter(Boolean).join(" / ")
    return [
      "[SLACK MESSAGE GUARD] Before sending, you MUST: (1) show the user the exact message content,",
      `(2) show the target channel NAME and ID${renderedChannel ? ` (current target: ${renderedChannel})` : ""},`,
      "(3) ask for explicit confirmation.",
      "High-visibility channels (#incidents, #general, #engineering, #engineering-lead, #sre-alerts) require extra caution — state the audience size.",
      "After the user explicitly confirms, retry the tool call.",
    ].join(" ")
  }

  if (/createjiraissue/i.test(toolName)) {
    const projectKey = summarizeField(args.projectKey ?? args.project ?? args.project_key)
    const summary = summarizeField(args.summary ?? args.title)
    const issueType = summarizeField(args.issueType ?? args.issue_type ?? args.type)
    return [
      "[JIRA TICKET GUARD] Before creating, you MUST: (1) show the user the project key",
      `${projectKey ? `(${projectKey}) ` : ""}and confirm it matches the routing guide,`,
      `(2) show the summary${summary ? ` (${summary})` : ""} and issue type${issueType ? ` (${issueType})` : ""},`,
      "(3) ask for explicit confirmation.",
      "After the user explicitly confirms, retry the tool call.",
    ].join(" ")
  }

  return null
}

export function buildClaudeMessagingGuardText(toolName: string, args?: Record<string, any>): string {
  return evaluateMessagingToolGuard({ toolName, args }) ?? ""
}

export function defaultHome(home?: string) {
  return home || process.env.HOME || os.homedir()
}

export function buildClaudeWelcomeOutput(pluginRoot: string, home: string): string | null {
  const version = currentClaudeVersion(pluginRoot)
  if (!version) return null

  const markerDir = path.join(home, ".claude")
  const markerName = `.acme-welcomed-${version}`
  const markerFile = path.join(markerDir, markerName)

  if (existsSync(markerFile)) return null

  mkdirSync(markerDir, { recursive: true })
  writeTextFile(markerFile, "")
  cleanupMarkers(markerDir, ".acme-welcomed-", markerName)

  const skillCount = countDirectories(path.join(pluginRoot, "skills")) || "many"
  const welcome = `Welcome to the Acme plugin v${version}!\n\nThe plugin includes specialized agents, ${skillCount} skills, CLI safety guards, and commands to streamline your workflow.\n\nRun \`/acme-engineering:setup\` to configure your environment:\n- **CLI tools** — GitHub (gh), Kubernetes (kubectl/helm)\n- **AWS CLI profiles** — SSO access to environments\n- **Notifications** — desktop alerts when long tasks finish\n\nType \`/acme-engineering:help\` to see everything the plugin can do.`

  const context = `IMPORTANT: This is the user's first session with the Acme plugin v${version}. Welcome them briefly and present the following guide:\n\n${welcome}`

  return createClaudeHookOutput({
    systemMessage: `Acme plugin v${version} installed — show welcome guide to user`,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context,
    },
  })
}

export function buildClaudeSessionRulesOutput(pluginRoot: string): string {
  const pluginVersion = currentClaudeVersion(pluginRoot) || "unknown"
  const skillCount = countDirectories(path.join(pluginRoot, "skills")) || "many"

  const context = `IMPORTANT — these rules apply to ALL work in this session (main conversation and subagents).\n\n## Acme Engineering Plugin (v${pluginVersion})\n\nThe user has the \`acme-engineering\` plugin installed (source: \`jdiegosierra/enterprise-agent-plugins\`).\n\n**Commands** (invoke via \`/acme-engineering:<name>\`): help, setup, run-tests, lint-fix\n\n**Agents**: backend-developer (Go/Python, AWS/K8s), frontend-developer (TS/React/Vue), sre (infra, monitoring, incidents)\n\n**Skills**: ${skillCount} skills — platform map, Kubernetes, SRE runbooks, and best practices.\n\n## Language rule\n\nAll code artifacts must be in **English**: code comments, commit messages, PR titles/descriptions, variable/function names, documentation, log messages, error messages.\n\n## CLI preference\n\n**Always prefer CLI tools** over MCPs — they are faster and have the full API surface:\n- **GitHub**: \`gh\`\n- **Kubernetes**: \`kubectl\` and \`helm\`\n- **AWS**: \`aws\` CLI\n\n## Development guidelines\n\n- **Always ask for explicit user confirmation before running git commit or git push.**\n- Never push to main or master directly. Always work through PRs.\n- **Always use squash merge** when merging PRs via \`gh pr merge\` — use the \`--squash\` flag.\n- When in doubt about the base branch, ask the user.\n- **Always sync before working on any project** — run \`git fetch origin\` and check if behind upstream.\n- **Never use cd in Bash commands** — use absolute paths or tool flags (git -C, gh --repo).`

  return createClaudeHookOutput({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context,
    },
  })
}

export function buildClaudeProjectContextOutput(directory: string): string | null {
  const context = projectInstructionContext(directory)
  if (!context) return null

  return createClaudeHookOutput({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context,
    },
  })
}

type ClaudeSetupStatus = Record<string, string>

const CLAUDE_SETUP_ITEMS = [
  "cli_gh",
  "cli_kubectl",
  "notifications",
] as const

function detectClaudeMcp(home: string, oldKey: string, newKey: string): boolean {
  const settings = readJsonFile<JsonObject>(path.join(home, ".claude", "settings.json"), {})
  const globalConfig = readJsonFile<JsonObject>(path.join(home, ".claude.json"), {})
  if (settings.mcpServers?.[oldKey]) return true
  if (globalConfig.mcpServers?.[newKey]) return true
  return false
}

function maybeMarkClaudeSetupItem(home: string, setup: ClaudeSetupStatus, key: string, status: string) {
  setup[key] = status
  writeJsonFile(path.join(home, ".claude", ".acme-setup.json"), setup)
}

export function buildClaudeOnboardingOutput(home: string): string | null {
  const setupFile = path.join(home, ".claude", ".acme-setup.json")
  const setup = readJsonFile<ClaudeSetupStatus>(setupFile, {})

  for (const item of CLAUDE_SETUP_ITEMS) {
    if (setup[item]) continue

    let detected = false
    switch (item) {
      case "cli_gh":
        detected = commandExists("gh", { ...process.env, HOME: home })
        break
      case "cli_kubectl":
        detected = commandExists("kubectl", { ...process.env, HOME: home })
        break
      case "notifications":
        detected = existsSync(path.join(home, ".claude", ".acme-notify-config.json"))
        break
      default:
        detected = false
    }

    if (detected) maybeMarkClaudeSetupItem(home, setup, item, "completed")
  }

  const pendingCount = CLAUDE_SETUP_ITEMS.filter((item) => !setup[item]).length
  if (pendingCount === 0) return null

  const parts: string[] = []
  if (pendingCount > 0) {
    parts.push("The Acme plugin has pending items to configure. Briefly suggest the user run /acme-engineering:setup to complete their setup. Keep it to one short sentence.")
  }

  return createClaudeHookOutput({
    systemMessage: "Acme plugin — pending setup items",
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: parts.join(" "),
    },
  })
}

function readFileSyncIfExists(filePath: string): string {
  try {
    return readFileSync(filePath, "utf8")
  } catch {
    return ""
  }
}

export function buildClaudeUpdateOutput(pluginRoot: string, home: string, env: NodeJS.ProcessEnv = process.env): string | null {
  const latest = latestAcmePluginVersion(env)
  if (!latest) return null

  const current = currentClaudeVersion(pluginRoot)
  if (!current) return null

  refreshClaudeStatuslineCache(home, latest, env)
  if (!versionGreater(latest, current)) return null

  const message = `acme plugin update available: v${current} → v${latest}. Run /acme-engineering:update to upgrade.`
  const context = `IMPORTANT: Inform the user once that an acme plugin update is available (v${current} → v${latest}). Tell them to run /acme-engineering:update to upgrade.`

  return createClaudeHookOutput({
    systemMessage: message,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context,
    },
  })
}

export function runClaudeNotification(home: string, rawInput: string, pluginRoot: string) {
  const input = safeJsonParse<JsonObject>(rawInput, {})
  if (input.stop_hook_active === true) return

  const configFile = path.join(home, ".claude", ".acme-notify-config.json")
  const config = readNotificationConfig(configFile)
  const channels = Array.isArray(config.channels) && config.channels.length > 0 ? config.channels : ["desktop"]
  if (!channels.includes("desktop")) return

  const cwd = typeof input.cwd === "string" ? input.cwd : process.cwd()
  const project = basenameSafe(cwd) || "project"
  const transcriptPath = typeof input.transcript_path === "string" ? input.transcript_path : ""
  const topic = topicFromTranscript(transcriptPath)

  const title = `Claude Code · ${project}`
  const message = topic || "Response complete"
  const iconPath = path.join(pluginRoot, "hooks", "assets", "icon.png")
  sendDesktopNotification(title, message, iconPath, { ...process.env, HOME: home })
}

export function evaluateDangerousBashCommand(command: string): string | null {
  if (!command) return null
  if (command.includes("ACME_GUARD_CONFIRMED=yes")) return null

  const git = /\bgit\b/i.test(command)
  if (git && /push\s+.*--force|push\s+.*-f\b|push\s+.*--delete|push\s+origin\s+:[a-zA-Z]|reset\s+--hard|clean\s+-[a-zA-Z]*f|branch\s+-D|worktree\s+remove|checkout\s+\.\s*$|checkout\s+--\s+\.|restore\s+--staged\s+\.|restore\s+\.|stash\s+(drop|clear)\b|tag\s+-d\b/i.test(command)) {
    return "[DESTRUCTIVE GIT] You MUST confirm with the user before proceeding. Show: (1) the exact command, (2) what will be lost or overwritten, (3) the affected branch/worktree. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r|\brm\s+-rf|\brm\s+-fr|\brm\s+-r\s+-f|\brm\s+-f\s+-r|\brm\s+--recursive|\bfind\b.*\s-delete\b/i.test(command)) {
    return "[DESTRUCTIVE SHELL] Recursive delete detected (rm -rf / find -delete). You MUST confirm with the user before proceeding. Show: (1) the exact paths to be deleted, (2) whether this is reversible. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\bkill\s+-9|\bkill\s+-SIGKILL|\bkill\s+-KILL|\bkill\s+-s\s+(9|KILL|SIGKILL)|\bkill\s+--signal\s+(9|KILL|SIGKILL)|\bkillall\b|\bpkill\b/i.test(command)) {
    return "[DESTRUCTIVE PROCESS] kill -9/killall/pkill detected. You MUST confirm with the user before proceeding. Show: (1) the process(es) to be killed, (2) potential side effects (data loss, broken connections). After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\b(chmod|chown)\s+-[a-zA-Z]*R/i.test(command)) {
    return "[DESTRUCTIVE PERMISSIONS] Recursive chmod/chown detected. You MUST confirm with the user before proceeding. Show: (1) the target path, (2) the permission/owner change, (3) how many files will be affected. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\bcurl\b.*\|\s*(bash|sh|zsh)\b|\bwget\b.*\|\s*(bash|sh|zsh)\b/i.test(command)) {
    return "[DANGEROUS EXECUTION] Piping remote content to a shell detected. You MUST confirm with the user before proceeding. Show: (1) the URL being fetched, (2) whether the source is trusted. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\baws\b/i.test(command) && /s3\s+(rm|rb)\s+.*--recursive|s3\s+rb\b|ec2\s+terminate-instances|rds\s+delete-db|cloudformation\s+delete-stack|ecs\s+delete-service|ecs\s+deregister-task-definition|lambda\s+delete-function|dynamodb\s+delete-table|sqs\s+delete-queue|sns\s+delete-topic|ecr\s+delete-repository|secretsmanager\s+delete-secret|iam\s+delete-role|iam\s+delete-policy|eks\s+delete-cluster|eks\s+delete-nodegroup/i.test(command)) {
    return "[DESTRUCTIVE AWS] Destructive AWS operation detected. You MUST confirm with the user before proceeding. Show: (1) the AWS profile/account, (2) the resource to be deleted, (3) whether this is reversible. For PRODUCTION accounts: use the word PRODUCTION in caps and require the user to type YES. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\bterraform\s+destroy|\bterraform\s+apply\s+.*-destroy|\bterraform\s+state\s+rm|\bpulumi\s+destroy|\btofu\s+destroy|\btofu\s+apply\s+.*-destroy|\btofu\s+state\s+rm/i.test(command)) {
    return "[DESTRUCTIVE IAC] Infrastructure destroy/state removal detected. You MUST confirm with the user before proceeding. Show: (1) the stack/workspace, (2) the environment, (3) the resources that will be destroyed or removed from state. For PRODUCTION: require the user to type YES. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\bdocker\b|\bdocker-compose\b/i.test(command) && /system\s+prune|image\s+prune|container\s+prune|volume\s+prune|network\s+prune|volume\s+rm|volume\s+remove|compose\s+down\s+.*-v|compose\s+down\s+.*--volumes|docker-compose\s+down\s+.*-v|docker-compose\s+down\s+.*--volumes/i.test(command)) {
    return "[DESTRUCTIVE DOCKER] Docker data-loss operation detected (prune/volume rm/down -v). You MUST confirm with the user before proceeding. Show: (1) what data will be lost (volumes, images, containers), (2) whether any volumes contain persistent data. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\b(psql|mongosh|mongo|mysql|mariadb)\b/i.test(command) && /DROP\s+(DATABASE|TABLE|COLLECTION|INDEX)|TRUNCATE\s+TABLE|dropDatabase|dropCollection|\.drop\(/i.test(command)) {
    return "[DESTRUCTIVE DATABASE] DROP/TRUNCATE operation detected via database CLI. You MUST confirm with the user before proceeding. Show: (1) the database/collection/table, (2) the environment, (3) the connection endpoint. For PRODUCTION: require the user to type YES. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\b(mongosh|mongo)\b/i.test(command) && /\.insert|\.update|\.delete|\.remove|\.replaceOne|\.bulkWrite|\.save\b|\.findOneAndDelete|\.findOneAndReplace|\.findOneAndUpdate|\.deleteOne|\.deleteMany|\.updateOne|\.updateMany|\.insertOne|\.insertMany/i.test(command)) {
    return "[WRITE OPERATION — DocumentDB] You MUST confirm with the user before proceeding. State clearly: (1) the environment, (2) the database name, (3) the collection, (4) the exact operation and affected documents. For PRODUCTION: use the word PRODUCTION in caps, show the connection endpoint, and require the user to type YES to confirm. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\bkubectl\b/i.test(command) && !/\baws\b.*\beks\b.*\bupdate-kubeconfig\b/i.test(command) && /\bkubectl\s+(delete|drain|cordon)\b|\bkubectl\s+apply\s+.*--prune|\bkubectl\s+replace\s+.*--force/i.test(command)) {
    return "[DESTRUCTIVE KUBECTL] You MUST confirm with the user before proceeding. Show: (1) cluster context, (2) namespace, (3) resource, (4) action. For PRODUCTION: require the user to type YES. After confirmation, prefix with ACME_GUARD_CONFIRMED=yes."
  }

  if (/\bgh\b/i.test(command) && /\bgh\s+(repo\s+delete|repo\s+archive|release\s+delete|issue\s+delete|issue\s+close|pr\s+merge|pr\s+close)|\bgh\s+api\s+.*-X\s+DELETE/i.test(command)) {
    return "[DESTRUCTIVE GITHUB] Destructive gh operation detected. You MUST confirm with the user before proceeding. Show: (1) the exact command, (2) the target repository/resource, (3) whether this is reversible. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
  }

  if (/\b(valkey-cli|redis-cli)\b/i.test(command)) {
    if (/FLUSHALL|FLUSHDB/i.test(command)) {
      return "[BLOCKED] FLUSHALL/FLUSHDB detected — this will delete ALL data in the cluster. You MUST confirm with the user first. Show: (1) cluster endpoint, (2) environment, (3) exact command. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
    }
    if (/\bDEL\s/i.test(command)) {
      return "[BLOCKED] DEL command detected. You MUST confirm with the user first. Show: (1) cluster endpoint, (2) environment, (3) key(s) to delete. After user confirms, prefix the command with ACME_GUARD_CONFIRMED=yes to proceed."
    }
    if (/\bKEYS\s+\*/i.test(command)) {
      return "[BLOCKED] KEYS * is dangerous on production clusters — it blocks the entire cluster while scanning. Use SCAN instead. Example: valkey-cli ... SCAN 0 COUNT 100"
    }
  }

  return null
}

type OpenCodeSetupStatus = Record<string, string>

const OPENCODE_SETUP_ITEMS = [
  "cli_gh",
  "cli_kubectl",
  "notifications",
] as const

export function buildOpenCodeWelcomeText(pluginRoot: string, home: string): string | null {
  const version = currentOpenCodeVersion(pluginRoot)
  if (!version) return null

  const markerDir = path.join(home, ".config", "opencode")
  const markerName = `.acme-welcomed-${version}`
  const markerFile = path.join(markerDir, markerName)
  if (existsSync(markerFile)) return null

  mkdirSync(markerDir, { recursive: true })
  writeTextFile(markerFile, "")
  cleanupMarkers(markerDir, ".acme-welcomed-", markerName)

  const skillCount = countDirectories(path.join(pluginRoot, "opencode", "skills")) || countDirectories(path.join(pluginRoot, "src", "skills")) || "many"
  return `IMPORTANT: This is the user's first OpenCode session with the Acme engineering plugin v${version}. Welcome them briefly and tell them that the plugin now includes ${skillCount} skills, agents, custom /acme-* commands, and safety plugins. Recommend running /acme-setup to verify AWS CLI, gh, kubectl, and notifications.`
}

export function buildOpenCodeSessionRulesText(pluginRoot: string): string {
  const version = currentOpenCodeVersion(pluginRoot) || "unknown"
  const skillCount = countDirectories(path.join(pluginRoot, "opencode", "skills")) || countDirectories(path.join(pluginRoot, "src", "skills")) || "many"
  return `IMPORTANT — these rules apply to ALL work in this OpenCode session (main conversation and subagents).\n\n## Acme Engineering Plugin (OpenCode v${version})\n\nThe user has the Acme engineering plugin installed for OpenCode.\n\n**Commands**: /acme-help, /acme-setup, /acme-run-tests, /acme-lint-fix, /acme-notify-config, /acme-slack-notify, /acme-slack-summary, /acme-reset, /acme-uninstall, /acme-update.\n\n**Agents**: backend-developer, frontend-developer, sre.\n\n**Skills**: ${skillCount} skills — platform map, Kubernetes, SRE runbooks, and best practices.\n\n## Language rule\n\nAll code artifacts must be in English even if the user speaks in another language.\n\n## CLI vs MCP preference\n\nAlways prefer CLI tools over MCPs when both can do the same work. Use gh for GitHub, kubectl/helm for Kubernetes, aws for AWS.\n\n## Git workflow\n\nAlways fetch before analyzing or changing a git repository. Never push directly to main or master. Ask for explicit confirmation before git commit or git push. Always use squash merge for PRs.\n\n## Safety\n\nDo not perform destructive shell, git, Kubernetes, database, or cloud operations without explicit user confirmation. Treat production actions with extra caution.`
}

export function buildOpenCodeProjectContextText(directory?: string): string | null {
  return projectInstructionContext(directory)
}

export function buildOpenCodeOnboardingText(home: string): string | null {
  const setupFile = path.join(home, ".config", "opencode", ".acme-setup.json")
  const setup = readJsonFile<OpenCodeSetupStatus>(setupFile, {})

  for (const item of OPENCODE_SETUP_ITEMS) {
    if (setup[item]) continue

    let detected = false
    switch (item) {
      case "cli_gh":
        detected = commandExists("gh", { ...process.env, HOME: home })
        break
      case "cli_kubectl":
        detected = commandExists("kubectl", { ...process.env, HOME: home })
        break
      case "notifications":
        detected = existsSync(path.join(home, ".config", "opencode", ".acme-notify-config.json"))
        break
      default:
        detected = false
    }

    if (detected) {
      setup[item] = "completed"
      writeJsonFile(setupFile, setup)
    }
  }

  const pending = OPENCODE_SETUP_ITEMS.filter((item) => !setup[item])
  if (pending.length === 0) return null
  return "The Acme engineering plugin still has pending OpenCode setup items. Briefly suggest running /acme-setup to verify AWS CLI profiles, gh, kubectl, and notifications. Keep it to one short sentence."
}

export function buildOpenCodeUpdateText(pluginRoot: string, env: NodeJS.ProcessEnv = process.env): string | null {
  const latest = latestAcmePluginVersion(env)
  const current = currentOpenCodeVersion(pluginRoot)
  if (!latest || !current || !versionGreater(latest, current)) return null
  return `A newer Acme engineering plugin release is available for OpenCode (v${current} -> v${latest}). Mention it once and suggest running /acme-update.`
}
