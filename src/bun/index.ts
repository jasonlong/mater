import { dlopen, FFIType } from 'bun:ffi'
import { BrowserView, BrowserWindow, Screen, Tray, Utils } from 'electrobun/bun'
import type { MaterRPC } from './rpc'

const WINDOW_WIDTH = 240
const WINDOW_HEIGHT = 226
const isMac = process.platform === 'darwin'

// On macOS, use objc_msgSend to fix template flag after setImage().
// Electrobun's setImage doesn't call [image setTemplate:YES], so the icon
// renders dark instead of adapting to the menubar appearance.
let markTrayImageAsTemplate: (() => void) | null = null

if (isMac) {
  // Bind objc_msgSend twice with different arg signatures
  const objc = dlopen('/usr/lib/libobjc.A.dylib', {
    objc_msgSend: { args: [FFIType.ptr, FFIType.ptr], returns: FFIType.ptr },
    sel_registerName: { args: [FFIType.cstring], returns: FFIType.ptr }
  })
  // Second binding with 3 args (for setTemplate: which takes a BOOL/ptr)
  const objc3 = dlopen('/usr/lib/libobjc.A.dylib', {
    objc_msgSend: {
      args: [FFIType.ptr, FFIType.ptr, FFIType.ptr],
      returns: FFIType.ptr
    }
  })

  const sel = (name: string) =>
    objc.symbols.sel_registerName(Buffer.from(`${name}\0`))
  const selButton = sel('button')
  const selImage = sel('image')
  const selSetTemplate = sel('setTemplate:')

  markTrayImageAsTemplate = () => {
    const statusItemPtr = tray.ptr
    if (!statusItemPtr) return
    const button = objc.symbols.objc_msgSend(statusItemPtr, selButton)
    if (!button) return
    const image = objc.symbols.objc_msgSend(button, selImage)
    if (!image) return
    // Pass 1 (YES) as a pointer-sized value for the BOOL arg
    objc3.symbols.objc_msgSend(image, selSetTemplate, 1 as never)
  }
}

// biome-ignore lint/suspicious/noExplicitAny: Electrobun's BrowserWindow generic requires RPC type which varies per instance
let popupWindow: BrowserWindow<any> | null = null

const tray = new Tray({
  image: isMac
    ? 'views://img/template/icon-0-Template.png'
    : process.platform === 'win32'
      ? 'views://img/ico/icon-0.ico'
      : 'views://img/png/icon-0.png',
  template: isMac,
  width: 22,
  height: 22
})

tray.on('tray-clicked', () => {
  togglePopup()
})

function getPopupPosition(): { x: number; y: number } {
  const cursor = Screen.getCursorScreenPoint()
  const primary = Screen.getPrimaryDisplay()

  let x = Math.round(cursor.x - WINDOW_WIDTH / 2)
  const y = primary.workArea.y

  const maxX = primary.bounds.x + primary.bounds.width - WINDOW_WIDTH
  if (x < primary.bounds.x) x = primary.bounds.x
  if (x > maxX) x = maxX

  return { x, y }
}

function togglePopup() {
  if (popupWindow) {
    popupWindow.close()
    popupWindow = null
    return
  }

  createPopupWindow()
}

function showPopup() {
  if (!popupWindow) {
    createPopupWindow()
  } else {
    popupWindow.focus()
  }
}

function hidePopup() {
  if (popupWindow) {
    popupWindow.close()
    popupWindow = null
  }
}

function createRPC() {
  return BrowserView.defineRPC<MaterRPC>({
    maxRequestTime: 5000,
    handlers: {
      requests: {},
      messages: {
        setTrayIcon: ({ iconPath }) => {
          tray.setImage(iconPath)
          markTrayImageAsTemplate?.()
        },
        hideWindow: () => {
          hidePopup()
        },
        showWindow: () => {
          showPopup()
        },
        quitApp: () => {
          tray.remove()
          Utils.quit()
        }
      }
    }
  })
}

function createPopupWindow() {
  const pos = getPopupPosition()
  const rpc = createRPC()

  popupWindow = new BrowserWindow({
    title: 'Mater',
    url: 'views://mainview/index.html',
    transparent: true,
    frame: {
      width: WINDOW_WIDTH,
      height: WINDOW_HEIGHT,
      x: pos.x,
      y: pos.y
    },
    titleBarStyle: 'hidden',
    rpc,
    styleMask: {
      Borderless: true,
      Titled: false,
      Closable: false,
      Miniaturizable: false,
      Resizable: false,
      FullSizeContentView: true
    }
  })

  popupWindow.setAlwaysOnTop(true)

  popupWindow.on('close', () => {
    popupWindow = null
  })
}

console.log('Mater is ready')
