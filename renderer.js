'use strict'

// Get menubar instance from main.js
const mb = require('electron').remote.getGlobal('sharedObject').mb

// DOM elements
const appContainer = document.querySelector('.js-app')
const startBtn = document.querySelector('.js-start-btn')
const stopBtn = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')

// State
let state = ""
const setState = newState => {
  appContainer.classList.remove('is-stopped', 'is-working', 'is-breaking')
  appContainer.classList.add(`is-${newState}`)
  state = newState
}
setState("stopped")
let currentMinute = 0

const minToMs = min => min * 60 * 1000
const msToMin = ms => ms / 60 / 1000

const setCurrentMinute = ms => {
  currentMinute = Math.ceil(msToMin(ms))
  mb.tray.setImage(`${__dirname}/img/icon-${currentMinute}-Template.png`)
}
setCurrentMinute(0)

// Sounds
const soundWindup = new Audio(__dirname + '/wav/windup.wav');
const soundClick = new Audio(__dirname + '/wav/click.wav');
const soundDing = new Audio(__dirname + '/wav/ding.wav');

const playSound = sound => {
  sound.currentTime = 0;
  sound.play();
}

// Timer stuff
const Timer = require('tiny-timer')
const workMinutes = 25
const breakMinutes = 5
const sliderWidth = 500
let timer = new Timer()

startBtn.addEventListener('click', () => {
  playSound(soundWindup)
  timer.start(minToMs(workMinutes))
  setState("working")
  slider.classList.add('is-resetting')
  setTimeout(() => slider.classList.remove('is-resetting'), 1500)
})

stopBtn.addEventListener('click', () => {
  playSound(soundClick)
  timer.stop()
  setState("stopped")
})

timer.on('tick', (ms) => {
  slider.style.transform = 'translateX(-' + Math.ceil((sliderWidth*ms)/(minToMs(workMinutes))) + 'px)';
  setCurrentMinute(ms)
})

timer.on('done', () => {
  playSound(soundDing)
  setState("stopped")
  setCurrentMinute(0)
  mb.showWindow()
})
