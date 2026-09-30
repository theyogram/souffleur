import Foundation
import NaturalLanguage
import Speech

enum LocaleResolver {
    static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales.sorted { $0.identifier < $1.identifier }
    }

    static func resolve(scriptText: String, preferredIdentifier: String?) async -> Locale {
        let supported = await supportedLocales()
        guard !supported.isEmpty else { return Locale(identifier: "en-US") }

        let preferred = preferredIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let language: String
        let region: String?
        if preferred.isEmpty {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(scriptText)
            language = recognizer.dominantLanguage?.rawValue ?? "en"
            region = Locale.current.region?.identifier
        } else {
            let locale = Locale(identifier: preferred)
            language = locale.language.languageCode?.identifier ?? "en"
            region = locale.region?.identifier
        }

        let candidates = supported.filter { $0.language.languageCode?.identifier == language }
        if let region, let exact = candidates.first(where: { $0.region?.identifier == region }) {
            return exact
        }
        let fallbackRegion = language == "fr" ? "FR" : "US"
        if let fallback = candidates.first(where: { $0.region?.identifier == fallbackRegion }) {
            return fallback
        }
        if let candidate = candidates.first { return candidate }
        return supported.first(where: {
            $0.language.languageCode?.identifier == "en" && $0.region?.identifier == "US"
        }) ?? supported[0]
    }

    static func displayName(for locale: Locale) -> String {
        let displayLocale = Locale.current
        let language = displayLocale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? "")
            ?? locale.identifier
        guard let region = locale.region?.identifier,
              let regionName = displayLocale.localizedString(forRegionCode: region) else { return language }
        return "\(language) (\(regionName))"
    }
}
