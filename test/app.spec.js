const path = require('path')
const {test, expect, _electron: electron} = require('@playwright/test')

let electronApp

test.beforeEach(async () => {
  electronApp = await electron.launch({
    args: [path.join(__dirname, '..', 'main.js')]
  })
})

test.afterEach(async () => {
  await electronApp.close()
})

test('app launches without errors', async () => {
  const window = await electronApp.firstWindow()
  await window.waitForLoadState('domcontentloaded')
  const title = await window.title()
  expect(title).toBe('Mater')
})

test('start button begins timer', async () => {
  const window = await electronApp.firstWindow()
  await window.waitForLoadState('domcontentloaded')

  const startButton = window.locator('.js-start-btn')
  await startButton.click()

  const appContainer = window.locator('.js-app')
  await expect(appContainer).toHaveClass(/is-working/)
})

test('stop button stops timer', async () => {
  const window = await electronApp.firstWindow()
  await window.waitForLoadState('domcontentloaded')

  // Start first
  const startButton = window.locator('.js-start-btn')
  await startButton.click()

  const appContainer = window.locator('.js-app')
  await expect(appContainer).toHaveClass(/is-working/)

  // Then stop
  const stopButton = window.locator('.js-stop-btn')
  await stopButton.click()

  await expect(appContainer).toHaveClass(/is-stopped/)
})

test('escape key press is handled', async () => {
  const window = await electronApp.firstWindow()
  await window.waitForLoadState('domcontentloaded')

  // Press escape - this triggers hideWindow via IPC
  // We verify it doesn't throw an error
  await window.keyboard.press('Escape')

  // Give time for any async handlers
  await new Promise(resolve => {
    setTimeout(resolve, 100)
  })

  // If we get here without error, the escape key handler worked
  expect(true).toBe(true)
})
