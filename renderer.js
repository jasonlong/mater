// Get menubar instance from main.js
const mb = require('electron').remote.getGlobal('sharedObject').mb

const Timer = require('tiny-timer')

const appContainer = document.querySelector('.js-app-container')
const startBtn = document.querySelector('.js-start-btn')
const stopBtn = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')
const numMinutes = 25

let timer = new Timer()

startBtn.addEventListener('click', () => {
  timer.start(numMinutes * 60 * 1000)
  appContainer.classList.add('is-running')
  slider.classList.add('is-resetting')
})

stopBtn.addEventListener('click', () => {
  timer.stop()
  appContainer.classList.remove('is-running')
})

timer.on('tick', (ms) => {
  slider.style.transform = 'translateX(-' + (500*ms)/(numMinutes*60*1000) + 'px)';
})

timer.on('done', () => {
  mb.showWindow()
})
