const electron = require('electron')
const menubar = require('menubar')
const mb = menubar({width: 220, height: 220})

mb.on('ready', () => {
  console.log('app is ready')
  // your app code here
})

mb.on('after-create-window', () => {
  mb.window.loadURL(`file://${__dirname}/index.html`)
})
