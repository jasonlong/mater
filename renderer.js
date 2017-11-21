// Get menubar instance from main.js
const mb = require('electron').remote.getGlobal('sharedObject').mb

const Timer = require('tiny-timer')

const appContainer = document.querySelector('.js-app-container')
const startBtn = document.querySelector('.js-start-btn')
const stopBtn = document.querySelector('.js-stop-btn')
const slider = document.querySelector('.js-slider')
const numMinutes = 25
let currentMinute = 0

let timer = new Timer()

const soundWindup = new Audio(__dirname + '/wav/windup.wav');
const soundClick = new Audio(__dirname + '/wav/click.wav');
const soundDing = new Audio(__dirname + '/wav/ding.wav');

startBtn.addEventListener('click', () => {
  soundWindup.currentTime = 0;
  soundWindup.play();
  timer.start(numMinutes * 60 * 1000)
  appContainer.classList.add('is-running')
  slider.classList.add('is-resetting')
})

stopBtn.addEventListener('click', () => {
  soundClick.currentTime = 0;
  soundClick.play();
  timer.stop()
  appContainer.classList.remove('is-running')
})

timer.on('tick', (ms) => {
  slider.classList.remove('is-resetting')
  slider.style.transform = 'translateX(-' + Math.ceil((500*ms)/(numMinutes*60*1000)) + 'px)';
  setCurrentMinute(ms)
})

timer.on('done', () => {
  soundDing.currentTime = 0;
  soundDing.play();
  appContainer.classList.remove('is-running')
  mb.tray.setImage(`${__dirname}/img/icon-0-Template.png`)
  mb.showWindow()
})

const setCurrentMinute = ms => {
  currentMinute = Math.ceil(ms / 60 / 1000)
  mb.tray.setImage(`${__dirname}/img/icon-${currentMinute}-Template.png`)
}
