import { Electroview } from 'electrobun/view'
import Timer from 'tiny-timer'
import type { MaterRPC } from '../bun/rpc'

const appContainer = document.querySelector('[data-app]') as HTMLElement
const startButton = document.querySelector(
  '[data-action="start"]'
) as HTMLButtonElement
const stopButton = document.querySelector(
  '[data-action="stop"]'
) as HTMLButtonElement
const slider = document.querySelector('[data-element="slider"]') as HTMLElement

// RPC setup
const rpc = Electroview.defineRPC<MaterRPC>({
  maxRequestTime: 5000,
  handlers: {
    requests: {},
    messages: {
      toggleSound: ({ enabled }) => {
        soundEnabled = enabled
      }
    }
  }
})

// Initialize the Electroview to connect RPC transport
new Electroview({ rpc })

// Sounds
let soundEnabled = true
const soundWindup = new Audio('views://wav/windup.wav')
const soundClick = new Audio('views://wav/click.wav')
const soundDing = new Audio('views://wav/ding.wav')

let state = ''
let currentMinute = 0
const workMinutes = 25
const breakMinutes = 5

const timer = new Timer()

// Utilities
const minToMs = (min: number) => min * 60 * 1000
const msToMin = (ms: number) => ms / 60 / 1000
const getCurrentMinutes = () =>
  state === 'breaking' ? breakMinutes : workMinutes
const getCurrentSliderWidth = () => (state === 'breaking' ? 100 : 500)

const playSound = (sound: HTMLAudioElement) => {
  sound.currentTime = 0
  if (soundEnabled) {
    sound.play()
  }
}

// State handling
const setState = (newState: string) => {
  appContainer.classList.remove('is-stopped', 'is-working', 'is-breaking')
  appContainer.classList.add(`is-${newState}`)
  state = newState
}

setState('stopped')

const setIcon = (minute: number, currentState: string) => {
  const breakSuffix = currentState === 'breaking' ? '-break' : ''
  const iconPath = `views://img/png/icon-${minute}${breakSuffix}.png`
  rpc.send.setTrayIcon({ iconPath })
}

const setCurrentMinute = (ms: number) => {
  const newMinute = Math.ceil(msToMin(ms))
  // Only update the tray icon when the minute changes — recreating the tray
  // on every tick (tiny-timer fires rapidly) would cause it to flicker/vanish.
  if (newMinute !== currentMinute) {
    currentMinute = newMinute
    setIcon(currentMinute, state)
  }
}

// Set initial icon without going through the change-detection
// (the bun process already sets the initial icon at startup)
currentMinute = 0

// Event handlers
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    rpc.send.hideWindow({})
  }
})

startButton.addEventListener('click', () => {
  playSound(soundWindup)
  timer.start(minToMs(workMinutes))
  setState('working')
  currentMinute = workMinutes
  setIcon(currentMinute, state)
  slider.classList.add('is-resetting-work')
  setTimeout(() => slider.classList.remove('is-resetting-work'), 1000)
})

stopButton.addEventListener('click', () => {
  playSound(soundClick)
  timer.stop()
  setState('stopped')
  currentMinute = 0
  setIcon(currentMinute, state)
})

timer.on('tick', (ms: number) => {
  const minutes = getCurrentMinutes()
  const sliderWidth = getCurrentSliderWidth()
  const offset = Math.ceil((sliderWidth * ms) / minToMs(minutes))
  slider.style.transform = `translateX(-${offset}px)`
  setCurrentMinute(ms)
})

const quitButton = document.querySelector(
  '[data-action="quit"]'
) as HTMLButtonElement
if (quitButton) {
  quitButton.addEventListener('click', () => {
    rpc.send.quitApp({})
  })
}

timer.on('done', () => {
  playSound(soundDing)
  currentMinute = 0
  setIcon(0, state)
  rpc.send.showWindow({})

  setTimeout(() => {
    playSound(soundWindup)
    if (state === 'working') {
      setState('breaking')
      timer.start(minToMs(breakMinutes))
      currentMinute = breakMinutes
      setIcon(currentMinute, state)
      slider.classList.add('is-resetting-break')
      setTimeout(() => slider.classList.remove('is-resetting-break'), 1000)
    } else {
      setState('working')
      timer.start(minToMs(workMinutes))
      currentMinute = workMinutes
      setIcon(currentMinute, state)
      slider.classList.add('is-resetting-work')
      setTimeout(() => slider.classList.remove('is-resetting-work'), 1000)
    }
  }, 2000)
})
