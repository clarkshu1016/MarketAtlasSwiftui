import Foundation
import Observation

@Observable
final class FavoritesViewModel {
    var companies: [Company] = [] {
        didSet { tickerSet = Set(companies.compactMap(\.ticker)) }
    }
    var isLoading = false
    var errorMessage: String?

    private var tickerSet: Set<String> = []

    func isFavorite(_ ticker: String?) -> Bool {
        guard let ticker else { return false }
        return tickerSet.contains(ticker)
    }

    func load(token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await APIService.shared.fetchFavorites(token: token)
            companies = result
            tickerSet = Set(result.compactMap(\.ticker))
        } catch is CancellationError {
            // Task cancelled by SwiftUI — not a real error
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggle(company: Company, token: String) async {
        guard let ticker = company.ticker else { return }
        if isFavorite(ticker) {
            tickerSet.remove(ticker)
            companies.removeAll { $0.ticker == ticker }
            try? await APIService.shared.removeFavorite(ticker: ticker, token: token)
        } else {
            tickerSet.insert(ticker)
            companies.insert(company, at: 0)
            try? await APIService.shared.addFavorite(ticker: ticker, token: token)
        }
    }
}
