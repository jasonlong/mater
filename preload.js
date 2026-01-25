const {contextBridge, ipcRenderer} = require('electron')

contextBridge.exposeInMainWorld('mater', {
  platform: process.platform, // eslint-disable-line n/prefer-global/process
  appPath: __dirname,

  setTrayIcon(iconPath) {
    ipcRenderer.send('SET_TRAY_ICON', iconPath)
  },

  hideWindow() {
    ipcRenderer.send('HIDE_WINDOW')
  },

  showWindow() {
    ipcRenderer.send('SHOW_WINDOW')
  },

  onToggleSound(callback) {
    ipcRenderer.on('TOGGLE_SOUND', (event, enabled) => callback(enabled))
  }
})
