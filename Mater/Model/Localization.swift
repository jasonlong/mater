import Foundation
import Observation
import os

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .system:
            Localization.shared.string("language.system")
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }
}

/// Resolves localized strings from the language bundle selected in-app so the
/// language can be switched at runtime without restarting the app.
@MainActor @Observable
final class Localization {
    private static let logger = Logger(subsystem: "me.jasonlong.mater", category: "localization")

    static let shared = Localization()

    private(set) var bundle: Bundle
    private var preferences: AppPreferences?

    private init() {
        bundle = Bundle.main
    }

    func configure(preferences: AppPreferences) {
        self.preferences = preferences
        apply(preferences.language)
        observeLanguagePreference()
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    static func resolveBundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private func observeLanguagePreference() {
        guard let preferences else { return }
        withObservationTracking {
            _ = preferences.language
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let preferences = self.preferences else { return }
                self.apply(preferences.language)
                self.observeLanguagePreference()
            }
        }
    }

    private func apply(_ language: AppLanguage) {
        switch language {
        case .system:
            bundle = Bundle.main
        case .english, .simplifiedChinese:
            guard let languageBundle = Self.resolveBundle(for: language) else {
                Self.logger.error("Missing '\(language.rawValue, privacy: .public)' localization bundle; falling back to system language.")
                bundle = Bundle.main
                return
            }
            bundle = languageBundle
        }
    }
}
