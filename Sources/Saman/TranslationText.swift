import Foundation
import NaturalLanguage
import Translation

struct TranslationLanguage: Hashable, Identifiable, Sendable {
    let id: String

    static let english = Self(id: "en")
    static let hebrew = Self(id: "he")

    var locale: Locale.Language { Locale.Language(identifier: id) }
    var baseCode: String { locale.languageCode?.identifier ?? id }
    var title: String { Locale(identifier: id).localizedString(forLanguageCode: id) ?? id }
    var displayName: String { InterfaceLanguage.current.locale.localizedString(forIdentifier: id) ?? title }
    var isRightToLeft: Bool { locale.characterDirection == .rightToLeft }

    fileprivate var recognizerLanguage: NLLanguage {
        NLLanguage(rawValue: baseCode == "zh" ? "zh-Hans" : baseCode)
    }

    fileprivate var scriptPattern: String? {
        switch locale.script?.identifier ?? Locale.Language(identifier: locale.maximalIdentifier).script?.identifier {
        case "Hans", "Hant": return #"\p{sc=Hani}"#
        case "Jpan": return #"\p{sc=Hira}|\p{sc=Kana}|\p{sc=Hani}"#
        case "Kore": return #"\p{sc=Hang}"#
        case let script?: return "\\p{sc=\(script)}"
        case nil: return nil
        }
    }
}

struct LanguagePair: Equatable, Sendable {
    let first: TranslationLanguage
    let second: TranslationLanguage

    static let standard = Self(first: .english, second: .hebrew)
    static let preferenceKey = "translationLanguagePair"

    var ids: [String] { [first.id, second.id] }

    static func saved(in defaults: UserDefaults = .standard) -> Self? {
        guard let ids = defaults.stringArray(forKey: preferenceKey),
              ids.count == 2, !ids[0].isEmpty, !ids[1].isEmpty else { return nil }
        let first = TranslationLanguage(id: ids[0])
        let second = TranslationLanguage(id: ids[1])
        guard first.baseCode != second.baseCode else { return nil }
        return Self(first: first, second: second)
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(ids, forKey: Self.preferenceKey)
    }

    static func suggested(for preferredLanguage: String?, from available: [TranslationLanguage]) -> Self {
        let preferred = preferredLanguage.map { TranslationLanguage(id: $0) }
        let first = available.first { $0.baseCode == preferred?.baseCode }
            ?? available.first { $0.baseCode == TranslationLanguage.english.baseCode }
            ?? available.first
            ?? standard.first
        let companion = first.baseCode == TranslationLanguage.english.baseCode
            ? TranslationLanguage.hebrew : .english
        let second = available.first { $0.baseCode == companion.baseCode }
            ?? available.first { $0.baseCode != first.baseCode }
            ?? companion
        return Self(first: first, second: second)
    }

    func supportsBothDirections() async -> Bool {
        guard first.baseCode != second.baseCode else { return false }
        let availability = LanguageAvailability()
        guard await availability.status(from: first.locale, to: second.locale) != .unsupported else { return false }
        return await availability.status(from: second.locale, to: first.locale) != .unsupported
    }

    static func availableLanguages() async -> [TranslationLanguage] {
        let candidates = await LanguageAvailability().supportedLanguages
            .map { TranslationLanguage(id: $0.minimalIdentifier) }
            .sorted { $0.id < $1.id }
        // Prefer the generic variant when Apple advertises several regions for the same language.
        var languages: [String: TranslationLanguage] = [:]
        for candidate in candidates where languages[candidate.baseCode] == nil || candidate.id == candidate.baseCode {
            languages[candidate.baseCode] = candidate
        }
        return languages.values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

struct TranslationText {
    let value: String
    let source: TranslationLanguage
    let target: TranslationLanguage

    init?(_ text: String?, pair: LanguagePair = .standard) {
        guard let text else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source = Self.detect(value, pair: pair) else { return nil }
        self.init(value: value, source: source, target: source == pair.first ? pair.second : pair.first)
    }

    private init(value: String, source: TranslationLanguage, target: TranslationLanguage) {
        self.value = value
        self.source = source
        self.target = target
    }

    var reversed: Self { Self(value: value, source: target, target: source) }

    private static func detect(_ text: String, pair: LanguagePair) -> TranslationLanguage? {
        guard text.unicodeScalars.contains(where: CharacterSet.letters.contains) else { return nil }
        let sample = String(text.prefix(1_500)).decomposedStringWithCompatibilityMapping
        if let firstPattern = pair.first.scriptPattern, let secondPattern = pair.second.scriptPattern,
           firstPattern != secondPattern,
           let firstRegex = try? NSRegularExpression(pattern: firstPattern),
           let secondRegex = try? NSRegularExpression(pattern: secondPattern) {
            let range = NSRange(sample.startIndex..., in: sample)
            let firstCount = firstRegex.numberOfMatches(in: sample, range: range)
            let secondCount = secondRegex.numberOfMatches(in: sample, range: range)
            if firstCount != secondCount { return firstCount > secondCount ? pair.first : pair.second }
            guard let firstMatch = firstRegex.firstMatch(in: sample, range: range),
                  let secondMatch = secondRegex.firstMatch(in: sample, range: range) else { return nil }
            if firstMatch.range.location != secondMatch.range.location {
                return firstMatch.range.location < secondMatch.range.location ? pair.first : pair.second
            }
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [pair.first.recognizerLanguage, pair.second.recognizerLanguage]
        recognizer.processString(sample)
        let scores = recognizer.languageHypotheses(withMaximum: 2)
        let first = scores[pair.first.recognizerLanguage, default: 0]
        let second = scores[pair.second.recognizerLanguage, default: 0]
        return second > first + 0.1 ? pair.second : pair.first
    }
}
