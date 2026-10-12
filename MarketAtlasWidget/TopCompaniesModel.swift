import Foundation
import UIKit

/// One row of `GET /api/market/top` — only what the widget draws.
struct TopCompany: Codable, Identifiable, Hashable {
    let rank: Int
    let name: String
    let ticker: String?
    let country: String?
    let logo_url: String?
    let price_display: String?
    let change_24h: Double?
    let market_cap: Double
    let market_cap_display: String?

    var id: Int { rank }

    /// "NVDA" — or a short name when there's no ticker.
    var shortLabel: String { ticker ?? String(name.prefix(5)).uppercased() }

    var capText: String { market_cap_display ?? TopCompany.short(market_cap) }

    var changeText: String {
        guard let c = change_24h else { return "—" }
        return String(format: "%+.2f%%", c)
    }

    static func short(_ value: Double) -> String {
        switch value {
        case 1e12...: return String(format: "$%.2f T", value / 1e12)
        case 1e9...:  return String(format: "$%.1f B", value / 1e9)
        default:      return String(format: "$%.0f M", value / 1e6)
        }
    }
}

struct TopResponse: Codable {
    let items: [TopCompany]
}

/// Loads the top companies (and their logos) for a timeline entry, falling back to the last good
/// result when the network is down.
enum TopCompaniesLoader {
    // The widget always reads the live server: it has no way to see the app's Debug server switch.
    private static let endpoint = URL(string: "https://marketatlas-api.appdevgpt.com/api/market/top?limit=10")!
    private static let cacheKey = "top_companies_cache_v1"

    struct Result {
        let companies: [TopCompany]
        let logos: [String: Data]      // keyed by ticker
        let isStale: Bool
    }

    static func load() async -> Result? {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15

        if let (data, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let decoded = try? JSONDecoder().decode(TopResponse.self, from: data), !decoded.items.isEmpty {
            UserDefaults.standard.set(data, forKey: cacheKey)
            return Result(companies: decoded.items, logos: await logos(for: decoded.items), isStale: false)
        }

        if let cached = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode(TopResponse.self, from: cached), !decoded.items.isEmpty {
            return Result(companies: decoded.items, logos: await logos(for: decoded.items), isStale: true)
        }
        return nil
    }

    /// Widgets can't use `AsyncImage`, so the logos are downloaded here and embedded in the entry.
    private static func logos(for companies: [TopCompany]) async -> [String: Data] {
        await withTaskGroup(of: (String, Data)?.self) { group in
            for company in companies {
                guard let ticker = company.ticker, let urlString = company.logo_url, let url = URL(string: urlString) else { continue }
                group.addTask {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 8
                    guard let (data, response) = try? await URLSession.shared.data(for: request),
                          (response as? HTTPURLResponse)?.statusCode == 200,
                          data.count < 200_000,
                          UIImage(data: data) != nil else { return nil }
                    return (ticker, data)
                }
            }
            var out: [String: Data] = [:]
            for await pair in group { if let pair { out[pair.0] = pair.1 } }
            return out
        }
    }
}

extension TopCompany {
    /// Placeholder / preview data, so the widget gallery has something to show.
    static let samples: [TopCompany] = [
        ("NVIDIA", "NVDA", "$5.54 T", 1.2), ("Apple", "AAPL", "$4.91 T", -0.4), ("Alphabet", "GOOG", "$4.25 T", 0.9),
        ("Microsoft", "MSFT", "$3.97 T", 0.3), ("Amazon", "AMZN", "$2.83 T", 1.8), ("Meta", "META", "$1.83 T", -1.1),
        ("Broadcom", "AVGO", "$1.73 T", 0.6), ("Tesla", "TSLA", "$1.51 T", -2.3), ("Micron", "MU", "$1.16 T", 3.4),
        ("Berkshire", "BRK-B", "$1.05 T", 0.1),
    ].enumerated().map { i, t in
        TopCompany(rank: i + 1, name: t.0, ticker: t.1, country: nil, logo_url: nil, price_display: nil,
                   change_24h: t.3, market_cap: 1e12, market_cap_display: t.2)
    }
}
