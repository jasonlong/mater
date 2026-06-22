import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppPreferences {
    private static let workKey = "AppPreferences.workMinutes"
    private static let breakKey = "AppPreferences.breakMinutes"
    private static let soundKey = "AppPreferences.soundEnabled"

    static let workRange = 1...60
    static let breakRange = 1...30
    private static let defaultWorkMinutes = 25
    private static let defaultBreakMinutes = 5

    private let defaults: UserDefaults
    private var storedWorkMinutes: Int
    private var storedBreakMinutes: Int

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
