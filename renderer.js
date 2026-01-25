(() => {
  // node_modules/mitt/dist/mitt.es.js
  function mitt_es_default(n) {
    return { all: n = n || /* @__PURE__ */ new Map(), on: function(t, e) {
      var i = n.get(t);
      i && i.push(e) || n.set(t, [e]);
    }, off: function(t, e) {
      var i = n.get(t);
      i && i.splice(i.indexOf(e) >>> 0, 1);
    }, emit: function(t, e) {
      (n.get(t) || []).slice().map(function(n2) {
        n2(e);
      }), (n.get("*") || []).slice().map(function(n2) {
        n2(t, e);
      });
    } };
  }

  // node_modules/tiny-timer/dist/tiny-timer.module.js
  var Timer = class {
    constructor({
      interval = 1e3,
      stopwatch = false
    } = {}) {
      this._duration = 0;
      this._endTime = 0;
      this._pauseTime = 0;
      this._status = "stopped";
      this._emitter = mitt_es_default();
      this.tick = () => {
        if (this.status === "paused") return;
        if (Date.now() >= this._endTime) {
          this.stop();
          this._emitter.emit("tick", this._stopwatch ? this._duration : 0);
          this._emitter.emit("done");
        } else {
          this._emitter.emit("tick", this.time);
        }
      };
      this._interval = interval;
      this._stopwatch = stopwatch;
    }
    start(duration, interval) {
      if (this.status !== "stopped") return;
      if (duration == null) {
        throw new TypeError("Must provide duration parameter");
      }
      this._duration = duration;
      this._endTime = Date.now() + duration;
      this._changeStatus("running");
      this._emitter.emit("tick", this._stopwatch ? 0 : this._duration);
      this._timeoutID = setInterval(this.tick, interval || this._interval);
    }
    stop() {
      if (this._timeoutID) clearInterval(this._timeoutID);
      this._changeStatus("stopped");
    }
    pause() {
      if (this.status !== "running") return;
      this._pauseTime = Date.now();
      this._changeStatus("paused");
    }
    resume() {
      if (this.status !== "paused") return;
      this._endTime += Date.now() - this._pauseTime;
      this._pauseTime = 0;
      this._changeStatus("running");
    }
    _changeStatus(status) {
      this._status = status;
      this._emitter.emit("statusChanged", this.status);
    }
    get time() {
      if (this.status === "stopped") return 0;
      const time = this.status === "paused" ? this._pauseTime : Date.now();
      const left = this._endTime - time;
      return this._stopwatch ? this._duration - left : left;
    }
    get duration() {
      return this._duration;
    }
    get status() {
      return this._status;
    }
    on(eventName, handler) {
      this._emitter.on(eventName, handler);
    }
    off(eventName, handler) {
      this._emitter.off(eventName, handler);
    }
  };
  var tiny_timer_module_default = Timer;

  // renderer.src.js
  var appContainer = document.querySelector(".js-app");
  var startButton = document.querySelector(".js-start-btn");
  var stopButton = document.querySelector(".js-stop-btn");
  var slider = document.querySelector(".js-slider");
  var soundEnabled = true;
  var soundWindup = new Audio(`${globalThis.mater.appPath}/wav/windup.wav`);
  var soundClick = new Audio(`${globalThis.mater.appPath}/wav/click.wav`);
  var soundDing = new Audio(`${globalThis.mater.appPath}/wav/ding.wav`);
  var state = "";
  var currentMinute = 0;
  var workMinutes = 25;
  var breakMinutes = 5;
  var timer = new tiny_timer_module_default();
  var minToMs = (min) => min * 60 * 1e3;
  var msToMin = (ms) => ms / 60 / 1e3;
  var getCurrentMinutes = () => state === "breaking" ? breakMinutes : workMinutes;
  var getCurrentSliderWidth = () => state === "breaking" ? 100 : 500;
  var playSound = (sound) => {
    sound.currentTime = 0;
    if (soundEnabled) {
      sound.play();
    }
  };
  var setState = (newState) => {
    appContainer.classList.remove("is-stopped", "is-working", "is-breaking");
    appContainer.classList.add(`is-${newState}`);
    state = newState;
  };
  setState("stopped");
  var setIcon = (minute, currentState) => {
    const { platform, appPath } = globalThis.mater;
    const breakSuffix = currentState === "breaking" ? "-break" : "";
    let file;
    switch (platform) {
      case "darwin": {
        file = `${appPath}/img/template/icon-${minute}${breakSuffix}-Template.png`;
        break;
      }
      case "win32": {
        file = `${appPath}/img/ico/icon-${minute}${breakSuffix}.ico`;
        break;
      }
      default: {
        file = `${appPath}/img/png/icon-${minute}${breakSuffix}.png`;
      }
    }
    globalThis.mater.setTrayIcon(file);
  };
  var setCurrentMinute = (ms) => {
    currentMinute = Math.ceil(msToMin(ms));
    setIcon(currentMinute, state);
  };
  setCurrentMinute(0);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      globalThis.mater.hideWindow();
    }
  });
  startButton.addEventListener("click", () => {
    playSound(soundWindup);
    timer.start(minToMs(workMinutes));
    setState("working");
    slider.classList.add("is-resetting-work");
    setTimeout(() => slider.classList.remove("is-resetting-work"), 1e3);
  });
  stopButton.addEventListener("click", () => {
    playSound(soundClick);
    timer.stop();
    setState("stopped");
  });
  timer.on("tick", (ms) => {
    const minutes = getCurrentMinutes();
    const sliderWidth = getCurrentSliderWidth();
    const offset = Math.ceil(sliderWidth * ms / minToMs(minutes));
    slider.style.transform = `translateX(-${offset}px)`;
    setCurrentMinute(ms);
  });
  timer.on("done", () => {
    playSound(soundDing);
    setCurrentMinute(0);
    globalThis.mater.showWindow();
    setTimeout(() => {
      playSound(soundWindup);
      if (state === "working") {
        setState("breaking");
        timer.start(minToMs(breakMinutes));
        slider.classList.add("is-resetting-break");
        setTimeout(() => slider.classList.remove("is-resetting-break"), 1e3);
      } else {
        setState("working");
        timer.start(minToMs(workMinutes));
        slider.classList.add("is-resetting-work");
        setTimeout(() => slider.classList.remove("is-resetting-work"), 1e3);
      }
    }, 2e3);
  });
  globalThis.mater.onToggleSound((enabled) => {
    soundEnabled = enabled;
  });
})();
