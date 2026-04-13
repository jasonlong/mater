import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppPreferences {
    private static let workKey = "AppPreferences.workMinutes"
    private static let breakKey = "AppPreferences.breakMinutes"
    private static let soundKey = "AppPreferences.soundEnabled"

    private let defaults: UserDefaults

    var workMinutes: Int {
        didSet { defaults.set(workMinutes, forKey: Self.workKey) }
    }

    var breakMinutes: Int {
        didSet { defaults.set(breakMinutes, forKey: Self.breakKey) }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Self.soundKey) }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            try? newValue
                ? SMAppService.mainApp.register()
                : SMAppService.mainApp.unregister()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedWork = defaults.integer(forKey: Self.workKey)
        let storedBreak = defaults.integer(forKey: Self.breakKey)
        self.workMinutes = storedWork > 0 ? storedWork : 25
        self.breakMinutes = storedBreak > 0 ? storedBreak : 5
        self.soundEnabled = defaults.object(forKey: Self.soundKey) as? Bool ?? true
    }
}
