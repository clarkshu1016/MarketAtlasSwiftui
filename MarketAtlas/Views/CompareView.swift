import Charts
import SwiftUI

/// Put two to four companies side by side: a growth (or market-cap) chart and a table of key figures.
struct CompareView: View {
    /// Everything that can be picked (the Markets list).
    let pool: [Company]
    /// Opened from a company page: start with this company (looked up in `pool` for its full figures).
    var initial: Company? = nil

    private static let maxCompanies = 4
    private static let palette: [Color] = [
        Color(red: 0.25, green: 0.50, blue: 1.00),   // blue
        Color(red: 0.95, green: 0.35, blue: 0.30),   // red
        Color(red: 0.15, green: 0.70, blue: 0.45),   // green
        Color(red: 0.98, green: 0.65, blue: 0.10),   // amber
    ]

    enum Range: String, CaseIterable, Identifiable {
        case y1 = "1Y", y5 = "5Y", y10 = "10Y", max = "Max"
        var id: String { rawValue }
        /// Seconds back from the newest data point; nil = everything.
        var span: TimeInterval? {
            switch self {
            case .y1:  365 * 86_400
            case .y5:  5 * 365 * 86_400
            case .y10: 10 * 365 * 86_400
            case .max: nil
            }
        }
    }

    enum Mode: String, CaseIterable, Identifiable {
        case growth, marketCap
        var id: String { rawValue }
        var title: LocalizedStringKey { self == .growth ? "Growth" : "Market Cap" }
    }

    @State private var selected: [Company] = []
    @State private var history: [String: [MarketCapPoint]] = [:]
    @State private var loading: Set<String> = []
    @State private var failed: Set<String> = []
    @State private var range: Range = .y5
    @State private var mode: Mode = .growth
    @State private var showPicker = false

    // MARK: Derived data

    private struct Series: Identifiable {
        let id: String            // ticker
        let name: String
        let color: Color
        let points: [(date: Date, value: Double)]
        let startDate: Date?
    }

    private func color(at index: Int) -> Color { Self.palette[index % Self.palette.count] }

    private var series: [Series] {
        let all = selected.enumerated().compactMap { index, company -> (Int, Company, [MarketCapPoint])? in
            guard let slug = company.slug, let pts = history[slug], !pts.isEmpty else { return nil }
            return (index, company, pts)
        }
        guard let newest = all.compactMap({ $0.2.last?.timestamp }).max() else { return [] }
        let cutoff = range.span.map { newest - Int($0) } ?? 0

        return all.compactMap { index, company, pts in
            let inRange = pts.filter { $0.timestamp >= cutoff && $0.value > 0 }
            guard let first = inRange.first else { return nil }
            let values: [(Date, Double)] = inRange.map { p in
                (p.date, mode == .growth ? p.value / first.value * 100 : p.value)
            }
            return Series(id: company.id, name: Company.shortName(company.name), color: color(at: index),
                          points: values.map { (date: $0.0, value: $0.1) }, startDate: first.date)
        }
    }

    /// Companies whose records begin well after the start of the window.
    private var lateStarters: [Series] {
        guard let earliest = series.compactMap(\.startDate).min() else { return [] }
        return series.filter { ($0.startDate ?? earliest).timeIntervalSince(earliest) > 90 * 86_400 }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                companyChips
                if selected.count < 2 {
                    emptyState
                } else {
                    controls
                    chartCard
                    statsCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CompanyPickerSheet(pool: pool, alreadySelected: Set(selected.map(\.id))) { company in
                add(company)
            }
        }
        .task {
            // Start with the two biggest companies so there is something to look at straight away.
            if selected.isEmpty {
                let ranked = pool.filter { $0.slug != nil }.sorted { ($0.market_cap ?? 0) > ($1.market_cap ?? 0) }
                if let initial {
                    // Prefer the full record from the list: companies reached from a heatmap carry fewer fields.
                    // Only this company: the user picks what to compare it with, so the sheet opens straight away.
                    selected = [pool.first { $0.id == initial.id } ?? initial]
                    showPicker = true
                } else {
                    selected = Array(ranked.prefix(2))
                }
                for c in selected { await loadHistory(for: c) }
            }
        }
    }

    // MARK: Pieces

