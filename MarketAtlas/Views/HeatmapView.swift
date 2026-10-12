import SwiftUI

/// World map of markets: one tile per country, sized by total market cap and coloured by the
/// market-cap-weighted change over the selected period. Tap a country for its largest companies.
struct HeatmapView: View {
    enum Period: String, CaseIterable, Identifiable {
        case ytd, y1 = "1y", y3 = "3y", y5 = "5y"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .ytd: "YTD"
            case .y1:  "1Y"
            case .y3:  "3Y"
            case .y5:  "5Y"
            }
        }
    }

    @Binding var period: Period
    @State private var selectedCountry: String?
    @State private var response: CountryHeatmapResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                if let response {
                    Text("World market cap \(Money.short(response.world_market_cap)) · tile size = market cap, colour = change")
                }
            }

            if let response, !response.items.isEmpty {
                Section {
                    TreemapView(weights: response.items.map(\.market_cap)) { i, size in
                        let item = response.items[i]
                        Button { selectedCountry = item.country } label: {
                            HeatTile(title: item.name, flag: item.flag, change: item.change_pct,
                                     marketCap: item.market_cap, size: size)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(Money.short(item.market_cap)), \(item.share_pct.formatted()) percent of world, \(HeatColor.text(item.change_pct))")
                    }
                    .aspectRatio(0.95, contentMode: .fit)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)

                    HeatLegend()
                        .listRowBackground(Color.clear)
                } footer: {
                    if let note = response.note { Text(DisplayName.note(note)) }
                }

                // Every country, including the ones whose tiles are too small to read.
                Section("All countries/regions") {
                    ForEach(Array(response.items.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink {
                            CountryHeatmapView(country: item.country, period: period)
                        } label: {
                            CountryRow(rank: idx + 1, item: item)
                        }
                    }
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
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Market Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCountry) { country in
            CountryHeatmapView(country: country, period: period)
        }
        .shareCard(title: "World market heatmap", key: response.map { "\($0.period)|\($0.items.count)|\($0.world_market_cap)" }) {
            if let response { CountryHeatmapShareCard(response: response) }
        }
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchCountryHeatmap(period: period.rawValue)
        } catch is CancellationError {
            return
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Country → companies

struct CountryHeatmapView: View {
    let country: String
    let period: HeatmapView.Period

    @State private var response: CompanyHeatmapResponse?
    @State private var selectedCompany: Company?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var displayName: String { DisplayName.country(country) }

    var body: some View {
        List {
            if let response, !response.items.isEmpty {
                Section {
                    TreemapView(weights: response.items.map(\.market_cap)) { i, size in
                        let item = response.items[i]
                        Button { selectedCompany = item.company } label: {
                            HeatTile(title: item.company.tileName, code: item.company.readableTicker, flag: nil,
                                     logoCompany: item.company,
                                     change: item.change_pct, marketCap: item.market_cap, size: size)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.company.name), \(Money.short(item.market_cap)), \(HeatColor.text(item.change_pct))")
                    }
                    .aspectRatio(0.95, contentMode: .fit)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)

                    HeatLegend()
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Largest \(response.items.count) companies · \(Money.short(response.country_market_cap)) total")
                } footer: {
                    if let note = response.note { Text(DisplayName.note(note)) }
                }

                Section("Companies") {
                    ForEach(Array(response.items.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink {
                            CompanyDetailView(company: item.company)
                        } label: {
                            CompanyHeatRow(rank: idx + 1, item: item)
                        }
                    }
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
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCompany) { company in
            CompanyDetailView(company: company)
        }
        .shareCard(title: "\(displayName) heatmap", key: response.map { "\($0.country)|\($0.period)|\($0.items.count)" }) {
            if let response { CompanyHeatmapShareCard(countryName: DisplayName.countryName(country), response: response) }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchCompanyHeatmap(country: country, period: period.rawValue)
        } catch is CancellationError {
            return
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Pieces

struct HeatTile: View {
    let title: String
    /// A short, human-readable code (e.g. "NVDA") usable on small tiles. Exchange codes like
    /// "688825.SS" or "9984.T" mean nothing to users, so those are never passed here.
    var code: String? = nil
    /// Country tiles: the flag emoji. Shown on every tile that has any room at all.
    let flag: String?
    /// Company tiles: used for a logo when the tile is too small for text.
    var logoCompany: Company? = nil
    let change: Double?
    var marketCap: Double? = nil
    let size: CGSize

    private struct Line: Identifiable {
        let id = UUID()
        let text: String
        let size: CGFloat
        let weight: Font.Weight
        let opacity: Double
    }

    // MARK: Fitting

    /// Rough text width in points. Bold UI text averages ~0.6 em per character; emoji are wider.
    private func width(_ text: String, size: CGFloat) -> CGFloat {
        text.reduce(CGFloat(0)) { $0 + ($1.unicodeScalars.first.map { $0.value > 0x2000 && !$0.properties.isAlphabetic } == true ? 1.3 : 0.6) * size }
    }

    /// Largest font size ≤ `maxSize` at which `text` fits `available` points wide, or nil if that
    /// would be smaller than `minSize`.
    private func fit(_ text: String, available: CGFloat, maxSize: CGFloat, minSize: CGFloat) -> CGFloat? {
        let unit = width(text, size: 1)
        guard unit > 0 else { return nil }
        let s = min(maxSize, available / unit)
        return s >= minSize ? s : nil
    }

    /// Picks the richest set of lines that fits: name + change + cap, then name + change, then
    /// just the name, with the flag / short code as the fallback label. Falls back to a bare
    /// mark (flag or logo) when not even that fits.
    private var lines: [Line] {
        let pad: CGFloat = 3
        let aw = size.width - pad * 2
        let ah = size.height - pad * 2
        guard aw > 0, ah > 0 else { return [] }

        let base = max(10, min(15, min(size.width, size.height) / 6))
        let changeText = HeatColor.text(change)
        let capText = marketCap.map(Money.short)

        // Label candidates, most informative first. Each is one or more lines; for countries the
        // name wraps under the flag when "flag + name" doesn't fit on one line.
        var labels: [[String]] = []
        if let flag {
            labels = [["\(flag) \(title)"], [flag, title], [flag]]
        } else {
            labels = [[title]]
            if let code, code != title { labels.append([code]) }
        }

        for wantCap in [true, false] {
            for wantChange in [true, false] {
                if wantCap && (capText == nil || !wantChange) { continue }
                for label in labels {
                    var out: [Line] = []
                    var fits = true
                    for (i, text) in label.enumerated() {
                        let isMark = text == flag
                        let isSecondary = i > 0
                        let maxSize = isMark ? base * 1.6 : (isSecondary ? base * 0.85 : base)
                        guard let ls = fit(text, available: aw, maxSize: maxSize, minSize: isMark ? 8 : 9) else { fits = false; break }
                        out.append(Line(text: text, size: ls, weight: .bold, opacity: 1))
                    }
                    guard fits else { continue }
                    if wantChange {
                        guard let cs = fit(changeText, available: aw, maxSize: base * 0.9, minSize: 8) else { continue }
                        out.append(Line(text: changeText, size: cs, weight: .semibold, opacity: 1))
                    }
                    if wantCap, let capText {
                        guard let ms = fit(capText, available: aw, maxSize: base * 0.8, minSize: 8) else { continue }
                        out.append(Line(text: capText, size: ms, weight: .medium, opacity: 0.85))
                    }
                    let height = out.reduce(0) { $0 + $1.size * 1.2 }
                    if height <= ah { return out }
                }
            }
        }
        return []
    }

    /// What to draw when no text configuration fits: the flag, or the company logo.
    private var markSize: CGFloat { min(size.width, size.height) - 2 }

    var body: some View {
        let text = lines
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(HeatColor.color(for: change))

            if !text.isEmpty {
                VStack(spacing: 1) {
                    ForEach(text) { line in
                        Text(line.text)
                            .font(.system(size: line.size, weight: line.weight, design: .rounded))
                            .opacity(line.opacity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(3)
            } else if let flag, markSize >= 5 {
                Text(flag).font(.system(size: markSize * 0.8)).minimumScaleFactor(0.3).lineLimit(1)
            } else if let logoCompany, logoCompany.logo_url != nil, markSize >= 10 {
                CompanyLogoView(company: logoCompany, size: min(markSize, 28))
            }
        }
        .contentShape(Rectangle())
    }
}

struct HeatLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("−\(Int(HeatColor.range))%").font(.caption2).foregroundStyle(.secondary)
            LinearGradient(
                colors: stride(from: -1.0, through: 1.0, by: 0.25).map { HeatColor.color(for: $0 * HeatColor.range) },
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())
            Text("+\(Int(HeatColor.range))%").font(.caption2).foregroundStyle(.secondary)
            Circle().fill(HeatColor.color(for: nil)).frame(width: 8, height: 8)
            Text("no data").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

private struct CountryRow: View {
    let rank: Int
    let item: CountryHeatItem

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24)
            Text(item.flag).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 15, weight: .semibold))
                Text("\(Money.short(item.market_cap)) · \(item.share_pct.formatted(.number.precision(.fractionLength(1))))% of world · \(item.company_count) companies")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(HeatColor.text(item.change_pct))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(HeatColor.textColor(item.change_pct))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank), \(item.name), \(Money.short(item.market_cap)), \(HeatColor.text(item.change_pct))")
    }
}

struct CompanyHeatRow: View {
    let rank: Int
    let item: CompanyHeatItem

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24)
            CompanyLogoView(company: item.company, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.company.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(Money.short(item.market_cap)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(HeatColor.text(item.change_pct))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(HeatColor.textColor(item.change_pct))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank), \(item.company.name), \(Money.short(item.market_cap)), \(HeatColor.text(item.change_pct))")
    }
}
