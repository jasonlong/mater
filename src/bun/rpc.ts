import type { ElectrobunRPCSchema } from 'electrobun/bun'

export type MaterRPC = ElectrobunRPCSchema<{
  // biome-ignore lint/complexity/noBannedTypes: Electrobun RPC schema requires empty object for unused requests
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
