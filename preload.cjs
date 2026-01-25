const {contextBridge, ipcRenderer} = require('electron')

contextBridge.exposeInMainWorld('mater', {
  platform: process.platform, // eslint-disable-line n/prefer-global/process
  appPath: __dirname,

  setTrayIcon(iconPath) {
    ipcRenderer.send('mater:set-tray-icon', iconPath)
  },

  hideWindow() {
    ipcRenderer.send('mater:hide-window')
  },

  showWindow() {
    ipcRenderer.send('mater:show-window')
  },

  onToggleSound(callback) {
    const handler = (_event, enabled) => callback(enabled)
    ipcRenderer.on('mater:toggle-sound', handler)
    return () => ipcRenderer.removeListener('mater:toggle-sound', handler)
  }
})
