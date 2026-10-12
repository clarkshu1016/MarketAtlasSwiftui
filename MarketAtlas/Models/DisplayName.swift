import Foundation

/// Display-only translation of the labels the server sends in English ("🇺🇸 USA", "💳 Financial services").
/// The raw strings stay the identifiers (filters, requests); only what the user reads is translated.
enum DisplayName {
    /// The localization the app is showing: "en", "ja", "zh-Hans" or "zh-Hant".
    private static var language: String { Bundle.main.preferredLocalizations.first ?? "en" }
    private static var isEnglish: Bool { language.hasPrefix("en") }

    // MARK: Countries

    /// "🇺🇸 USA" → ("🇺🇸", "USA").
    private static func splitFlag(_ raw: String) -> (flag: String, name: String)? {
        let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].unicodeScalars.count == 2,
              parts[0].unicodeScalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) else { return nil }
        return (parts[0], parts[1])
    }

    private static func regionCode(forFlag flag: String) -> String {
        String(String.UnicodeScalarView(flag.unicodeScalars.compactMap { UnicodeScalar($0.value - 0x1F1E6 + 0x41) }))
    }

    /// The four China-related labels are kept as four separate, neutral names in every language
    /// (see the naming decision); everything else uses the system's region names.
    private static func neutralName(_ code: String) -> String? {
        switch (code, language) {
        case ("CN", "zh-Hans"): "中国大陆"
        case ("HK", "zh-Hans"): "香港"
        case ("MO", "zh-Hans"): "澳门"
        case ("TW", "zh-Hans"): "台湾"
        case ("CN", "zh-Hant"): "中國大陸"
        case ("HK", "zh-Hant"): "香港"
        case ("MO", "zh-Hant"): "澳門"
        case ("TW", "zh-Hant"): "台灣"
        case ("CN", "ja"):      "中国本土"
        case ("HK", "ja"):      "香港"
        case ("MO", "ja"):      "マカオ"
        case ("TW", "ja"):      "台湾"
        default:                nil
        }
    }

    /// Name only: "🇺🇸 USA" → "美国".
    static func countryName(_ raw: String) -> String {
        guard !isEnglish, let (flag, name) = splitFlag(raw) else {
            return splitFlag(raw)?.name ?? raw
        }
        let code = regionCode(forFlag: flag)
        return neutralName(code) ?? Locale(identifier: language).localizedString(forRegionCode: code) ?? name
    }

    /// Flag + name: "🇺🇸 USA" → "🇺🇸 美国".
    static func country(_ raw: String) -> String {
        guard !isEnglish, let (flag, _) = splitFlag(raw) else { return raw }
        return "\(flag) \(countryName(raw))"
    }

    // MARK: Tags

    /// "💳 Financial services" → "💳 金融服务". Tags without a translation stay as sent.
    static func tag(_ raw: String) -> String {
        guard !isEnglish else { return raw }
        let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return raw }
        let translated = NSLocalizedString(parts[1], tableName: "Tags", bundle: .main, value: parts[1], comment: "")
        return "\(parts[0]) \(translated)"
    }

    // MARK: Server footnotes

    /// The explanatory notes the API returns are English; known ones are translated by exact match.
    static func note(_ raw: String) -> String {
        guard !isEnglish else { return raw }
        return NSLocalizedString(raw, tableName: "ServerNotes", bundle: .main, value: raw, comment: "")
    }
}
