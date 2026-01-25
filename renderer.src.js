/* global document, Audio */
'use strict'

const Timer = require('tiny-timer')

// DOM elements & variables
// =============================================================================

const appContainer = document.querySelector('.js-app')
const startButton = document.querySelector('.js-start-btn')
const stopButton = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')

// Sounds
let soundEnabled = true
const soundWindup = new Audio(`${globalThis.mater.appPath}/wav/windup.wav`)
const soundClick = new Audio(`${globalThis.mater.appPath}/wav/click.wav`)
const soundDing = new Audio(`${globalThis.mater.appPath}/wav/ding.wav`)

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
  const {platform, appPath} = globalThis.mater
  let file = ''
  const breakSuffix = currentState === 'breaking' ? '-break' : ''

  switch (platform) {
    case 'darwin': {
      file = `${appPath}/img/template/icon-${currentMinute}${breakSuffix}-Template.png`
      break
    }

    case 'win32': {
      file = `${appPath}/img/ico/icon-${currentMinute}${breakSuffix}.ico`
      break
    }

    default: {
      file = `${appPath}/img/png/icon-${currentMinute}${breakSuffix}.png`
    }
  }

  globalThis.mater.setTrayIcon(file)
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
      globalThis.mater.hideWindow()
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

timer.on('tick', ms => {
  const minutes = getCurrentMinutes()
  const sliderWidth = getCurrentSliderWidth()
  slider.style.transform = 'translateX(-' + Math.ceil((sliderWidth * ms) / (minToMs(minutes))) + 'px)'
  setCurrentMinute(ms)
})

timer.on('done', () => {
  playSound(soundDing)
  setCurrentMinute(0)
  globalThis.mater.showWindow()

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

globalThis.mater.onToggleSound(enabled => {
  soundEnabled = enabled
})
