const {Menu} = require('electron')
const menubar = require('menubar')

// Toggle with cmd + alt + i
require('electron-debug')({showDevTools: true})

const initialIcon = (process.platform === 'darwin' ? `${__dirname}/img/icon-0-Template.png` : `${__dirname}/img/ico/icon-0.ico`)

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
