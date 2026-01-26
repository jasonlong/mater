import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './test',
  timeout: 30_000,
  retries: 0,
  use: {
    trace: 'on-first-retry'
  }
})
