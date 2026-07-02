import Foundation

struct StatsResponse: Codable {
    let total_companies: Int
    let total_market_cap: Double?
    let total_market_cap_display: String?
    let countries: Int
    let last_updated: String?
}

struct CountriesResponse: Codable {
    let countries: [String]
    let total: Int
}
