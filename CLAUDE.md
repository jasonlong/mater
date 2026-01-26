# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mater is a minimal Pomodoro timer menubar app built with Electron. It runs a 25-minute work timer followed by a 5-minute break, repeating until stopped.

## Commands

- `npm start` - Run the app in development mode
- `npm test` - Run all linters (JS + CSS) and e2e tests
- `npm run lint:js` - Run XO (ESLint-based) JavaScript linter
- `npm run lint:css` - Run Stylelint CSS linter
- `npm run bundle` - Bundle renderer.js (production, minified)
- `npm run bundle:dev` - Bundle renderer.js (dev, with sourcemaps)
- `npm run make` - Build installer for current platform (uses Electron Forge)
- `npm run make:mac` / `make:linux` / `make:win` - Build for specific platform

## Architecture

This is a standard Electron app with two processes:

- **main.js** - Main process: creates the menubar using the `menubar` package, handles tray icon and context menu (sound toggle, quit)
- **renderer.js** - Renderer process: manages timer logic using `tiny-timer`, handles UI state transitions (stopped/working/breaking), updates tray icons per minute
- **index.html** - Single HTML file with the timer UI (sliding ruler visualization)

### Key Details

- Timer icons are stored in `img/` with platform-specific formats: `template/` (macOS), `ico/` (Windows), `png/` (Linux)
- Sound files are in `wav/` directory
- Main-to-renderer communication uses Electron's `ipcRenderer` for sound toggle
- Renderer accesses menubar instance via `globalThis.sharedObject` set in main process

## Code Style

- **JavaScript**: XO with no semicolons, 2-space indentation
- **CSS**: Stylelint with strict property ordering (see `.stylelintrc`)
