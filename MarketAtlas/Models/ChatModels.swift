import Foundation

// MARK: - Request

struct ChatMessage: Codable {
    let role: String   // "user" | "assistant"
    let content: String
}

struct ChatRequest: Codable {
    let message: String
    let history: [ChatMessage]
}

// MARK: - Response Blocks

enum ChatBlock: Codable {
    case text(TextChatBlock)
    case companyTable(CompanyTableBlock)
    case barChart(BarChartBlock)
    case priceChart(PriceChartBlock)

    private enum TypeKey: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let blockType = try container.decode(String.self, forKey: .type)
        switch blockType {
        case "text":
            self = .text(try TextChatBlock(from: decoder))
        case "company_table":
            self = .companyTable(try CompanyTableBlock(from: decoder))
        case "bar_chart":
            self = .barChart(try BarChartBlock(from: decoder))
        case "price_chart":
            self = .priceChart(try PriceChartBlock(from: decoder))
        default:
            self = .text(TextChatBlock(content: "[Unsupported block: \(blockType)]"))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let b):         try b.encode(to: encoder)
        case .companyTable(let b): try b.encode(to: encoder)
        case .barChart(let b):     try b.encode(to: encoder)
        case .priceChart(let b):   try b.encode(to: encoder)
        }
    }
}

struct TextChatBlock: Codable {
    let type: String
    let content: String

    init(type: String = "text", content: String) {
        self.type = type
        self.content = content
    }
}

struct CompanyTableBlock: Codable {
    let type: String
    let title: String?
    let companies: [CompanyChatItem]
}

struct CompanyChatItem: Codable, Identifiable {
    var id: String { slug ?? ticker ?? name }
    let slug: String?
    let name: String
    let ticker: String?
    let country: String?
    let sector: String?
    let tags: [String]?
    let market_cap_display: String?
    let earnings_display: String?
    let revenue_display: String?
    let market_cap: Double?
    let change_24h: Double?
    let logo_url: String?
    let price_display: String?
    let pe_ratio: Double?
    let dividend_yield: Double?
    let operating_margin: Double?
    let employees: Int?
}

extension CompanyChatItem {
    var asCompany: Company {
        Company(
            name: name,
            ticker: ticker,
            slug: slug,
            country: country,
            logo_url: logo_url,
            company_url: nil,
            market_cap_rank: nil,
            price: nil,
            price_display: price_display,
            change_24h: change_24h,
            market_cap: market_cap,
            market_cap_display: market_cap_display,
            earnings: nil,
            earnings_display: earnings_display,
            revenue: nil,
            revenue_display: revenue_display,
            employees: employees,
            pe_ratio: pe_ratio,
            dividend_yield: dividend_yield,
            mcap_gain: nil,
            mcap_gain_display: nil,
            mcap_loss: nil,
            mcap_loss_display: nil,
            operating_margin: operating_margin,
            cost_to_borrow: nil,
            total_assets: nil,
            total_assets_display: nil,
            net_assets: nil,
            net_assets_display: nil,
            total_liabilities: nil,
            total_liabilities_display: nil,
            total_debt: nil,
            total_debt_display: nil,
            cash_on_hand: nil,
            cash_on_hand_display: nil,
            price_to_book: nil,
            sector: sector,
            tags: tags
        )
    }
}

struct BarChartBlock: Codable {
    let type: String
    let title: String
    let metric: String
    let slug: String
    let data: [ChartDataPoint]
}

struct ChartDataPoint: Codable {
    let year: Int
    let value: Double
}

struct PriceChartBlock: Codable {
    let type: String
    let slug: String
    let company_name: String
}

struct ChatResponse: Codable {
    let blocks: [ChatBlock]
}
