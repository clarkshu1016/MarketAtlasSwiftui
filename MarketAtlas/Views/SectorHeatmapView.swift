import SwiftUI

/// Industry map: one tile per sector, sized by total market cap and coloured by the market-cap-weighted
/// change over the selected period. Tap a sector for its largest companies.
struct SectorHeatmapView: View {
    @State private var period: HeatmapView.Period = .ytd
    @State private var selectedSector: String?
    @State private var response: SectorHeatmapResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(HeatmapView.Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                if let response {
                    Text("Total market cap \(Money.short(response.total_market_cap)) · tile size = market cap, colour = change")
                }
            }

            if let response, !response.items.isEmpty {
                Section {
                    TreemapView(weights: response.items.map(\.market_cap)) { i, size in
                        let item = response.items[i]
                        Button { selectedSector = item.sector } label: {
                            HeatTile(title: item.name, flag: item.icon, change: item.change_pct,
                                     marketCap: item.market_cap, size: size)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(Money.short(item.market_cap)), \(HeatColor.text(item.change_pct))")
                    }
                    .aspectRatio(0.95, contentMode: .fit)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)

                    HeatLegend()
                        .listRowBackground(Color.clear)
                } footer: {
                    if let note = response.note { Text(DisplayName.note(note)) }
                }

                Section("All sectors") {
                    ForEach(Array(response.items.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink {
                            SectorCompaniesView(sector: item.sector, period: period)
                        } label: {
                            SectorRow(rank: idx + 1, item: item)
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
        .navigationTitle("Sector Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSector) { sector in
            SectorCompaniesView(sector: sector, period: period)
        }
        .shareCard(title: String(localized: "Sector heatmap"),
                   key: response.map { "\($0.period)|\($0.items.count)|\($0.total_market_cap)" }) {
            if let response { SectorHeatmapShareCard(response: response) }
        }
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchSectorHeatmap(period: period.rawValue)
        } catch is CancellationError {
            return
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Sector → companies

struct SectorCompaniesView: View {
    let sector: String
    let period: HeatmapView.Period

    @State private var response: SectorCompaniesResponse?
    @State private var selectedCompany: Company?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var displayName: String { Sector.displayName(sector) }

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
                    Text("Largest \(response.items.count) companies · \(Money.short(response.sector_market_cap)) total")
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
        .shareCard(title: String(localized: "\(displayName) heatmap"),
                   key: response.map { "\($0.sector)|\($0.period)|\($0.items.count)" }) {
            if let response {
                CompanyHeatmapShareCard(
                    countryName: displayName,
                    response: CompanyHeatmapResponse(country: response.sector, period: response.period,
                                                     country_market_cap: response.sector_market_cap,
                                                     note: response.note, items: response.items))
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchSectorCompanies(sector: sector, period: period.rawValue)
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

private struct SectorRow: View {
    let rank: Int
    let item: SectorHeatItem

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24)
            Text(item.icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 15, weight: .semibold))
                Text("\(Money.short(item.market_cap)) · \(item.share_pct.formatted(.number.precision(.fractionLength(1))))% of total · \(item.company_count) companies")
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
