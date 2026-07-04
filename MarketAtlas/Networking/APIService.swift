import Foundation

#if DEBUG
  #if targetEnvironment(simulator)
  private let kBaseURL = "http://127.0.0.1:8000"   // Simulator → Mac's localhost (IPv4 explicit)
  #else
  private let kBaseURL = "http://shuclarknoMacBook-Pro.local:8000" // Physical device → Mac's mDNS hostname (stable)
  #endif
#else
private let kBaseURL = "https://marketatlas-api.appdevgpt.com"
#endif

final class APIService {
    static let shared = APIService()
    static let baseURL = URL(string: kBaseURL)!
    private let decoder = JSONDecoder()
    private let base = URL(string: kBaseURL)!

    // MARK: - Companies

    func fetchCompanies() async throws -> [Company] {
        var comps = URLComponents(url: base.appendingPathComponent("api/companies"), resolvingAgainstBaseURL: true)!
        comps.queryItems = [
            URLQueryItem(name: "sort_by", value: "market_cap"),
            URLQueryItem(name: "order",   value: "desc"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try decoder.decode(CompaniesResponse.self, from: data).companies
    }

    func fetchStats() async throws -> StatsResponse {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/stats"))
        return try decoder.decode(StatsResponse.self, from: data)
    }

    func fetchCountries() async throws -> [String] {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/countries"))
        return try decoder.decode(CountriesResponse.self, from: data).countries
    }

    func fetchFinancials(slug: String) async throws -> FinancialResponse {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/companies/\(slug)/financials"))
        return try decoder.decode(FinancialResponse.self, from: data)
    }

    func fetchQuarterlyFinancials(slug: String) async throws -> QuarterlyResponse {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/companies/\(slug)/financials/quarterly"))
        return try decoder.decode(QuarterlyResponse.self, from: data)
    }

    func fetchPriceHistory(slug: String, range: String = "1y", token: String? = nil) async throws -> PriceHistoryResponse {
        var comps = URLComponents(url: base.appendingPathComponent("api/companies/\(slug)/price-history"), resolvingAgainstBaseURL: true)!
        comps.queryItems = [URLQueryItem(name: "range", value: range)]
        var req = URLRequest(url: comps.url!)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(PriceHistoryResponse.self, from: data)
    }

    func fetchMarketCapHistory(slug: String) async throws -> MarketCapHistoryResponse {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/companies/\(slug)/market-cap-history"))
        return try decoder.decode(MarketCapHistoryResponse.self, from: data)
    }

    // MARK: - Favorites

    func fetchFavorites(token: String) async throws -> [Company] {
        var req = URLRequest(url: base.appendingPathComponent("api/favorites"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(CompaniesResponse.self, from: data).companies
    }

    func addFavorite(ticker: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("api/favorites/\(ticker)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode != 409 else { return } // already exists
    }

    func removeFavorite(ticker: String, token: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("api/favorites/\(ticker)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Pro endpoints

    func fetchMovers() async throws -> MoversResponse {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/market/movers"))
        return try decoder.decode(MoversResponse.self, from: data)
    }

    func fetchScreener(params: [String: String], token: String?) async throws -> [Company] {
        var comps = URLComponents(url: base.appendingPathComponent("api/screener"), resolvingAgainstBaseURL: true)!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(CompaniesResponse.self, from: data).companies
    }

    func fetchCompare(tickers: [String], token: String) async throws -> [Company] {
        var comps = URLComponents(url: base.appendingPathComponent("api/compare"), resolvingAgainstBaseURL: true)!
        comps.queryItems = [URLQueryItem(name: "tickers", value: tickers.joined(separator: ","))]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(CompaniesResponse.self, from: data).companies
    }

    func fetchReturns(slug: String, token: String) async throws -> ReturnsResponse {
        var req = URLRequest(url: base.appendingPathComponent("api/companies/\(slug)/returns"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(ReturnsResponse.self, from: data)
    }

    // MARK: - AI Chat

    func sendChatMessage(message: String, history: [ChatMessage]) async throws -> ChatResponse {
        var req = URLRequest(url: base.appendingPathComponent("api/ai/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 180  // LLM inference can be slow
        req.httpBody = try JSONEncoder().encode(ChatRequest(message: message, history: history))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(ChatResponse.self, from: data)
    }

    // MARK: - AI Screener

    func aiScreener(query: String) async throws -> AIScreenerResponse {
        var req = URLRequest(url: base.appendingPathComponent("api/ai/screener"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(AIScreenerResponse.self, from: data)
    }
}
