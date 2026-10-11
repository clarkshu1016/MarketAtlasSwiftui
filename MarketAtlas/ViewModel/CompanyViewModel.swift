import SwiftUI
import Observation

@Observable
final class CompanyViewModel {
    var allCompanies: [Company] = [] { didSet { recomputeFiltered() } }
    var availableCountries: [String] = []
    var availableTags: [String] = []
    var stats: StatsResponse?
    var selectedMetric: MetricType = .marketCap { didSet { recomputeFiltered() } }
    var sortDescending: Bool = true { didSet { recomputeFiltered() } }
    var selectedCountry: String? = nil { didSet { recomputeFiltered() } }
    var selectedTag: String? = nil { didSet { recomputeFiltered() } }
    var searchText: String = "" { didSet { recomputeFiltered() } }
    var isLoading = false
    var errorMessage: String?
    private var lastLoadedAt: Date?

    /// Filtered + sorted list. Cached: it is recomputed only when an input changes,
    /// not on every SwiftUI body evaluation (the full list is ~11k companies).
    private(set) var filteredCompanies: [Company] = []

    // MARK: - Data freshness

    /// When the server last refreshed its company data (from `/api/stats`).
    var dataUpdatedAt: Date? {
        guard let raw = stats?.last_updated else { return nil }
        // Backend sends microsecond precision ("…07.566263+00:00"); drop the fraction to parse reliably.
        let trimmed = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }

    // MARK: - Filtering

    private func recomputeFiltered() {
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

        // Decorate-sort-undecorate: read each sort key once instead of twice per comparison.
        let metric = selectedMetric
        let descending = sortDescending
        filteredCompanies = list
            .map { (company: $0, value: metric.value(from: $0)) }
            .sorted { a, b in
                switch (a.value, b.value) {
                case (nil, nil):           return a.company.name < b.company.name
                case (nil, _):             return false
                case (_, nil):             return true
                case (let av?, let bv?):   return descending ? av > bv : av < bv
                }
            }
            .map(\.company)
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
            sortDescending = metric.defaultDescending
        }
    }
}
