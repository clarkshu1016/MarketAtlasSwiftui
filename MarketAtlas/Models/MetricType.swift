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

    // Derived from fields we already have — no extra scraping needed.
    case priceToSales        = "price_to_sales"
    case earningsYield       = "earnings_yield"
    case netCash             = "net_cash"
    case debtToAssets        = "debt_to_assets"
    case revenuePerEmployee  = "revenue_per_employee"

    /// Which way the list sorts the first time the metric is picked. Cheap-is-better ratios
    /// start ascending; everything that existed before keeps its original (descending) behaviour.
    var defaultDescending: Bool {
        switch self {
        case .priceToSales, .debtToAssets: return false
        default:                           return true
        }
    }

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
        case .priceToSales:       return "P/S Ratio"
        case .earningsYield:      return "Earnings Yield"
        case .netCash:            return "Net Cash"
        case .debtToAssets:       return "Debt / Assets"
        case .revenuePerEmployee: return "Revenue / Employee"
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
        case .priceToSales:       return "cart.fill"
        case .earningsYield:      return "chart.line.uptrend.xyaxis"
        case .netCash:            return "plus.forwardslash.minus"
        case .debtToAssets:       return "scalemass.fill"
        case .revenuePerEmployee: return "person.fill.checkmark"
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
        case .priceToSales:
            guard let cap = c.market_cap, let rev = c.revenue, cap > 0, rev > 0 else { return nil }
            return cap / rev
        case .earningsYield:
            guard let cap = c.market_cap, let earn = c.earnings, cap > 0 else { return nil }
            return earn / cap * 100
        case .netCash:
            guard let cash = c.cash_on_hand, let debt = c.total_debt else { return nil }
            return cash - debt
        case .debtToAssets:
            guard let debt = c.total_debt, let assets = c.total_assets, assets > 0 else { return nil }
            return debt / assets * 100
        case .revenuePerEmployee:
            guard let rev = c.revenue, let emp = c.employees, emp > 0, rev > 0 else { return nil }
            return rev / Double(emp)
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
        case .priceToSales:     return value(from: c).map { String(format: "%.2f\u{00D7}", $0) } ?? "—"
        case .earningsYield:    return value(from: c).map { String(format: "%.2f%%", $0) } ?? "—"
        case .netCash:          return value(from: c).map(Money.short) ?? "—"
        case .debtToAssets:     return value(from: c).map { String(format: "%.1f%%", $0) } ?? "—"
        case .revenuePerEmployee: return value(from: c).map(Money.short) ?? "—"
        }
    }
}
