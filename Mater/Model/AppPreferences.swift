import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppPreferences {
    private static let workKey = "AppPreferences.workMinutes"
    private static let breakKey = "AppPreferences.breakMinutes"
    private static let soundKey = "AppPreferences.soundEnabled"
    private static let languageKey = "AppPreferences.language"
    private static let notificationsKey = "AppPreferences.notificationsEnabled"
    private static let showPanelKey = "AppPreferences.showPanelOnCycleComplete"

    static let workRange = 1...60
    static let breakRange = 1...30
    private static let defaultWorkMinutes = 25
    private static let defaultBreakMinutes = 5

    private let defaults: UserDefaults
    private var storedWorkMinutes: Int
    private var storedBreakMinutes: Int
    private var storedLanguage: AppLanguage

    var workMinutes: Int {
        get { storedWorkMinutes }
        set {
            storedWorkMinutes = Self.clamped(newValue, to: Self.workRange)
            defaults.set(storedWorkMinutes, forKey: Self.workKey)
        }
    }

    var breakMinutes: Int {
        get { storedBreakMinutes }
        set {
            storedBreakMinutes = Self.clamped(newValue, to: Self.breakRange)
            defaults.set(storedBreakMinutes, forKey: Self.breakKey)
        }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Self.soundKey) }
    }

    var language: AppLanguage {
        get { storedLanguage }
        set {
            storedLanguage = newValue
            defaults.set(newValue.rawValue, forKey: Self.languageKey)
        }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }

    var showPanelOnCycleComplete: Bool {
        didSet { defaults.set(showPanelOnCycleComplete, forKey: Self.showPanelKey) }
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
        storedWorkMinutes = Self.storedMinutes(
            defaults: defaults,
            key: Self.workKey,
            defaultValue: Self.defaultWorkMinutes,
            range: Self.workRange
        )
        storedBreakMinutes = Self.storedMinutes(
            defaults: defaults,
            key: Self.breakKey,
            defaultValue: Self.defaultBreakMinutes,
            range: Self.breakRange
        )
        soundEnabled = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        storedLanguage = Self.storedLanguage(defaults: defaults)
        notificationsEnabled = defaults.object(forKey: Self.notificationsKey) as? Bool ?? false
        showPanelOnCycleComplete = defaults.object(forKey: Self.showPanelKey) as? Bool ?? false
    }

    private static func storedLanguage(defaults: UserDefaults) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: languageKey),
              let language = AppLanguage(rawValue: rawValue)
        else { return .system }
        return language
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func storedMinutes(
        defaults: UserDefaults,
        key: String,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        guard let value = defaults.object(forKey: key) as? Int else { return defaultValue }
        return clamped(value, to: range)
    }
}
