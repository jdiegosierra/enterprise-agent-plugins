import path from "node:path"
import { fileURLToPath } from "node:url"
import {
  basenameSafe,
  buildOpenCodeOnboardingText,
  buildOpenCodeProjectContextText,
  buildOpenCodeSessionRulesText,
  buildOpenCodeUpdateText,
  buildOpenCodeWelcomeText,
  defaultHome,
  evaluateMessagingToolGuard,
  evaluateDangerousBashCommand,
  plainTextFromValue,
  readNotificationConfig,
  sendDesktopNotification,
} from "./common.ts"

const moduleDir = path.dirname(fileURLToPath(import.meta.url))
const pluginRoot = path.dirname(path.dirname(moduleDir))
const home = defaultHome()
const sessionState = new Map<string, { directory: string; title?: string; lastUserMessage?: string }>()

export const MaisaEngineeringPlugin = async () => {
  return {
    event: async ({ event }: { event: { type: string; properties?: Record<string, any> } }) => {
      if (event.type === "session.created" || event.type === "session.updated") {
        const sessionID = event.properties?.sessionID as string | undefined
        const info = event.properties?.info as { directory?: string; title?: string } | undefined
        if (sessionID && info?.directory) {
          sessionState.set(sessionID, {
            directory: info.directory,
            title: info.title,
            lastUserMessage: sessionState.get(sessionID)?.lastUserMessage,
          })
        }
        return
      }

      if (event.type !== "session.idle") return

      const sessionID = event.properties?.sessionID as string | undefined
      const state = sessionID ? sessionState.get(sessionID) : undefined
      const config = readNotificationConfig(path.join(home, ".config", "opencode", ".acme-notify-config.json"))
      const channels = Array.isArray(config.channels) && config.channels.length > 0 ? config.channels : ["desktop"]
      if (!channels.includes("desktop")) return

      const project = basenameSafe(state?.directory ?? "") || "project"
      const title = `OpenCode · ${project}`
      const message = state?.title?.trim() || "Response complete"
      sendDesktopNotification(title, message)
    },

    "chat.message": async (
      input: { sessionID: string },
      output: { message: unknown; parts: unknown[] },
    ) => {
      const text = plainTextFromValue(output.parts?.length ? output.parts : output.message).trim()
      if (!text) return
      const current = sessionState.get(input.sessionID)
      sessionState.set(input.sessionID, {
        directory: current?.directory || "",
        title: current?.title,
        lastUserMessage: text,
      })
    },

    "experimental.chat.system.transform": async (input: { sessionID?: string }, output: { system: string[] }) => {
      output.system.push(buildOpenCodeSessionRulesText(pluginRoot))

      const projectContext = buildOpenCodeProjectContextText(
        input.sessionID ? sessionState.get(input.sessionID)?.directory : undefined,
      )
      if (projectContext) output.system.push(projectContext)

      const welcome = buildOpenCodeWelcomeText(pluginRoot, home)
      if (welcome) output.system.push(welcome)

      const onboarding = buildOpenCodeOnboardingText(home)
      if (onboarding) output.system.push(onboarding)

      const update = buildOpenCodeUpdateText(pluginRoot)
      if (update) output.system.push(update)
    },

    "tool.execute.before": async (
      input: { tool: string; sessionID: string },
      output: { args: Record<string, any> },
    ) => {
      if (input.tool === "bash") {
        const command = typeof output.args?.command === "string" ? output.args.command : ""
        const denial = evaluateDangerousBashCommand(command)
        if (denial) throw new Error(denial)
      }

      const guard = evaluateMessagingToolGuard({
        toolName: input.tool,
        args: output.args,
        latestUserMessage: sessionState.get(input.sessionID)?.lastUserMessage,
      })
      if (guard) throw new Error(guard)
    },
  }
}
