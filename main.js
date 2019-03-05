const {Menu} = require('electron')
const platform = require('os').platform()
const menubar = require('menubar')

// Toggle with cmd + alt + i
require('electron-debug')({showDevTools: true})

const initialIcon = `${__dirname}/img/png/blank.png`

const mb = menubar({
  width: 220,
  height: 206,
  preloadWindow: true,
  icon: initialIcon
})

// Make menubar accessible to the renderer
global.sharedObject = {mb}

mb.on('ready', () => {
  console.log('app is ready')
  // Workaround to fix window position when statusbar at top for win32
  if (platform === 'win32') {
    if (mb.tray.getBounds().y < 5) {
      mb.setOption('windowPosition', 'trayCenter')
    }
  }
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`)

  const contextMenu = Menu.buildFromTemplate([
    {label: 'Quit', click: () => {
      mb.app.quit()
    }}
  ])
  mb.tray.on('right-click', () => {
    mb.tray.popUpContextMenu(contextMenu)
  })
})
