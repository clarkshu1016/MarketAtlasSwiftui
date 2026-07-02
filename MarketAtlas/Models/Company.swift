import Foundation

struct Company: Codable, Identifiable, Hashable {
    var id: String { ticker ?? name }

    let name: String
    let ticker: String?
    let slug: String?
    let country: String?
    let logo_url: String?
    let company_url: String?

    let market_cap_rank: Int?
    let price: Double?
    let price_display: String?
    let change_24h: Double?

    let market_cap: Double?
    let market_cap_display: String?
    let earnings: Double?
    let earnings_display: String?
    let revenue: Double?
    let revenue_display: String?
    let employees: Int?
    let pe_ratio: Double?
    let dividend_yield: Double?
    let mcap_gain: Double?
    let mcap_gain_display: String?
    let mcap_loss: Double?
    let mcap_loss_display: String?
    let operating_margin: Double?
    let cost_to_borrow: Double?
    let total_assets: Double?
    let total_assets_display: String?
    let net_assets: Double?
    let net_assets_display: String?
    let total_liabilities: Double?
    let total_liabilities_display: String?
    let total_debt: Double?
    let total_debt_display: String?
    let cash_on_hand: Double?
    let cash_on_hand_display: String?
    let price_to_book: Double?
    var sector: String? = nil
    let tags: [String]?
}

struct CompaniesResponse: Codable {
    let total: Int
    let companies: [Company]
    let last_updated: String?
}
