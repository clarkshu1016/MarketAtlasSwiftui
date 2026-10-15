import Foundation

/// What a company does, in the reader's language (or the closest one the server has), with where it came from.
/// The text is from Wikipedia (CC BY-SA), so `sourceURL` must be shown with it.
struct CompanyProfile: Codable, Equatable {
    let summary: String
    let sourceURL: URL?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case summary
        case sourceURL = "source_url"
        case website
    }

    /// The address as a web link, or nil when it is missing or not http(s).
    var websiteURL: URL? { URL.web(website) }

    /// "nvidia.com" from "https://www.nvidia.com/en-us/".
    var websiteDisplay: String? {
        guard let host = websiteURL?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension CompanyProfile {
    /// The language code the server uses for the app's current language: en, ja, zh-Hans, zh-Hant, ko, es, de, fr, pt-BR.
    static var serverLanguage: String {
        let id = Locale.preferredLanguages.first ?? "en"
        let locale = Locale(identifier: id)
        let code = locale.language.languageCode?.identifier ?? "en"
        switch code {
        case "zh":
            let script = locale.language.script?.identifier
            let region = locale.region?.identifier
            if script == "Hant" || ["TW", "HK", "MO"].contains(region ?? "") { return "zh-Hant" }
            return "zh-Hans"
        case "pt": return "pt-BR"
        case "ja", "ko", "es", "de", "fr": return code
        default: return "en"
        }
    }
}
