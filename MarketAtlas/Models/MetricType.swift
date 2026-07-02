import Foundation

enum MetricType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case marketCap        = "market_cap"
    case earnings         = "earnings"
    case revenue          = "revenue"
    case employees        = "employees"
    case peRatio          = "pe_ratio"
    case dividendYield    = "dividend_yield"
    case mcapGain         = "mcap_gain"
    case mcapLoss         = "mcap_loss"
    case operatingMargin  = "operating_margin"
    case costToBorrow     = "cost_to_borrow"
    case totalAssets      = "total_assets"
    case netAssets        = "net_assets"
    case totalLiabilities = "total_liabilities"
    case totalDebt        = "total_debt"
    case cashOnHand       = "cash_on_hand"
    case priceToBook      = "price_to_book"

    var label: String {
        switch self {
        case .marketCap:        return "Market Cap"
        case .earnings:         return "Earnings"
        case .revenue:          return "Revenue"
        case .employees:        return "Employees"
        case .peRatio:          return "P/E Ratio"
        case .dividendYield:    return "Dividend %"
        case .mcapGain:         return "Cap Gain"
        case .mcapLoss:         return "Cap Loss"
        case .operatingMargin:  return "Op. Margin"
        case .costToBorrow:     return "Borrow Cost"
        case .totalAssets:      return "Total Assets"
        case .netAssets:        return "Net Assets"
        case .totalLiabilities: return "Liabilities"
        case .totalDebt:        return "Total Debt"
        case .cashOnHand:       return "Cash"
        case .priceToBook:      return "P/B Ratio"
        }
    }

    var icon: String {
        switch self {
        case .marketCap:        return "chart.pie.fill"
        case .earnings:         return "dollarsign.circle.fill"
        case .revenue:          return "arrow.up.right.circle.fill"
        case .employees:        return "person.3.fill"
        case .peRatio:          return "divide.circle.fill"
        case .dividendYield:    return "percent"
        case .mcapGain:         return "arrow.up.forward.circle.fill"
        case .mcapLoss:         return "arrow.down.backward.circle.fill"
        case .operatingMargin:  return "gauge.with.needle.fill"
        case .costToBorrow:     return "creditcard.fill"
        case .totalAssets:      return "building.columns.fill"
        case .netAssets:        return "checkmark.seal.fill"
        case .totalLiabilities: return "minus.circle.fill"
        case .totalDebt:        return "banknote.fill"
        case .cashOnHand:       return "dollarsign.bank.building.fill"
        case .priceToBook:      return "book.fill"
        }
    }

    func value(from c: Company) -> Double? {
        switch self {
        case .marketCap:        return c.market_cap
        case .earnings:         return c.earnings
        case .revenue:          return c.revenue
        case .employees:        return c.employees.map(Double.init)
        case .peRatio:          return c.pe_ratio
        case .dividendYield:    return c.dividend_yield
        case .mcapGain:         return c.mcap_gain
        case .mcapLoss:         return c.mcap_loss
        case .operatingMargin:  return c.operating_margin
        case .costToBorrow:     return c.cost_to_borrow
        case .totalAssets:      return c.total_assets
        case .netAssets:        return c.net_assets
        case .totalLiabilities: return c.total_liabilities
        case .totalDebt:        return c.total_debt
        case .cashOnHand:       return c.cash_on_hand
        case .priceToBook:      return c.price_to_book
        }
    }

    func display(from c: Company) -> String {
        switch self {
        case .marketCap:        return c.market_cap_display        ?? "—"
        case .earnings:         return c.earnings_display          ?? "—"
        case .revenue:          return c.revenue_display           ?? "—"
        case .employees:
            guard let e = c.employees else { return "—" }
            if e >= 1_000_000 { return String(format: "%.1fM", Double(e) / 1_000_000) }
            if e >= 1_000     { return String(format: "%.0fK", Double(e) / 1_000) }
            return "\(e)"
        case .peRatio:          return c.pe_ratio.map          { String(format: "%.2f\u{00D7}", $0) } ?? "—"
        case .dividendYield:
            guard let v = c.dividend_yield, v != 0 else { return "—" }
            return String(format: "%.2f%%", v)
        case .mcapGain:         return c.mcap_gain_display          ?? "—"
        case .mcapLoss:         return c.mcap_loss_display          ?? "—"
        case .operatingMargin:
            guard let v = c.operating_margin, v != 0 else { return "—" }
            return String(format: "%.2f%%", v)
        case .costToBorrow:
            guard let v = c.cost_to_borrow, v != 0 else { return "—" }
            return String(format: "%.2f%%", v)
        case .totalAssets:      return c.total_assets_display       ?? "—"
        case .netAssets:        return c.net_assets_display         ?? "—"
        case .totalLiabilities: return c.total_liabilities_display  ?? "—"
        case .totalDebt:        return c.total_debt_display         ?? "—"
        case .cashOnHand:       return c.cash_on_hand_display       ?? "—"
        case .priceToBook:      return c.price_to_book.map     { String(format: "%.2f\u{00D7}", $0) }  ?? "—"
        }
    }
}
