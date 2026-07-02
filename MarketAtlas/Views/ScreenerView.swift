import SwiftUI

private let kSectors = [
    "Technology", "Finance", "Consumer", "Industrials",
    "Healthcare", "Energy", "Materials", "Media & Telecom",
    "Real Estate", "Services",
]

struct ScreenerView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var marketCapMin: Double = 0
    @State private var marketCapMax: Double = 5_000
    @State private var peRatioMax: Double = 500
    @State private var dividendYieldMin: Double = 0
    @State private var operatingMarginMin: Double = -0.5
    @State private var selectedCountry: String = ""
    @State private var selectedSector: String = ""

    @State private var showCountryPicker = false
    @State private var showSectorPicker = false
    @State private var availableCountries: [String] = []
    @State private var countrySearch = ""

    @State private var results: [Company] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    // AI search
    @State private var aiQuery = ""
    @State private var isAILoading = false
    @State private var parsedFiltersText: String?
    @State private var aiErrorMessage: String?

    var body: some View {
        NavigationStack {
            screenerContent
                .sheet(isPresented: $showCountryPicker) { countryPickerSheet }
                .sheet(isPresented: $showSectorPicker) { sectorPickerSheet }
        }
    }

    // MARK: - Screener content

    private var screenerContent: some View {
        List {
            // ── AI Natural Language Search ─────────────────────────────────
            Section {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    TextField("e.g. Japanese tech stocks with P/E under 20", text: $aiQuery)
                        .submitLabel(.search)
                        .onSubmit { Task { await runAIScreener() } }
                    if isAILoading {
                        ProgressView().scaleEffect(0.75)
                    } else if !aiQuery.isEmpty {
                        Button { Task { await runAIScreener() } } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let hint = parsedFiltersText {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let aiErr = aiErrorMessage {
                    Text(aiErr)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("AI Search (Gemma)")
            } footer: {
                Text("Describe what you're looking for in plain language.")
            }

            Section("Market Cap") {
                HStack {
                    Text("Min: \(formatBillions(marketCapMin * 1e9))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Max: \(formatBillions(marketCapMax * 1e9))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: $marketCapMin, in: 0...(marketCapMax - 1), step: 10)
                    .tint(.accentColor)
                Slider(value: $marketCapMax, in: (marketCapMin + 1)...5_000, step: 10)
                    .tint(.accentColor)
            }

            Section("Max P/E Ratio") {
                HStack {
                    Text("P/E ≤ \(peRatioMax < 500 ? "\(Int(peRatioMax))" : "Any")")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Slider(value: $peRatioMax, in: 1...500, step: 1)
                    .tint(.accentColor)
            }

            Section("Min Dividend Yield") {
                HStack {
                    Text("Yield ≥ \(String(format: "%.1f%%", dividendYieldMin * 100))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Slider(value: $dividendYieldMin, in: 0...0.15, step: 0.001)
                    .tint(.accentColor)
            }

            Section("Min Operating Margin") {
                HStack {
                    Text("Margin ≥ \(String(format: "%.0f%%", operatingMarginMin * 100))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Slider(value: $operatingMarginMin, in: -0.5...0.5, step: 0.01)
                    .tint(.accentColor)
            }

            Section("Country") {
                Button { showCountryPicker = true } label: {
                    HStack {
                        Text(selectedCountry.isEmpty ? "Any country" : selectedCountry)
                            .foregroundStyle(selectedCountry.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Sector") {
                Button { showSectorPicker = true } label: {
                    HStack {
                        Text(selectedSector.isEmpty ? "Any sector" : selectedSector)
                            .foregroundStyle(selectedSector.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // ── Results ───────────────────────────────────────────────
            if isLoading {
                Section {
                    HStack { Spacer(); ProgressView("Screening…"); Spacer() }
                }
            } else if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            } else if hasSearched {
                Section(results.isEmpty ? "No Results" : "\(results.count) Companies") {
                    if results.isEmpty {
                        ContentUnavailableView(
                            "No Matches",
                            systemImage: "magnifyingglass",
                            description: Text("Try adjusting your filters.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, company in
                            NavigationLink {
                                CompanyDetailView(company: company)
                            } label: {
                                CompanyRowView(company: company, rank: idx + 1, metric: .marketCap)
                            }
                            .listRowInsets(EdgeInsets(top: 3, leading: 14, bottom: 3, trailing: 14))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 10)
                            )
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Screener")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Screen") {
                    Task { await runScreener() }
                }
                .disabled(isLoading)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Country picker

    private var countryPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    selectedCountry = ""
                    showCountryPicker = false
                } label: {
                    HStack {
                        Text("Any country").foregroundStyle(.primary)
                        Spacer()
                        if selectedCountry.isEmpty {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                ForEach(filteredCountries, id: \.self) { country in
                    Button {
                        selectedCountry = country
                        showCountryPicker = false
                    } label: {
                        HStack {
                            Text(country).foregroundStyle(.primary)
                            Spacer()
                            if selectedCountry == country {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $countrySearch, prompt: "Search countries")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCountryPicker = false }
                }
            }
        }
        .task {
            if availableCountries.isEmpty {
                availableCountries = (try? await APIService.shared.fetchCountries()) ?? []
            }
        }
    }

    private var filteredCountries: [String] {
        if countrySearch.isEmpty { return availableCountries }
        return availableCountries.filter { $0.localizedCaseInsensitiveContains(countrySearch) }
    }

    // MARK: - Sector picker

    private var sectorPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    selectedSector = ""
                    showSectorPicker = false
                } label: {
                    HStack {
                        Text("Any sector").foregroundStyle(.primary)
                        Spacer()
                        if selectedSector.isEmpty {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                ForEach(kSectors, id: \.self) { sector in
                    Button {
                        selectedSector = sector
                        showSectorPicker = false
                    } label: {
                        HStack {
                            Text(sector).foregroundStyle(.primary)
                            Spacer()
                            if selectedSector == sector {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Sector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSectorPicker = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func runAIScreener() async {
        guard !aiQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isAILoading = true
        aiErrorMessage = nil
        parsedFiltersText = nil
        do {
            let response = try await APIService.shared.aiScreener(query: aiQuery)
            let f = response.filters
            // Apply parsed filters to sliders/pickers
            marketCapMin = (f.market_cap_min ?? 0) / 1e9
            marketCapMax = min((f.market_cap_max ?? 5_000e9) / 1e9, 5_000)
            peRatioMax   = f.pe_ratio_max ?? 500
            dividendYieldMin   = f.dividend_yield_min ?? 0
            operatingMarginMin = f.operating_margin_min ?? -0.5
            selectedCountry = f.country ?? ""
            selectedSector  = f.sector ?? ""
            results     = response.companies
            hasSearched = true
            // Build a human-readable hint
            var parts: [String] = []
            if let c = f.country { parts.append(c) }
            if let s = f.sector  { parts.append(s) }
            if let v = f.pe_ratio_max { parts.append("P/E ≤ \(Int(v))") }
            if let v = f.market_cap_min { parts.append("MCap ≥ \(formatBillions(v))") }
            if let v = f.dividend_yield_min { parts.append("Div ≥ \(String(format: "%.1f%%", v*100))") }
            parsedFiltersText = parts.isEmpty ? nil : "Filters: " + parts.joined(separator: " · ")
        } catch {
            aiErrorMessage = "AI Search unavailable: \(error.localizedDescription)"
        }
        isAILoading = false
    }

    private func runScreener() async {
        isLoading = true
        errorMessage = nil
        hasSearched = true
        var params: [String: String] = [
            "order": "desc",
            "sort_by": "market_cap",
        ]
        if marketCapMin > 0 {
            params["market_cap_min"] = String(marketCapMin * 1e9)
        }
        if marketCapMax < 5_000 {
            params["market_cap_max"] = String(marketCapMax * 1e9)
        }
        if peRatioMax < 500 {
            params["pe_ratio_max"] = String(Int(peRatioMax))
        }
        if dividendYieldMin > 0 {
            params["dividend_yield_min"] = String(dividendYieldMin)
        }
        if operatingMarginMin > -0.5 {
            params["operating_margin_min"] = String(operatingMarginMin)
        }
        if !selectedCountry.isEmpty {
            params["country"] = selectedCountry
        }
        if !selectedSector.isEmpty {
            params["sector"] = selectedSector
        }
        do {
            results = try await APIService.shared.fetchScreener(params: params, token: authVM.token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func formatBillions(_ v: Double) -> String {
        switch v {
        case 1e12...: return String(format: "$%.1fT", v / 1e12)
        case 1e9...:  return String(format: "$%.0fB", v / 1e9)
        default:      return String(format: "$%.0fM", v / 1e6)
        }
    }
}

#Preview {
    ScreenerView()
        .environment(AuthViewModel())
        .environment(FavoritesViewModel())
}
