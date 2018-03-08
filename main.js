const {Menu} = require('electron')
const menubar = require('menubar')

require('electron-debug')({showDevTools: true});

const mb = menubar({
  width: 220,
  height: 206,
  preloadWindow: true,
  icon: `${__dirname}/img/icon-0-Template.png`
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
