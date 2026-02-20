import type { ElectrobunRPCSchema } from "electrobun/bun"

export type MaterRPC = ElectrobunRPCSchema<{
  requests: {}
  messages: {
    // View -> Bun
    setTrayIcon: { iconPath: string }
    hideWindow: Record<string, never>
    showWindow: Record<string, never>
    quitApp: Record<string, never>
    // Bun -> View
    toggleSound: { enabled: boolean }
  }
}>
