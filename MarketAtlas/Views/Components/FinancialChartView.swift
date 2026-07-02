import SwiftUI
import Charts

// MARK: - Supporting types

enum FinancialTab: String, CaseIterable {
    case earnings    = "earnings"
    case revenue     = "revenue"
    case cashOnHand  = "cash_on_hand"

    var label: String {
        switch self {
        case .earnings:   return "Net Profit"
        case .revenue:    return "Revenue"
        case .cashOnHand: return "Cash"
        }
    }

    var icon: String {
        switch self {
        case .earnings:   return "dollarsign.circle.fill"
        case .revenue:    return "arrow.up.right.circle.fill"
        case .cashOnHand: return "banknote.fill"
        }
    }
}

struct BarChartPoint: Identifiable {
    let id: UUID
    let year: Int
    let value: Int64
    let yoy: Double?

    var yearStr: String { String(year) }

    init(year: Int, value: Int64, yoy: Double?) {
        self.id = UUID()
        self.year = year
        self.value = value
        self.yoy = yoy
    }
}

// MARK: - Main view

struct FinancialChartView: View {
    let company: Company
    @State private var response: FinancialResponse? = nil
    @State private var isLoading = true
    @State private var selectedTab: FinancialTab = .earnings

    private var chartPoints: [BarChartPoint] {
        guard let resp = response else { return [] }
        let series: [FinancialPoint]
        switch selectedTab {
        case .earnings:   series = resp.financials.earnings
        case .revenue:    series = resp.financials.revenue
        case .cashOnHand: series = resp.financials.cash_on_hand
        }
        let sorted = series.sorted { $0.year < $1.year }.suffix(6)
        return sorted.enumerated().map { i, pt in
            let prev: Int64? = i > 0 ? sorted[sorted.index(sorted.startIndex, offsetBy: i - 1)].value : nil
            let yoy: Double? = prev.flatMap { p in
                guard p != 0 else { return nil }
                return (Double(pt.value - p) / Swift.abs(Double(p))) * 100
            }
            return BarChartPoint(year: pt.year, value: pt.value, yoy: yoy)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                Text("Annual Financials")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Segmented tab selector
            HStack(spacing: 4) {
                ForEach(FinancialTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(.horizontal, 16)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .padding(.bottom, 16)
            } else if chartPoints.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis")
                    .frame(minHeight: 160)
                    .padding(.bottom, 16)
            } else {
                // Legend
                HStack(spacing: 16) {
                    Label {
                        Text(selectedTab.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } icon: {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: 10, height: 10)
                    }
                    Label {
                        Text("YoY %")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                barChart
                    .padding(.horizontal, 8)

                dataTable
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .task(id: company.slug) { await load() }
    }

    // MARK: - Bar chart

    private var barChart: some View {
        let points = chartPoints
        let values = points.map { Double($0.value) }
        let hasNegative = values.contains { $0 < 0 }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = Swift.abs(maxVal - minVal)
        let yMin: Double = minVal < 0 ? minVal - range * 0.08 : 0
        let yMax: Double = maxVal > 0 ? maxVal + range * 0.28 : range * 0.25

        let yoys = points.compactMap { $0.yoy }
        let yoyMin = yoys.min() ?? -100
        let yoyMax = yoys.max() ?? 100
        let yoyRange = yoyMax == yoyMin ? 1.0 : yoyMax - yoyMin
        let valueRange = yMax == yMin ? 1.0 : yMax - yMin

        func normalizedYoy(_ yoy: Double) -> Double {
            let t = (yoy - yoyMin) / yoyRange
            return yMin + t * valueRange * 0.6 + valueRange * 0.2
        }

        return Chart {
            if hasNegative {
                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color(UIColor.separator))
            }
            ForEach(points) { pt in
                BarMark(
                    x: .value("Year", pt.yearStr),
                    y: .value("Value", Double(pt.value)),
                    width: .fixed(min(44, 200 / CGFloat(max(points.count, 1))))
                )
                .foregroundStyle(pt.value >= 0
                    ? Color.accentColor.opacity(0.8)
                    : Color.red.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center, spacing: 3) {
                    Text(formatValue(pt.value))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            ForEach(points.filter { $0.yoy != nil }) { pt in
                LineMark(
                    x: .value("Year", pt.yearStr),
                    y: .value("YoY", normalizedYoy(pt.yoy!))
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Year", pt.yearStr),
                    y: .value("YoY", normalizedYoy(pt.yoy!))
                )
                .foregroundStyle(Color.orange)
                .symbolSize(25)
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel().font(.system(size: 11))
            }
        }
        .frame(height: 180)
    }

    // MARK: - Data table

    private var dataTable: some View {
        FinancialDataTable(points: chartPoints)
    }

    // MARK: - Helpers

    private func load() async {
        guard let slug = company.slug else { isLoading = false; return }
        isLoading = true
        do {
            response = try await APIService.shared.fetchFinancials(slug: slug)
        } catch {
            response = nil
        }
        isLoading = false
    }

    private func formatValue(_ v: Int64) -> String {
        let d = Double(v)
        let sign = d < 0 ? "-" : ""
        let absVal = Swift.abs(d)
        switch absVal {
        case 1_000_000_000_000...: return "\(sign)$\(String(format: "%.2f", absVal / 1e12))T"
        case 1_000_000_000...:     return "\(sign)$\(String(format: "%.2f", absVal / 1e9))B"
        case 1_000_000...:         return "\(sign)$\(String(format: "%.1f", absVal / 1e6))M"
        default:                   return "\(sign)$\(Int64(absVal))"
        }
    }
}
