import AppKit
import Observation

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let timerPanel: TimerPanel
    private let timerState: TimerState
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var iconCache: [String: NSImage] = [:]
    private let showSettings: () -> Void

    init(timerState: TimerState, showSettings: @escaping () -> Void) {
        self.timerState = timerState
        self.showSettings = showSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.timerPanel = TimerPanel(timerState: timerState, showSettings: showSettings)
        super.init()

        if let button = statusItem.button {
            button.image = Self.makeIcon(named: "icon-stopped")
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        timerState.onCycleComplete = { [weak self] in
            self?.showPanel()
        }

        observeIcon()
        setupOutsideClickMonitors()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if timerPanel.isVisible {
            timerPanel.close()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let buttonRect = statusItemButtonScreenFrame() else { return }
        timerPanel.setFrameOrigin(Self.panelOrigin(buttonRect: buttonRect, panelSize: timerPanel.frame.size))
        timerPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildContextMenu()
        let menuOrigin = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: menuOrigin, in: button)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let soundItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        let soundSubmenu = NSMenu()

        let soundOnItem = NSMenuItem(title: "On", action: #selector(enableSound), keyEquivalent: "")
        soundOnItem.target = self
        soundOnItem.state = timerState.soundEnabled ? .on : .off

        let soundOffItem = NSMenuItem(title: "Off", action: #selector(disableSound), keyEquivalent: "")
        soundOffItem.target = self
        soundOffItem.state = timerState.soundEnabled ? .off : .on

        soundSubmenu.addItem(soundOnItem)
        soundSubmenu.addItem(soundOffItem)
        soundItem.submenu = soundSubmenu
        menu.addItem(soundItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mater", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func enableSound() {
        timerState.soundEnabled = true
    }

    @objc private func disableSound() {
        timerState.soundEnabled = false
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func observeIcon() {
        withObservationTracking {
            _ = timerState.iconChanged
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateIcon()
                self?.observeIcon()
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let name = timerState.iconName
        if let cached = iconCache[name] {
            button.image = cached
        } else if let icon = Self.makeIcon(named: name) {
            iconCache[name] = icon
            button.image = icon
        }
    }

    private func setupOutsideClickMonitors() {
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                self?.closePanelIfOutsideClick(mouseLocation: location)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            guard let self else { return event }
            let isStatusItemClick = event.window == self.statusItem.button?.window
            if !isStatusItemClick {
                self.closePanelIfOutsideClick(mouseLocation: NSEvent.mouseLocation)
            }
            return event
        }
    }

    private func closePanelIfOutsideClick(mouseLocation: CGPoint) {
        guard timerPanel.isVisible,
              let statusItemFrame = statusItemButtonScreenFrame()
        else { return }

        if !timerPanel.frame.contains(mouseLocation) && !statusItemFrame.contains(mouseLocation) {
            timerPanel.close()
        }
    }

    private func statusItemButtonScreenFrame() -> CGRect? {
        guard let button = statusItem.button,
              let buttonWindow = button.window
        else { return nil }
        return buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private static func makeIcon(named name: String) -> NSImage? {
        if name == "icon-stopped" {
            return IconGenerator.generate(text: "×", style: .outlined)
        }
        if name.contains("-break") {
            let minute = name.replacingOccurrences(of: "icon-", with: "")
                .replacingOccurrences(of: "-break", with: "")
            return IconGenerator.generate(text: minute, style: .outlined)
        }
        let minute = name.replacingOccurrences(of: "icon-", with: "")
        return IconGenerator.generate(text: minute, style: .filled)
    }

    static func panelOrigin(buttonRect: CGRect, panelSize: CGSize) -> CGPoint {
        CGPoint(
            x: buttonRect.midX - panelSize.width / 2,
            y: buttonRect.minY - panelSize.height
        )
    }
}
