const {defineConfig} = require('@playwright/test')

module.exports = defineConfig({
  testDir: './test',
  timeout: 30_000,
  retries: 0,
  use: {
    trace: 'on-first-retry'
  }
})
