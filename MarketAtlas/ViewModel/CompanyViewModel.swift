import SwiftUI
import Observation

@Observable
final class CompanyViewModel {
    var allCompanies: [Company] = []
    var availableCountries: [String] = []
    var availableTags: [String] = []
    var stats: StatsResponse?
    var selectedMetric: MetricType = .marketCap
    var sortDescending: Bool = true
    var selectedCountry: String? = nil
    var selectedTag: String? = nil
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?
    private var lastLoadedAt: Date?

    // MARK: - Computed

    var filteredCompanies: [Company] {
        var list = allCompanies

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                ($0.ticker?.lowercased().contains(q) ?? false)
            }
        }

        if let country = selectedCountry {
            let cl = country.lowercased()
            list = list.filter { $0.country?.lowercased().contains(cl) ?? false }
        }

        if let tag = selectedTag {
            list = list.filter { $0.tags?.contains(tag) ?? false }
        }

        list.sort { a, b in
            let av = selectedMetric.value(from: a)
            let bv = selectedMetric.value(from: b)
            switch (av, bv) {
            case (nil, nil): return a.name < b.name
            case (nil, _):   return false
            case (_, nil):   return true
            case (let av?, let bv?):
                return sortDescending ? av > bv : av < bv
            }
        }
        return list
    }

    // MARK: - Actions

    func load() async {
        // Skip if data is fresh (loaded within last 5 minutes) — prevents hammering on tab switches
        if let last = lastLoadedAt, Date().timeIntervalSince(last) < 300, !allCompanies.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        async let companiesFetch  = APIService.shared.fetchCompanies()
        async let statsFetch      = APIService.shared.fetchStats()
        async let countriesFetch  = APIService.shared.fetchCountries()
        do {
            let (c, s, countries) = try await (companiesFetch, statsFetch, countriesFetch)
            allCompanies       = c
            stats              = s
            availableCountries = countries
            availableTags      = Self.buildTagList(from: c)
            lastLoadedAt       = Date()
        } catch is CancellationError {
            // Task cancelled by SwiftUI (e.g. view re-render) — not a real error
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private static func buildTagList(from companies: [Company]) -> [String] {
        var freq: [String: Int] = [:]
        for company in companies {
            for tag in company.tags ?? [] { freq[tag, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.map(\.key)
    }

    func selectMetric(_ metric: MetricType) {
        if selectedMetric == metric {
            sortDescending.toggle()
        } else {
            selectedMetric = metric
            sortDescending = true
        }
    }
}
