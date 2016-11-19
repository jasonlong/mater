const electron = require('electron')
const menubar = require('menubar')
const mb = menubar({width: 220, height: 206})

mb.on('ready', () => {
  console.log('app is ready')
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`)
})

