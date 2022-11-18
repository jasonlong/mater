const {Menu} = require('electron')
const platform = require('node:os').platform()
const path = require('node:path')
const {menubar} = require('menubar')

const initialIcon = path.join(__dirname, 'img/png/blank.png')

const mb = menubar({
  preloadWindow: true,
  icon: initialIcon,
  browserWindow: {
    width: 220,
    height: 206,
    webPreferences: {
      nodeIntegration: true,
      enableRemoteModule: true
    }
  }
})

// Make menubar accessible to the renderer
global.sharedObject = {mb}

mb.on('ready', () => {
  console.log('app is ready')
  // Workaround to fix window position when statusbar at top for win32
  if (platform === 'win32' && mb.tray.getBounds().y < 5) {
    mb.setOption('windowPosition', 'trayCenter')
  }
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`) // eslint-disable-line n/no-path-concat

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
