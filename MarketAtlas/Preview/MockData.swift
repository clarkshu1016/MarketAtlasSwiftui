import Foundation

// MARK: - Mock Companies

extension Company {
    static let mockNVIDIA = Company(
        name: "NVIDIA", ticker: "NVDA", slug: "nvidia",
        country: "\u{1F1FA}\u{1F1F8} USA",
        logo_url: "https://companiesmarketcap.com/img/company-logos/64/NVDA.png",
        company_url: "https://companiesmarketcap.com/nvidia/marketcap/",
        market_cap_rank: 1, price: 210.69, price_display: "$210.69", change_24h: 2.95,
        market_cap: 5_103_000_000_000, market_cap_display: "$5.103 T",
        earnings: 141_700_000_000, earnings_display: "$141.70 B",
        revenue: 130_000_000_000, revenue_display: "$130.00 B",
        employees: 36_000,
        pe_ratio: 38.5, dividend_yield: 0.03,
        mcap_gain: 1_200_000_000_000, mcap_gain_display: "$1.200 T",
        mcap_loss: nil, mcap_loss_display: nil,
        operating_margin: 54.2, cost_to_borrow: nil,
        total_assets: 96_000_000_000, total_assets_display: "$96.00 B",
        net_assets: 58_000_000_000, net_assets_display: "$58.00 B",
        total_liabilities: 38_000_000_000, total_liabilities_display: "$38.00 B",
        total_debt: 8_500_000_000, total_debt_display: "$8.50 B",
        cash_on_hand: 34_000_000_000, cash_on_hand_display: "$34.00 B",
        price_to_book: 40.2,
        tags: ["📟 Semiconductors", "👩‍💻 Tech", "🔌 Electronics", "🦾 AI"]
    )

    static let mockApple = Company(
        name: "Apple", ticker: "AAPL", slug: "apple",
        country: "\u{1F1FA}\u{1F1F8} USA",
        logo_url: "https://companiesmarketcap.com/img/company-logos/64/AAPL.png",
        company_url: "https://companiesmarketcap.com/apple/marketcap/",
        market_cap_rank: 3, price: 298.01, price_display: "$298.01", change_24h: 0.70,
        market_cap: 4_376_000_000_000, market_cap_display: "$4.376 T",
        earnings: 101_000_000_000, earnings_display: "$101.00 B",
        revenue: 395_000_000_000, revenue_display: "$395.00 B",
        employees: 161_000,
        pe_ratio: 29.1, dividend_yield: 0.55,
        mcap_gain: nil, mcap_gain_display: nil,
        mcap_loss: nil, mcap_loss_display: nil,
        operating_margin: 31.5, cost_to_borrow: nil,
        total_assets: 364_000_000_000, total_assets_display: "$364.00 B",
        net_assets: 56_000_000_000, net_assets_display: "$56.00 B",
        total_liabilities: 308_000_000_000, total_liabilities_display: "$308.00 B",
        total_debt: 97_000_000_000, total_debt_display: "$97.00 B",
        cash_on_hand: 73_000_000_000, cash_on_hand_display: "$73.00 B",
        price_to_book: 48.5, tags: nil
    )

    static let mockWalmart = Company(
        name: "Walmart", ticker: "WMT", slug: "walmart",
        country: "\u{1F1FA}\u{1F1F8} USA",
        logo_url: nil, company_url: nil,
        market_cap_rank: 15, price: 117.18, price_display: "$117.18", change_24h: -0.80,
        market_cap: 940_000_000_000, market_cap_display: "$940.00 B",
        earnings: 15_000_000_000, earnings_display: "$15.00 B",
        revenue: 713_000_000_000, revenue_display: "$713.16 B",
        employees: 2_100_000,
        pe_ratio: 37.2, dividend_yield: 1.1,
        mcap_gain: nil, mcap_gain_display: nil,
        mcap_loss: nil, mcap_loss_display: nil,
        operating_margin: 4.2, cost_to_borrow: nil,
        total_assets: 260_000_000_000, total_assets_display: "$260.00 B",
        net_assets: 80_000_000_000, net_assets_display: "$80.00 B",
        total_liabilities: 180_000_000_000, total_liabilities_display: "$180.00 B",
        total_debt: 55_000_000_000, total_debt_display: "$55.00 B",
        cash_on_hand: 12_000_000_000, cash_on_hand_display: "$12.00 B",
        price_to_book: 5.8, tags: nil
    )

    static let mockSamples: [Company] = [.mockNVIDIA, .mockApple, .mockWalmart]
}

// MARK: - Mock Stats

extension StatsResponse {
    static let mock = StatsResponse(
        total_companies: 892,
        total_market_cap: 65_279_000_000_000,
        total_market_cap_display: "$65.279T",
        countries: 52,
        last_updated: nil
    )
}
