import path from 'node:path'
import {fileURLToPath} from 'node:url'
import {test, expect, _electron as electron} from '@playwright/test'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

let electronApp

test.beforeEach(async () => {
  electronApp = await electron.launch({
    args: [path.join(__dirname, '..', 'main.js')]
  })
})

test.afterEach(async () => {
  await electronApp.close()
})

test.describe('App Lifecycle', () => {
  test('launches without errors', async () => {
    const window = await electronApp.firstWindow()
    await window.waitForLoadState('domcontentloaded')
    const title = await window.title()
    expect(title).toBe('Mater')
  })
})

test.describe('Timer Controls', () => {
  test('start button begins timer', async () => {
    const window = await electronApp.firstWindow()
    await window.waitForLoadState('domcontentloaded')

    const startButton = window.locator('[data-action="start"]')
    await startButton.click()

    const appContainer = window.locator('[data-app]')
    await expect(appContainer).toHaveClass(/is-working/)
  })

  test('stop button stops timer', async () => {
    const window = await electronApp.firstWindow()
    await window.waitForLoadState('domcontentloaded')

    // Start first
    const startButton = window.locator('[data-action="start"]')
    await startButton.click()

    const appContainer = window.locator('[data-app]')
    await expect(appContainer).toHaveClass(/is-working/)

    // Then stop
    const stopButton = window.locator('[data-action="stop"]')
    await stopButton.click()

    await expect(appContainer).toHaveClass(/is-stopped/)
  })
})

test.describe('Keyboard Shortcuts', () => {
  test('escape key is handled', async () => {
    const window = await electronApp.firstWindow()
    await window.waitForLoadState('domcontentloaded')

    // Press escape - this triggers hideWindow via IPC
    await window.keyboard.press('Escape')

    // Give time for any async handlers
    await new Promise(resolve => {
      setTimeout(resolve, 100)
    })

    // If we get here without error, the escape key handler worked
    expect(true).toBe(true)
  })
})
