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
    private lazy var contextMenu: NSMenu = buildContextMenu()
    private var lastIconName: String = ""
    private let showSettings: () -> Void

    init(timerState: TimerState, showSettings: @escaping () -> Void) {
        self.timerState = timerState
        self.showSettings = showSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.timerPanel = TimerPanel(timerState: timerState, showSettings: showSettings)
        super.init()

        if let button = statusItem.button {
            button.image = cachedIcon(named: "icon-stopped")
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        prewarmLikelyIcons()

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
        let menuOrigin = NSPoint(x: 0, y: button.bounds.height + 4)
        contextMenu.popUp(positioning: nil, at: menuOrigin, in: button)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func observeIcon() {
        withObservationTracking {
            _ = timerState.iconName
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
        guard name != lastIconName else { return }
        lastIconName = name
        button.image = cachedIcon(named: name)
    }

    private func prewarmLikelyIcons() {
        _ = cachedIcon(named: "icon-\(timerState.preferences.workMinutes)")
        _ = cachedIcon(named: "icon-\(timerState.preferences.breakMinutes)-break")
    }

    private func cachedIcon(named name: String) -> NSImage? {
        if let cached = iconCache[name] {
            return cached
        }
        guard let icon = Self.makeIcon(named: name) else { return nil }
        Self.forceRender(icon)
        iconCache[name] = icon
        return icon
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

    private static func forceRender(_ image: NSImage) {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        _ = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }

    static func panelOrigin(buttonRect: CGRect, panelSize: CGSize) -> CGPoint {
        CGPoint(
            x: buttonRect.midX - panelSize.width / 2,
            y: buttonRect.minY - panelSize.height
        )
    }
}
