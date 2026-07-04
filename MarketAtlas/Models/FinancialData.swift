import Foundation

struct FinancialPoint: Codable {
    let year: Int
    let value: Int64
}

struct QuarterlyPoint: Codable {
    let year: Int
    let quarter: Int   // 1-4
    let value: Int64
}

struct QuarterlyMetrics: Codable {
    let cash_on_hand: [QuarterlyPoint]
}

struct QuarterlyResponse: Codable {
    let slug: String
    let ticker: String?
    let financials: QuarterlyMetrics
}

struct PricePoint: Codable, Identifiable {
    let timestamp: Int
    let price: Double
    var id: Int { timestamp }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }
}

struct PriceHistoryResponse: Codable {
    let slug: String
    let ticker: String?
    let points: [PricePoint]
}

struct MarketCapPoint: Codable, Identifiable {
    let timestamp: Int
    let value: Double
    var id: Int { timestamp }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }
}

struct MarketCapHistoryResponse: Codable {
    let slug: String
    let ticker: String?
    let points: [MarketCapPoint]
}

struct FinancialMetrics: Codable {
    let revenue: [FinancialPoint]
    let earnings: [FinancialPoint]
    let cash_on_hand: [FinancialPoint]
}

struct FinancialResponse: Codable {
    let slug: String
    let ticker: String?
    let financials: FinancialMetrics
}
