import Foundation

// MARK: - /api/market/performance

struct PerformanceResponse: Codable {
    let period: String
    let note: String?
    let items: [PerformanceItem]
}

struct PerformanceItem: Codable, Identifiable {
    let company: Company
    /// Market-cap change in percent. For the "peak" period this is the distance from the
    /// all-time-high market cap, so it is always <= 0.
    let change_pct: Double
    /// Market cap at the start of the period — or at the peak, for the "peak" period (USD).
    let reference_value: Double
    let reference_date: String
    let end_value: Double

    var id: String { company.id }
}

// MARK: - /api/market/time-machine

struct TimeMachineResponse: Codable {
    let date: String
    let note: String?
    let items: [TimeMachineItem]
}

struct TimeMachineItem: Codable, Identifiable {
    let rank_then: Int
    let company: Company
    let value_then: Double
    let value_now: Double?
    let rank_now: Int?
    let multiple: Double?

    var id: String { company.id }
}

// MARK: - /api/market/heatmap/*

struct CountryHeatmapResponse: Codable {
    let period: String
    let world_market_cap: Double
    let note: String?
    let items: [CountryHeatItem]
}

struct CountryHeatItem: Codable, Identifiable {
    /// Includes the flag emoji, e.g. "🇺🇸 USA".
    let country: String
    let market_cap: Double
    let share_pct: Double
    let company_count: Int
    /// How many of `company_count` had a market cap at the start of the period (the change is computed over those).
    let coverage: Int
    let change_pct: Double?

    var id: String { country }

    var flag: String { country.split(separator: " ", maxSplits: 1).first.map(String.init) ?? "" }
    var name: String {
        let parts = country.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : country
    }
}

struct CompanyHeatmapResponse: Codable {
    let country: String
    let period: String
    let country_market_cap: Double
    let note: String?
    let items: [CompanyHeatItem]
}

struct CompanyHeatItem: Codable, Identifiable {
    let company: Company
    let market_cap: Double
    let change_pct: Double?

    var id: String { company.id }
}


// MARK: - Display helpers for heatmap tiles

extension Company {
    /// The ticker only if it's a plain letters code people recognise (NVDA, BP). Exchange-style
    /// codes — "688825.SS", "9984.T", "005930.KS", "2454.TW" — are meaningless to users.
    var readableTicker: String? {
        guard let t = ticker, t.range(of: #"^[A-Za-z]{1,5}$"#, options: .regularExpression) != nil else { return nil }
        return t
    }

    /// Name without trailing corporate boilerplate ("KIOXIA Holdings Corporation" → "KIOXIA"),
    /// so it fits more often on a tile.
    var tileName: String {
        let boilerplate = #"(?i)(,?\s+(co\.?,?\s*ltd\.?|corporation|corp\.?|incorporated|inc\.?|holdings?|group|limited|ltd\.?|plc|s\.a\.|n\.v\.|ag|se|company|co\.?))+\s*$"#
        let short = name.replacingOccurrences(of: boilerplate, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        return short.count >= 2 ? short : name
    }
}


// MARK: - Display helpers shared by the list rows and the share cards

extension PerformanceItem {
    /// Huge gains read better as a multiple ("×36") than "+3,584%".
    var changeText: String {
        change_pct >= 1000 ? String(format: "×%.0f", change_pct / 100 + 1) : String(format: "%+.1f%%", change_pct)
    }

    func detailText(isPeak: Bool) -> String {
        let reference = Money.short(reference_value)
        let date = Money.monthYear(fromISO: reference_date)
        return isPeak ? "Peak \(reference) · \(date)" : "\(reference) → \(Money.short(end_value))"
    }
}

extension TimeMachineItem {
    var multipleText: String {
        guard let m = multiple else { return "—" }
        return m >= 10 ? String(format: "×%.0f", m) : String(format: "×%.2f", m)
    }

    var todayText: String {
        var parts: [String] = []
        if let rank = rank_now { parts.append("#\(rank)") }
        if let now = value_now { parts.append(Money.short(now)) }
        return parts.isEmpty ? "Not ranked now" : "Now " + parts.joined(separator: " · ")
    }
}
