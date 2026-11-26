import Foundation
import SwiftUI

enum InterfaceLanguage: String {
    case english = "en"
    case hebrew = "he"

    static var current: Self {
        InterfaceLanguagePreference.saved().resolve(preferredLanguages: Locale.preferredLanguages)
    }

    static func preferred(from preferences: [String]) -> Self {
        preferences.lazy
            .compactMap { Locale.Language(identifier: $0).languageCode?.identifier }
            .compactMap(Self.init(rawValue:))
            .first ?? .english
    }

    var locale: Locale { Locale(identifier: rawValue) }
    var isRightToLeft: Bool { self == .hebrew }
    var layoutDirection: LayoutDirection { isRightToLeft ? .rightToLeft : .leftToRight }

    func string(_ key: String) -> String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return key }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

func localized(_ key: String, _ arguments: CVarArg...) -> String {
    let format = InterfaceLanguage.current.string(key)
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: InterfaceLanguage.current.locale, arguments: arguments)
}

enum InterfaceLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case hebrew = "he"

    private static let key = "interfaceLanguage"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return localized("settings.language.system")
        case .english: return InterfaceLanguage.english.string("app.language.name")
        case .hebrew: return InterfaceLanguage.hebrew.string("app.language.name")
        }
    }

    static func saved(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: key).flatMap(Self.init(rawValue:)) ?? .system
    }

    func save(in defaults: UserDefaults = .standard) {
        if self == .system {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(rawValue, forKey: Self.key)
        }
    }

    func resolve(preferredLanguages: [String]) -> InterfaceLanguage {
        InterfaceLanguage(rawValue: rawValue) ?? .preferred(from: preferredLanguages)
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published private(set) var selection = InterfaceLanguagePreference.saved()
    @Published private(set) var bubblePaused = UserDefaults.standard.bool(forKey: "translationBubblePaused")

    var language: InterfaceLanguage { selection.resolve(preferredLanguages: Locale.preferredLanguages) }

    func setBubblePaused(_ paused: Bool) {
        UserDefaults.standard.set(paused, forKey: "translationBubblePaused")
        bubblePaused = paused
    }

    func set(_ selection: InterfaceLanguagePreference) {
        guard selection != self.selection else { return }
        selection.save()
        self.selection = selection
    }
}
