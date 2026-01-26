## Mater

[![GitHub release](https://img.shields.io/github/release/jasonlong/mater.svg)](https://github.com/jasonlong/mater/releases/latest)
![Node.js CI](https://github.com/jasonlong/mater/workflows/Node.js%20CI/badge.svg)
[![XO code style](https://img.shields.io/badge/code_style-XO-5ed9c7.svg)](https://github.com/xojs/xo)

![mater-sm](https://user-images.githubusercontent.com/6104/37107543-9627589a-2202-11e8-825b-c68b248610ce.gif)

This is a minimal menubar Pomodoro app written in Electron. It simply runs a 25 minute timer, resets for a 5 minute break, and repeats until you stop it.

### Installation

Binaries for Mac, Windows, and Linux are available on the [releases page](https://github.com/jasonlong/mater/releases).

#### macOS

1. Download the `.dmg` from [Releases](https://github.com/jasonlong/mater/releases)
2. Open the DMG and drag Mater to Applications
3. **Important:** Before first launch, run this command in Terminal:
   ```
   xattr -cr /Applications/Mater.app
   ```
4. Open Mater from Applications

This removes the quarantine flag that macOS adds to downloaded apps. Without this step, macOS will show a warning that the app is damaged.

_Note: I'm not able to test the Windows and Linux builds, so please open an issue if you have any problems._

### Contributions

I don't have plans to add much else at this time, so please open an issue to discuss any feature ideas before implementing them.

### Development

```
$ git clone https://github.com/jasonlong/mater
$ cd mater
$ npm install
$ npm start
```

### What's with the name?

I'm a Pixar fan and Mater is awesome. ["Like Ta-mater without the ta"](https://youtu.be/MJm8vNTasMg?t=25s). Get it?

![mate2](https://cloud.githubusercontent.com/assets/6104/20083476/8dcb077e-a52a-11e6-962f-828c437f6011.jpg)
