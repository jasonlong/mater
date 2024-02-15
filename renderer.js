'use strict'

// DOM elements & variables
// =============================================================================

// Get menubar instance from main.js
const {mb} = require('electron').remote.getGlobal('sharedObject')
const {ipcRenderer} = require('electron')
const path = require('path')
const Timer = require('tiny-timer')

const appContainer = document.querySelector('.js-app')
const startButton = document.querySelector('.js-start-btn')
const stopButton = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')

// Sounds
let soundEnabled = true
const soundWindup = new Audio(path.join(__dirname, '/wav/windup.wav'))
const soundClick = new Audio(path.join(__dirname, '/wav/click.wav'))
const soundDing = new Audio(path.join(__dirname, '/wav/ding.wav'))

let state = ''
let currentMinute = 0
const workMinutes = 25
const breakMinutes = 5

// Timer stuff
const timer = new Timer()

// Utilities
// =============================================================================
const minToMs = min => min * 60 * 1000

const msToMin = ms => ms / 60 / 1000

const getCurrentMinutes = () => state === 'breaking' ? breakMinutes : workMinutes

const getCurrentSliderWidth = () => state === 'breaking' ? 100 : 500

const playSound = sound => {
  sound.currentTime = 0
  if (soundEnabled) {
    sound.play()
  }
}

// State handling
// =============================================================================

const setState = newState => {
  appContainer.classList.remove('is-stopped', 'is-working', 'is-breaking')
  appContainer.classList.add(`is-${newState}`)
  state = newState
}

setState('stopped')

const setIcon = (currentMinute, currentState) => {
  const process = require('process')
  let file = ''
  const breakSuffix = currentState === 'breaking' ? '-break' : ''

  switch (process.platform) {
    case 'darwin': {
      file = path.join(__dirname, `img/template/icon-${currentMinute}${breakSuffix}-Template.png`)
      break
    }

    case 'win32': {
      file = path.join(__dirname, `img/ico/icon-${currentMinute}${breakSuffix}.ico`)
      break
    }

    default: {
      file = path.join(__dirname, `img/png/icon-${currentMinute}${breakSuffix}.png`)
    }
  }

  mb.tray.setImage(file)
}

const setCurrentMinute = ms => {
  currentMinute = Math.ceil(msToMin(ms))
  setIcon(currentMinute, state)
}

setCurrentMinute(0)

// Event handlers
// =============================================================================

document.addEventListener('keydown', event => {
  switch (event.key) {
    case 'Escape': {
      mb.hideWindow()
      break
    }

    default: {
      break
    }
  }
})

startButton.addEventListener('click', () => {
  playSound(soundWindup)
  timer.start(minToMs(workMinutes))
  setState('working')
  slider.classList.add('is-resetting-work')
  setTimeout(() => slider.classList.remove('is-resetting-work'), 1000)
})

stopButton.addEventListener('click', () => {
  playSound(soundClick)
  timer.stop()
  setState('stopped')
})

mb.on('after-hide', () => {
  mb.app.hide()
})

timer.on('tick', ms => {
  const minutes = getCurrentMinutes()
  const sliderWidth = getCurrentSliderWidth()
  slider.style.transform = 'translateX(-' + Math.ceil((sliderWidth * ms) / (minToMs(minutes))) + 'px)'
  setCurrentMinute(ms)
})

timer.on('done', () => {
  playSound(soundDing)
  setCurrentMinute(0)
  mb.showWindow()

  setTimeout(() => {
    playSound(soundWindup)
    if (state === 'working') {
      setState('breaking')
      timer.start(minToMs(breakMinutes))
      slider.classList.add('is-resetting-break')
      setTimeout(() => slider.classList.remove('is-resetting-break'), 1000)
    } else {
      setState('working')
      timer.start(minToMs(workMinutes))
      slider.classList.add('is-resetting-work')
      setTimeout(() => slider.classList.remove('is-resetting-work'), 1000)
    }
  }, 2000)
})

ipcRenderer.on('TOGGLE_SOUND', (event, data) => {
  soundEnabled = data
})
