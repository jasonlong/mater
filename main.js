const electron = require('electron')
const menubar = require('menubar')
const mb = menubar({
  width: 220,
  height: 206,
  preloadWindow: true,
  icon: `${__dirname}/img/icon-0-Template.png`
})

require('electron-reload')(__dirname);

// Make menubar accessible to the renderer
global.sharedObject = {
  mb: mb
}

mb.on('ready', () => {
  console.log('app is ready')
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`)
  // mb.window.openDevTools()
})

