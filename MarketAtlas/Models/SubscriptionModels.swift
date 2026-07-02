import Foundation

struct MoversResponse: Codable {
    let gainers: [Company]
    let losers: [Company]
}

struct ReturnsResponse: Codable {
    let one_year: Double?
    let three_year: Double?
    let five_year: Double?
}

struct AIScreenerFilters: Codable {
    let market_cap_min: Double?
    let market_cap_max: Double?
    let pe_ratio_max: Double?
    let dividend_yield_min: Double?
    let operating_margin_min: Double?
    let country: String?
    let sector: String?
}

struct AIScreenerResponse: Codable {
    let query: String
    let filters: AIScreenerFilters
    let total: Int
    let companies: [Company]
}
