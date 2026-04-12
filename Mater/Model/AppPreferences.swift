import Foundation
import Observation

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var workMinutes: Int {
        didSet { defaults.set(workMinutes, forKey: "AppPreferences.workMinutes") }
    }

    var breakMinutes: Int {
        didSet { defaults.set(breakMinutes, forKey: "AppPreferences.breakMinutes") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedWork = defaults.integer(forKey: "AppPreferences.workMinutes")
        let storedBreak = defaults.integer(forKey: "AppPreferences.breakMinutes")
        self.workMinutes = storedWork > 0 ? storedWork : 25
        self.breakMinutes = storedBreak > 0 ? storedBreak : 5
    }
}
