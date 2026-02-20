# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mater is a minimal Pomodoro timer menubar app built with Electrobun. It runs a 25-minute work timer followed by a 5-minute break, repeating until stopped.

## Commands

- `bun run dev` - Run the app in development mode (via `electrobun dev`)
- `bun run build` - Build the app (via `electrobun build`)
- `bun run start` - Build then run in dev mode
- `bun run test` - Run all linters (JS + CSS)
- `bun run lint:js` - Run Biome JavaScript/TypeScript linter
- `bun run lint:css` - Run Stylelint CSS linter

## Architecture

This is an Electrobun app with two processes:

- **src/bun/index.ts** - Main process (runs on Bun): creates tray icon, manages popup window positioning, handles context menu (sound toggle, quit), processes RPC calls from the renderer
- **src/bun/rpc.ts** - Shared RPC type definitions (typed schema for bun <-> view communication)
- **src/mainview/index.ts** - Renderer process (runs in WebView): manages timer logic using `tiny-timer`, handles UI state transitions (stopped/working/breaking), sends tray icon updates via RPC
- **src/mainview/index.html** - Single HTML file with the timer UI (sliding ruler visualization)
- **src/mainview/main.css** - Styles for the popup window

### Key Details

- Timer icons are stored in `img/` with platform-specific formats: `template/` (macOS), `ico/` (Windows), `png/` (Linux)
- Sound files are in `wav/` directory
- Main-to-renderer communication uses Electrobun's typed RPC (`defineRPC`) instead of Electron's IPC
- The popup window is manually positioned below the tray icon (no `menubar` package equivalent in Electrobun)
- `electrobun.config.ts` defines build configuration, asset copying, and platform-specific settings

## Code Style

- **JavaScript/TypeScript**: Biome with no semicolons, 2-space indentation, single quotes
- **CSS**: Stylelint with strict property ordering (see `.stylelintrc`)