    private var companyChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(selected.enumerated()), id: \.element.id) { index, company in
                HStack(spacing: 10) {
                    Circle().fill(color(at: index)).frame(width: 10, height: 10)
                    CompanyLogoView(company: company, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Company.shortName(company.name)).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(company.ticker ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let slug = company.slug, loading.contains(slug) {
                        ProgressView()
                    } else if let slug = company.slug, failed.contains(slug) {
                        Button("Retry") { Task { await loadHistory(for: company) } }.font(.caption.weight(.semibold))
                    }
                    Button {
                        withAnimation { selected.removeAll { $0.id == company.id } }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("Remove")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if selected.count < Self.maxCompanies {
                Button { showPicker = true } label: {
                    Label("Add company", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 34)).foregroundStyle(.tertiary)
            Text("Pick at least two companies to compare.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Range", selection: $range) {
                ForEach(Range.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var chartCard: some View {
        let data = series
        return VStack(alignment: .leading, spacing: 10) {
            Text(mode == .growth ? "Growth, start of period = 100" : "Market cap")
                .font(.caption).foregroundStyle(.secondary)

            if data.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 240)
            } else {
                Chart {
                    ForEach(data) { s in
                        ForEach(Array(s.points.enumerated()), id: \.offset) { _, p in
                            LineMark(x: .value("Date", p.date), y: .value("Value", p.value),
                                     series: .value("Company", s.id))
                                .foregroundStyle(by: .value("Company", s.id))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.monotone)
                        }
                    }
                    if mode == .growth {
                        RuleMark(y: .value("Start", 100))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                    }
                }
                .chartForegroundStyleScale(domain: data.map(\.id), range: data.map(\.color))
                .chartLegend(.hidden)
                .chartYScale(domain: yDomain(data), type: mode == .growth ? .log : .linear)
                .chartYAxis {
                    AxisMarks(position: .trailing) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3, 3]))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(mode == .growth ? String(format: "%.0f", d) : Money.short(d)).font(.system(size: 10))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: range == .y1 ? .dateTime.month(.abbreviated) : .dateTime.year())
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 260)

                legend(data)

                if mode == .growth {
                    Text("Log scale, so equal percentage moves look equal.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                if !lateStarters.isEmpty {
                    Text("Some companies have no data at the start of this period, so their line begins later.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Keeps the axis tight around the data (the automatic log axis pads out to a whole power of ten).
    private func yDomain(_ data: [Series]) -> ClosedRange<Double> {
        let values = data.flatMap { $0.points.map(\.value) }
        guard let lo = values.min(), let hi = values.max(), lo > 0, hi > lo else { return 1...100 }
        if mode == .growth {
            return Swift.min(lo, 100) * 0.85 ... Swift.max(hi, 100) * 1.15
        }
        return lo * 0.9 ... hi * 1.1
    }

    private func legend(_ data: [Series]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(data) { s in
                HStack(spacing: 8) {
                    Circle().fill(s.color).frame(width: 8, height: 8)
                    Text(s.name).font(.footnote.weight(.semibold)).lineLimit(1)
                    Spacer()
                    if let last = s.points.last {
                        if mode == .growth {
                            let pct = last.value - 100
                            Text(String(format: "%+.1f%%", pct))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(pct >= 0 ? Color.green : Color.red)
                        } else {
                            Text(Money.short(last.value)).font(.footnote.weight(.bold))
                        }
                    }
                }
            }
        }
    }

    // MARK: Table

    private struct Row {
        let title: LocalizedStringKey
        let value: (Company) -> Double?
        let format: (Double) -> String
        let higherIsBetter: Bool?     // nil = no "winner" highlight
    }

    private var rows: [Row] {
        [
            Row(title: "Market Cap", value: { $0.market_cap }, format: Money.short, higherIsBetter: true),
            Row(title: "Revenue", value: { $0.revenue }, format: Money.short, higherIsBetter: true),
            Row(title: "Earnings", value: { $0.earnings }, format: Money.short, higherIsBetter: true),
            Row(title: "Operating margin", value: { $0.operating_margin }, format: { String(format: "%.1f%%", $0) }, higherIsBetter: true),
            Row(title: "P/E Ratio", value: { $0.pe_ratio }, format: { String(format: "%.1f", $0) }, higherIsBetter: nil),
            Row(title: "Dividend %", value: { $0.dividend_yield }, format: { String(format: "%.2f%%", $0) }, higherIsBetter: true),
            Row(title: "Employees", value: { $0.employees.map(Double.init) }, format: { Int($0).formatted() }, higherIsBetter: nil),
            Row(title: "Price change (24h)", value: { $0.change_24h }, format: { String(format: "%+.2f%%", $0) }, higherIsBetter: true),
        ]
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("").frame(width: 112, alignment: .leading)
                ForEach(Array(selected.enumerated()), id: \.element.id) { index, c in
                    Text(c.ticker ?? Company.shortName(c.name))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color(at: index))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                let values = selected.map { row.value($0) }
                let best: Double? = {
                    guard let better = row.higherIsBetter else { return nil }
                    let present = values.compactMap { $0 }
                    guard present.count > 1 else { return nil }
                    return better ? present.max() : present.min()
                }()
                HStack(spacing: 0) {
                    Text(row.title).font(.caption).foregroundStyle(.secondary)
                        .frame(width: 112, alignment: .leading)
                    ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                        Group {
                            if let v {
                                Text(row.format(v))
                                    .font(.system(size: 13, weight: v == best ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(v == best ? Color.accentColor : Color.primary)
                            } else {
                                Text("—").foregroundStyle(.quaternary)
                            }
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                if i < rows.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Actions

    private func add(_ company: Company) {
        guard selected.count < Self.maxCompanies, !selected.contains(where: { $0.id == company.id }) else { return }
        withAnimation { selected.append(company) }
        Task { await loadHistory(for: company) }
    }

    private func loadHistory(for company: Company) async {
        guard let slug = company.slug, history[slug] == nil else { return }
        loading.insert(slug); failed.remove(slug)
        defer { loading.remove(slug) }
        do {
            history[slug] = try await APIService.shared.fetchMarketCapHistory(slug: slug).points
        } catch {
            failed.insert(slug)
        }
    }
}

// MARK: - Picker

private struct CompanyPickerSheet: View {
    let pool: [Company]
    let alreadySelected: Set<String>
    let onPick: (Company) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Company] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = pool.filter { $0.slug != nil && !alreadySelected.contains($0.id) }
        guard !q.isEmpty else { return Array(base.prefix(60)) }
        return Array(base.filter { $0.name.lowercased().contains(q) || ($0.ticker ?? "").lowercased().contains(q) }.prefix(60))
    }

    var body: some View {
        NavigationStack {
            List(results) { company in
                Button {
                    onPick(company); dismiss()
                } label: {
                    HStack(spacing: 12) {
                        CompanyLogoView(company: company, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Company.shortName(company.name)).foregroundStyle(.primary)
                            Text(company.ticker ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let cap = company.market_cap { Text(Money.short(cap)).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search company or ticker…")
            .navigationTitle("Add company")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
