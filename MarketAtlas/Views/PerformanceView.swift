import SwiftUI

/// Market-cap leaderboards: best/worst performers over a period, and distance from the all-time peak.
struct PerformanceView: View {
    private enum Period: String, CaseIterable, Identifiable {
        case ytd, y1 = "1y", y3 = "3y", y5 = "5y", y10 = "10y", peak = "ath"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .ytd: "YTD"
            case .y1:  "1Y"
            case .y3:  "3Y"
            case .y5:  "5Y"
            case .y10: "10Y"
            case .peak: "Peak"
            }
        }
        var title: String {
            switch self {
            case .ytd:  "Since January 1"
            case .y1:   "Past year"
            case .y3:   "Past 3 years"
            case .y5:   "Past 5 years"
            case .y10:  "Past 10 years"
            case .peak: "Distance from all-time high"
            }
        }
    }

    private enum Size: Double, CaseIterable, Identifiable {
        case all = 0, b1 = 1e9, b10 = 1e10, b100 = 1e11
        var id: Double { rawValue }
        var label: String {
            switch self {
            case .all: "All sizes"
            case .b1: "$1B+"
            case .b10: "$10B+"
            case .b100: "$100B+"
            }
        }
    }

    private struct LoadKey: Hashable { let period: Period; let ascending: Bool; let size: Size }

    @State private var period: Period = .ytd
    /// false → best first (gainers / near peak), true → worst first (losers / biggest drops)
    @State private var worstFirst = false
    @State private var size: Size = .all
    @State private var response: PerformanceResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var key: LoadKey { LoadKey(period: period, ascending: worstFirst, size: size) }

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Order", selection: $worstFirst) {
                    Text(period == .peak ? "Near Peak" : "Gainers").tag(false)
                    Text(period == .peak ? "Biggest Drops" : "Losers").tag(true)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(period.title)
            }
            .listRowSeparator(.hidden)

            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Company size", selection: $size) {
                        ForEach(Size.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label(size.label, systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Company size filter, \(size.label)")
            }
        }
        .onChange(of: period) { _, new in worstFirst = (new == .peak) }   // "biggest drops" is the interesting default
        .task(id: key) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let response, !response.items.isEmpty {
            Section {
                ForEach(Array(response.items.enumerated()), id: \.element.id) { idx, item in
                    NavigationLink {
                        CompanyDetailView(company: item.company)
                    } label: {
                        PerformanceRow(rank: idx + 1, item: item, isPeak: period == .peak)
                    }
                }
            } footer: {
                if let note = response.note { Text(note) }
            }
        } else if isLoading {
            ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }.buttonStyle(.borderedProminent)
            }
            .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView("No Results", systemImage: "chart.line.uptrend.xyaxis")
                .listRowBackground(Color.clear)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchPerformance(
                period: period.rawValue,
                order: worstFirst ? "asc" : "desc",
                minMarketCap: size.rawValue
            )
        } catch is CancellationError {
            return   // a newer request replaced this one
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct PerformanceRow: View {
    let rank: Int
    let item: PerformanceItem
    let isPeak: Bool

    private var color: Color { item.change_pct > 0 ? .green : (item.change_pct < 0 ? .red : .secondary) }

    private var changeText: String {
        let v = item.change_pct
        // Huge gains read better as a multiple ("×36") than "+3,584%".
        if v >= 1000 { return String(format: "×%.0f", v / 100 + 1) }
        return String(format: "%+.1f%%", v)
    }

    private var detail: String {
        let reference = Money.short(item.reference_value)
        let date = Money.monthYear(fromISO: item.reference_date)
        return isPeak ? "Peak \(reference) · \(date)" : "\(reference) → \(Money.short(item.end_value))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24)

            CompanyLogoView(company: item.company, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.company.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(changeText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank), \(item.company.name), \(changeText), \(detail)")
    }
}
