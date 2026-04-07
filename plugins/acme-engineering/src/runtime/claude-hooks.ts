import {
  buildClaudeMessagingGuardText,
  buildClaudeOnboardingOutput,
  buildClaudeProjectContextOutput,
  buildClaudeSessionRulesOutput,
  buildClaudeUpdateOutput,
  buildClaudeWelcomeOutput,
  defaultHome,
  evaluateDangerousBashCommand,
  readStdin,
  runClaudeNotification,
} from "./common.ts"
import { fileURLToPath } from "node:url"

function fail(message: string): never {
  process.stderr.write(`${message}\n`)
  process.exit(2)
}

function main() {
  const hook = process.argv[2]
  const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || fileURLToPath(new URL("../../claude/", import.meta.url))
  const home = defaultHome()

  switch (hook) {
    case "bash-safety-guard": {
      let input: Record<string, any> = {}
      try {
        input = JSON.parse(readStdin() || "{}")
      } catch {
        input = {}
      }
      const command = input?.tool_input?.command ?? ""
      const denial = evaluateDangerousBashCommand(command)
      if (denial) fail(denial)
      return
    }
    case "welcome": {
      const output = buildClaudeWelcomeOutput(pluginRoot, home)
      if (output) process.stdout.write(output)
      return
    }
    case "session-rules": {
      process.stdout.write(buildClaudeSessionRulesOutput(pluginRoot))
      return
    }
    case "onboarding": {
      const output = buildClaudeOnboardingOutput(home)
      if (output) process.stdout.write(output)
      return
    }
    case "check-update": {
      const output = buildClaudeUpdateOutput(pluginRoot, home)
      if (output) process.stdout.write(output)
      return
    }
    case "notify": {
      runClaudeNotification(home, readStdin(), pluginRoot)
      return
    }
    case "slack-message-guard": {
      let input: Record<string, any> = {}
      try {
        input = JSON.parse(readStdin() || "{}")
      } catch {
        input = {}
      }
      const output = buildClaudeMessagingGuardText("slack_send_message", input.tool_input)
      if (output) process.stdout.write(output)
      return
    }
    case "jira-ticket-guard": {
      let input: Record<string, any> = {}
      try {
        input = JSON.parse(readStdin() || "{}")
      } catch {
        input = {}
      }
      const output = buildClaudeMessagingGuardText("createJiraIssue", input.tool_input)
      if (output) process.stdout.write(output)
      return
    }
    case "project-context": {
      const output = buildClaudeProjectContextOutput(process.cwd())
      if (output) process.stdout.write(output)
      return
    }
    default:
      process.stderr.write(`Unknown Claude hook: ${hook}\n`)
      process.exit(1)
  }
}

try {
  main()
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`)
  process.exit(1)
}
