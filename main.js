const electron = require('electron')
const menubar = require('menubar')
const mb = menubar({width: 220, height: 206, preloadWindow: true, alwaysOnTop: true})

mb.on('ready', () => {
  console.log('app is ready')
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`)
  mb.window.openDevTools()
})

