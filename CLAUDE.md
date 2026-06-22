# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mater is a minimal macOS menu bar Pomodoro timer written in Swift, SwiftUI, and AppKit. As of v3, Mater is macOS-only.

## Commands

- `xcodebuild -project Mater.xcodeproj -scheme Mater -configuration Debug build -derivedDataPath /tmp/mater-derived` - Build debug app
- `xcodebuild test -project Mater.xcodeproj -scheme Mater -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/mater-derived` - Run tests
- `xcodebuild archive -project Mater.xcodeproj -scheme Mater -configuration Release -archivePath /tmp/Mater.xcarchive` - Create a release archive (signing requires Developer ID configuration)

## Architecture

- **Mater/App/AppDelegate.swift** - Creates shared `AppPreferences`, `TimerState`, `StatusItemController`, and `SettingsWindowController` instances.
- **Mater/App/MaterApp.swift** - SwiftUI app entry point that bridges to the app delegate.
- **Mater/Panel/StatusItemController.swift** - Owns the menu bar status item, context menu, outside-click monitors, panel presentation, and status icon updates.
- **Mater/Panel/TimerPanel.swift** - Creates the borderless AppKit panel and hosts the SwiftUI timer UI.
- **Mater/Views/TimerPanelView.swift** and **Mater/Views/RulerView.swift** - Render the timer panel and sliding ruler interaction.
- **Mater/Views/SettingsView.swift** - Renders Settings and About panes.
- **Mater/Model/TimerState.swift** - Owns the timer state machine, drag/momentum behavior, cycle transitions, and sound playback.
- **Mater/Model/AppPreferences.swift** - Owns persisted preferences and launch-at-login state.
- **Mater/Model/IconGenerator.swift** - Generates menu bar status icons dynamically.
- **Mater/Model/WindupSoundGenerator.swift** - Synthesizes windup audio from `tick.wav`.
- **MaterTests/TimerStateTests.swift** - Contains Swift Testing coverage for preferences, timer state, audio generation, icons, and panel-origin helpers.

## Key Details

- Status item icons are generated dynamically by `IconGenerator`.
- Sounds live under `Mater/Sounds/`.
- Preferences use `UserDefaults` through `AppPreferences`.
- Launch-at-login uses `ServiceManagement`.
- Tests use Swift Testing in `MaterTests/TimerStateTests.swift`.

## Code Style

- Swift code uses 4-space indentation.
- Prefer `@MainActor` for UI and observed state objects that mutate AppKit or SwiftUI-visible state.
- Keep related tests grouped under `// MARK:` sections in `MaterTests/TimerStateTests.swift`.
