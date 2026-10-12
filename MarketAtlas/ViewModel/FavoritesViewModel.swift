import Foundation
import Observation

@Observable
final class FavoritesViewModel {
    var companies: [Company] = [] {
        didSet { tickerSet = Set(companies.compactMap(\.ticker)) }
    }
    var isLoading = false
    var errorMessage: String?
    /// True when the last `load` failed — lets the UI show an error state instead of "No Favourites Yet".
    private(set) var loadFailed = false
    /// Set when add/remove fails after being rolled back; shown once as an alert, then cleared.
    var syncError: String?

    private var tickerSet: Set<String> = []

    func isFavorite(_ ticker: String?) -> Bool {
        guard let ticker else { return false }
        return tickerSet.contains(ticker)
    }

    func load(token: String) async {
        isLoading = true
        errorMessage = nil
        loadFailed = false
        do {
            let result = try await APIService.shared.fetchFavorites(token: token)
            companies = result
        } catch is CancellationError {
            // Task cancelled by SwiftUI — not a real error
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
        }
        isLoading = false
    }

    /// Optimistically flips the favourite state, then syncs with the server.
    /// If the request fails the change is rolled back and `syncError` is set,
    /// so the star never shows a state the server doesn't have.
    func toggle(company: Company, token: String) async {
        guard let ticker = company.ticker else { return }
        let wasFavorite = isFavorite(ticker)
        let previous = companies

        if wasFavorite {
            companies.removeAll { $0.ticker == ticker }
        } else {
            companies.insert(company, at: 0)
        }

        do {
            if wasFavorite {
                try await APIService.shared.removeFavorite(ticker: ticker, token: token)
            } else {
                try await APIService.shared.addFavorite(ticker: ticker, token: token)
            }
        } catch {
            companies = previous
            if !(error is CancellationError) {
                syncError = wasFavorite
                    ? String(localized: "Couldn't remove \(company.name) from favourites. \(error.localizedDescription)")
                    : String(localized: "Couldn't add \(company.name) to favourites. \(error.localizedDescription)")
            }
        }
    }
}
