import { platform } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { ipcMain, Menu } from 'electron'
import { menubar } from 'menubar'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const currentPlatform = platform()

const initialIcon = path.join(__dirname, 'img/png/blank.png')

const mb = menubar({
  preloadWindow: true,
  icon: initialIcon,
  index: `file://${__dirname}/index.html`,
  browserWindow: {
    width: 220,
    height: 206,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      preload: path.join(__dirname, 'preload.cjs')
    }
  }
})

mb.on('ready', () => {
  console.log('app is ready')
  // Workaround to fix window position when statusbar at top for win32
  if (currentPlatform === 'win32' && mb.tray.getBounds().y < 5) {
    mb.setOption('windowPosition', 'trayCenter')
  }
})

mb.on('after-create-window', () => {
  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Sound',
      submenu: [
        {
          label: 'On',
          type: 'radio',
          checked: true,
          click: () => mb.window.webContents.send('mater:toggle-sound', true)
        },
        {
          label: 'Off',
          type: 'radio',
          checked: false,
          click: () => mb.window.webContents.send('mater:toggle-sound', false)
        }
      ]
    },
    {
      label: 'Quit',
      click() {
        mb.app.quit()
      }
    }
  ])
  mb.tray.on('right-click', () => {
    mb.tray.popUpContextMenu(contextMenu)
  })
})

mb.on('after-hide', () => {
  mb.app.hide()
})

ipcMain.on('mater:set-tray-icon', (_event, iconPath) => {
  mb.tray.setImage(iconPath)
})

ipcMain.on('mater:hide-window', () => {
  mb.hideWindow()
})

ipcMain.on('mater:show-window', () => {
  mb.showWindow()
})
