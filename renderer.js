// Get menubar instance from main.js
const mb = require('electron').remote.getGlobal('sharedObject').mb

const Timer = require('tiny-timer')

const appContainer = document.querySelector('.js-app-container')
const startBtn = document.querySelector('.js-start-btn')
const stopBtn = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')
const numMinutes = 25

let timer = new Timer()

const soundWindup = new Audio(__dirname + '/wav/windup.wav');
const soundClick = new Audio(__dirname + '/wav/click.wav');
const soundDing = new Audio(__dirname + '/wav/ding.wav');

startBtn.addEventListener('click', () => {
  soundWindup.currentTime = 0;
  soundWindup.volume = 0.5;
  soundWindup.play();
  timer.start(numMinutes * 60 * 1000)
  appContainer.classList.add('is-running')
  slider.classList.add('is-resetting')
})

stopBtn.addEventListener('click', () => {
  soundClick.currentTime = 0;
  soundClick.volume = 0.5;
  soundClick.play();
  timer.stop()
  appContainer.classList.remove('is-running')
})

timer.on('tick', (ms) => {
  slider.classList.remove('is-resetting')
  slider.style.transform = 'translateX(-' + Math.ceil((500*ms)/(numMinutes*60*1000)) + 'px)';
})

timer.on('done', () => {
  soundDing.currentTime = 0;
  soundDing.volume = 0.5;
  soundDing.play();
  appContainer.classList.remove('is-running')
  mb.showWindow()
})
