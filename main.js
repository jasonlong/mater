const {Menu, ipcMain} = require('electron')
const platform = require('os').platform()
const path = require('path')
const {menubar} = require('menubar')

const initialIcon = path.join(__dirname, 'img/png/blank.png')

const mb = menubar({
  preloadWindow: true,
  icon: initialIcon,
  index: `file://${__dirname}/index.html`, // eslint-disable-line n/no-path-concat
  browserWindow: {
    width: 220,
    height: 206,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      preload: path.join(__dirname, 'preload.js')
    }
  }
})

mb.on('ready', () => {
  console.log('app is ready')
  // Workaround to fix window position when statusbar at top for win32
  if (platform === 'win32' && mb.tray.getBounds().y < 5) {
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
          click: () => mb.window.webContents.send('TOGGLE_SOUND', true)
        },
        {
          label: 'Off',
          type: 'radio',
          checked: false,
          click: () => mb.window.webContents.send('TOGGLE_SOUND', false)
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

ipcMain.on('SET_TRAY_ICON', (event, iconPath) => {
  mb.tray.setImage(iconPath)
})

ipcMain.on('HIDE_WINDOW', () => {
  mb.hideWindow()
})

ipcMain.on('SHOW_WINDOW', () => {
  mb.showWindow()
})
