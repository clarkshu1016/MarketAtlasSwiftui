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

    /// Only Cash has quarterly data from the server
    var supportsQuarterly: Bool { self == .cashOnHand }
}

struct BarChartPoint: Identifiable {
    let id = UUID()
    let year: Int
    let value: Int64
    let yoy: Double?
    var yearStr: String { String(year) }

    init(year: Int, value: Int64, yoy: Double?) {
        self.year = year; self.value = value; self.yoy = yoy
    }
}

struct QuarterBarPoint: Identifiable {
    let id = UUID()
    let year: Int
    let quarter: Int   // 1-4
    let value: Int64
    var yearStr: String  { String(year) }
    var quarterLabel: String { "Q\(quarter)" }
}

// MARK: - Main view

struct FinancialChartView: View {
    let company: Company

    @State private var response: FinancialResponse?
    @State private var quarterlyResponse: QuarterlyResponse?
    @State private var isLoading = true
    @State private var selectedTab: FinancialTab = .earnings
    @State private var isQuarterly = false
    @State private var selectedYearStr: String? = nil

    // MARK: Computed data

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
                return Double(pt.value - p) / Swift.abs(Double(p)) * 100
            }
            return BarChartPoint(year: pt.year, value: pt.value, yoy: yoy)
        }
    }

    /// Last 4 years of quarterly cash data (16 quarters max)
    private var quarterlyPoints: [QuarterBarPoint] {
        guard let resp = quarterlyResponse else { return [] }
        let all = resp.financials.cash_on_hand
            .sorted { $0.year != $1.year ? $0.year < $1.year : $0.quarter < $1.quarter }
        let recentYears = Set(all.map(\.year)).sorted().suffix(4)
        return all
            .filter { recentYears.contains($0.year) }
            .map { QuarterBarPoint(year: $0.year, quarter: $0.quarter, value: $0.value) }
    }

    private var showingQuarterly: Bool {
        isQuarterly && selectedTab.supportsQuarterly && !quarterlyPoints.isEmpty
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Annual Financials")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // Tab selector
            HStack(spacing: 4) {
                ForEach(FinancialTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                            if !tab.supportsQuarterly { isQuarterly = false }
                        }
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
                        .background(selectedTab == tab ? Color.accentColor : Color.clear)
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
                // Legend row
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

                    if !showingQuarterly {
                        Label {
                            Text("YoY %")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        } icon: {
                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                        }
                    }

                    // Quarterly checkbox — only visible on Cash tab
                    if selectedTab.supportsQuarterly {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isQuarterly.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isQuarterly ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 13))
                                    .foregroundStyle(isQuarterly ? Color.accentColor : .secondary)
                                Text("Quarterly")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                if showingQuarterly {
                    quarterlyBarChart
                        .padding(.horizontal, 8)
                        .padding(.bottom, 16)
                } else {
                    annualBarChart
                        .padding(.horizontal, 8)

                    FinancialDataTable(points: chartPoints)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .task(id: company.slug) { await load() }
    }

    // MARK: Annual chart

    @ViewBuilder
    private var annualBarChart: some View {
        let points = chartPoints
        let values = points.map { Double($0.value) }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range  = Swift.abs(maxVal - minVal)
        let yMin: Double = minVal < 0 ? minVal - range * 0.08 : 0
        let yMax: Double = maxVal > 0 ? maxVal + range * 0.28 : range * 0.25
        let yoys      = points.compactMap { $0.yoy }
        let yoyMin    = yoys.min() ?? -100
        let yoyMax    = yoys.max() ?? 100
        let yoyRange  = yoyMax == yoyMin ? 1.0 : yoyMax - yoyMin
        let valRange  = yMax == yMin ? 1.0 : yMax - yMin

        let normYoy: (Double) -> Double = { y in
            yMin + ((y - yoyMin) / yoyRange) * valRange * 0.6 + valRange * 0.2
        }

        Chart {
            if values.contains(where: { $0 < 0 }) {
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
                .foregroundStyle(pt.value >= 0 ? Color.accentColor.opacity(0.8) : Color.red.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center, spacing: 3) {
                    Text(formatValue(pt.value))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            ForEach(points.filter { $0.yoy != nil }) { pt in
                LineMark(x: .value("Year", pt.yearStr), y: .value("YoY", normYoy(pt.yoy!)))
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Year", pt.yearStr), y: .value("YoY", normYoy(pt.yoy!)))
                    .foregroundStyle(Color.orange)
                    .symbolSize(25)
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 11)) } }
        .frame(height: 180)
    }

    // MARK: Quarterly chart (Cash only)

    @ViewBuilder
    private var quarterlyBarChart: some View {
        let points  = quarterlyPoints
        let maxVal  = points.map { Double($0.value) }.max() ?? 1
        let yMax    = maxVal * 1.25
        let byYear  = Dictionary(grouping: points, by: { $0.yearStr })

        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(points) { pt in
                    BarMark(
                        x: .value("Year", pt.yearStr),
                        y: .value("Cash", Double(pt.value))
                    )
                    .foregroundStyle(by: .value("Quarter", pt.quarterLabel))
                    .position(by: .value("Quarter", pt.quarterLabel), axis: .horizontal)
                    .cornerRadius(2)
                }
            }
            .chartForegroundStyleScale([
                "Q1": Color.accentColor,
                "Q2": Color.accentColor.opacity(0.72),
                "Q3": Color.accentColor.opacity(0.48),
                "Q4": Color.accentColor.opacity(0.28),
            ])
            .chartLegend(.hidden)
            .chartYScale(domain: 0...yMax)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatValue(Int64(v)))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 11)) } }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    guard let frame = proxy.plotFrame else { return }
                                    let x = drag.location.x - geo[frame].minX
                                    if let yr: String = proxy.value(atX: x) {
                                        selectedYearStr = yr
                                    }
                                }
                                .onEnded { _ in selectedYearStr = nil }
                        )
                }
            }
            .padding(.top, 14)
            .frame(height: 214)
            .clipped()

            // Per-year tooltip
            if let yr = selectedYearStr, let qpts = byYear[yr] {
                let sorted = qpts.sorted { $0.quarter < $1.quarter }
                let total  = sorted.reduce(Int64(0)) { $0 + $1.value }

                VStack(alignment: .leading, spacing: 4) {
                    Text(yr)
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(sorted) { pt in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(quarterColor(pt.quarter))
                                .frame(width: 8, height: 8)
                            Text(pt.quarterLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatValue(pt.value))
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    Divider()
                    HStack {
                        Text("Total")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(formatValue(total))
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .frame(width: 155)
                .padding(.leading, 8)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: Load

    private func load() async {
        guard let slug = company.slug else { isLoading = false; return }
        isLoading = true
        async let annual    = try? APIService.shared.fetchFinancials(slug: slug)
        async let quarterly = try? APIService.shared.fetchQuarterlyFinancials(slug: slug)
        (response, quarterlyResponse) = await (annual, quarterly)
        isLoading = false
    }

    // MARK: Helpers

    private func quarterColor(_ q: Int) -> Color {
        switch q {
        case 1:  return Color.accentColor
        case 2:  return Color.accentColor.opacity(0.72)
        case 3:  return Color.accentColor.opacity(0.48)
        default: return Color.accentColor.opacity(0.28)
        }
    }

    private func formatValue(_ v: Int64) -> String {
        let d = Double(v), sign = d < 0 ? "-" : "", a = Swift.abs(d)
        switch a {
        case 1e12...: return "\(sign)$\(String(format: "%.2f", a/1e12))T"
        case 1e9...:  return "\(sign)$\(String(format: "%.2f", a/1e9))B"
        case 1e6...:  return "\(sign)$\(String(format: "%.1f", a/1e6))M"
        default:      return "\(sign)$\(Int64(a))"
        }
    }
}
