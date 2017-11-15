const Timer = require('tiny-timer')

const appContainer = document.querySelector('.js-app-container')
const startBtn = document.querySelector('.js-start-btn')
const stopBtn = document.querySelector('.js-stop-btn')
const timeRemaining = document.querySelector('.js-time-remaining')

let timer = new Timer()

startBtn.addEventListener('click', () => {
  timer.start(25 * 60 * 1000) // 25 minutes
  appContainer.classList.add('is-running')
})

stopBtn.addEventListener('click', () => {
  timer.stop()
  appContainer.classList.remove('is-running')
  timeRemaining.innerHTML = "1500000ms remaining"
})

timer.on('tick', (ms) => {
  timeRemaining.innerHTML = ms + "ms remaining"
})

timer.on('done', () => console.log('done!'))
