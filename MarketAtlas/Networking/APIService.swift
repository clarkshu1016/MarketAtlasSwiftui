import Foundation
#if DEBUG
import Pulse
#endif

// MARK: - Server environment

/// Which backend the app talks to. Release builds are always `.production`; Debug builds can switch
/// in Settings (a physical device can't reach the Mac's local server when away from home).
enum ServerEnvironment: String, CaseIterable, Identifiable {
    case production, local

    var id: String { rawValue }
    var label: String { self == .production ? "Production" : "Local Mac" }

    static let storageKey = "debug_server_environment"
    static let productionURL = "https://marketatlas-api.appdevgpt.com"

    var url: URL {
        switch self {
        case .production:
            return URL(string: Self.productionURL)!
        case .local:
            #if targetEnvironment(simulator)
            return URL(string: "http://127.0.0.1:8000")!                    // Simulator → Mac's localhost (IPv4 explicit)
            #else
            return URL(string: "http://shuclarknoMacBook-Pro.local:8000")!  // Device → Mac's mDNS hostname
            #endif
        }
    }

    /// Default: the simulator uses the local server, a physical device uses production.
    static var `default`: ServerEnvironment {
        #if targetEnvironment(simulator)
        return .local
        #else
        return .production
        #endif
    }

    static var current: ServerEnvironment {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return raw.flatMap(ServerEnvironment.init(rawValue:)) ?? .default
        #else
        return .production
        #endif
    }
}

extension Notification.Name {
    /// Posted (Debug builds) after the user switches server — sessions and cached data belong to the old one.
    static let serverEnvironmentChanged = Notification.Name("MarketAtlas.serverEnvironmentChanged")
}

// MARK: - Errors

enum APIError: LocalizedError {
    /// The server rejected the bearer token (expired / revoked).
    case unauthorized
    case server(statusCode: Int)
    case offline
    case timeout
    case network
    case decoding

    var errorDescription: String? {
        switch self {
        case .unauthorized:  return String(localized: "Your session has expired. Please sign in again.")
        case .server(let c): return String(localized: "The server had a problem (\(c)). Please try again in a moment.")
        case .offline:       return String(localized: "You appear to be offline. Check your connection and try again.")
        case .timeout:       return String(localized: "The request timed out. Please try again.")
        case .network:       return String(localized: "Couldn't reach the server. Please try again.")
        case .decoding:      return String(localized: "Received unexpected data from the server.")
        }
    }
}

extension Notification.Name {
    /// Posted (on the main thread) when an authenticated request comes back 401.
    static let apiUnauthorized = Notification.Name("MarketAtlas.apiUnauthorized")
}

// MARK: - Service

final class APIService {
    static let shared = APIService()
    static var baseURL: URL { ServerEnvironment.current.url }
    private let decoder = JSONDecoder()
    private var base: URL { Self.baseURL }

    // Debug builds route requests through Pulse so they show up in the debug console
    // (floating bubble). URLSessionProxy — not URLSessionProxyDelegate — is required
    // because it's the only Pulse option that works with async/await URLSession APIs.
    #if DEBUG
    private let session = URLSessionProxy(configuration: .default)
    #else
    private let session = URLSession.shared
    #endif

    // MARK: - Request plumbing

    /// Sends the request, validates the HTTP status and maps failures to `APIError`.
    /// Task cancellation is surfaced as `CancellationError` so callers can ignore it.
    @discardableResult
    private func send(_ request: URLRequest, allowing extra: Set<Int> = []) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:                                       throw CancellationError()
            case .notConnectedToInternet, .dataNotAllowed:         throw APIError.offline
            case .timedOut:                                        throw APIError.timeout
            default:                                               throw APIError.network
            }
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        switch http.statusCode {
        case 200..<300:
            return data
        case let code where extra.contains(code):
            return data
        case 401 where request.value(forHTTPHeaderField: "Authorization") != nil:
            await MainActor.run { NotificationCenter.default.post(name: .apiUnauthorized, object: nil) }
            throw APIError.unauthorized
        case let code:
            throw APIError.server(statusCode: code)
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, _ request: URLRequest) async throws -> T {
        let data = try await send(request)
        do { return try decoder.decode(T.self, from: data) } catch { throw APIError.decoding }
    }

    private func get(_ path: String, query: [URLQueryItem] = [], token: String? = nil) -> URLRequest {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func request(_ method: String, _ path: String, token: String? = nil) -> URLRequest {
        var req = get(path, token: token)
        req.httpMethod = method
        return req
    }

    // MARK: - Companies

    func fetchCompanies() async throws -> [Company] {
        let req = get("api/companies", query: [
            URLQueryItem(name: "sort_by", value: "market_cap"),
            URLQueryItem(name: "order",   value: "desc"),
        ])
        return try await fetch(CompaniesResponse.self, req).companies
    }

    func fetchStats() async throws -> StatsResponse {
        try await fetch(StatsResponse.self, get("api/stats"))
    }

    func fetchCountries() async throws -> [String] {
        try await fetch(CountriesResponse.self, get("api/countries")).countries
    }

    func fetchFinancials(slug: String) async throws -> FinancialResponse {
        try await fetch(FinancialResponse.self, get("api/companies/\(slug)/financials"))
    }

    func fetchQuarterlyFinancials(slug: String) async throws -> QuarterlyResponse {
        try await fetch(QuarterlyResponse.self, get("api/companies/\(slug)/financials/quarterly"))
    }

    func fetchPriceHistory(slug: String, range: String = "1y", token: String? = nil) async throws -> PriceHistoryResponse {
        let req = get("api/companies/\(slug)/price-history",
                      query: [URLQueryItem(name: "range", value: range)], token: token)
        return try await fetch(PriceHistoryResponse.self, req)
    }

    func fetchMarketCapHistory(slug: String) async throws -> MarketCapHistoryResponse {
        try await fetch(MarketCapHistoryResponse.self, get("api/companies/\(slug)/market-cap-history"))
    }

    // MARK: - Market insights

    func fetchPerformance(period: String, order: String, minMarketCap: Double, limit: Int = 50) async throws -> PerformanceResponse {
        let query = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "min_market_cap", value: String(Int(minMarketCap))),
        ]
        return try await fetch(PerformanceResponse.self, get("api/market/performance", query: query))
    }

    func fetchTimeMachine(date: Date, limit: Int = 20) async throws -> TimeMachineResponse {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let iso = String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
        let query = [URLQueryItem(name: "date", value: iso), URLQueryItem(name: "limit", value: String(limit))]
        return try await fetch(TimeMachineResponse.self, get("api/market/time-machine", query: query))
    }

    func fetchCountryHeatmap(period: String) async throws -> CountryHeatmapResponse {
        try await fetch(CountryHeatmapResponse.self,
                        get("api/market/heatmap/countries", query: [URLQueryItem(name: "period", value: period)]))
    }

    func fetchCompanyHeatmap(country: String, period: String, limit: Int = 80) async throws -> CompanyHeatmapResponse {
        let query = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return try await fetch(CompanyHeatmapResponse.self, get("api/market/heatmap/companies", query: query))
    }

    func fetchSectorHeatmap(period: String) async throws -> SectorHeatmapResponse {
        try await fetch(SectorHeatmapResponse.self,
                        get("api/market/heatmap/sectors", query: [URLQueryItem(name: "period", value: period)]))
    }

    func fetchSectorCompanies(sector: String, period: String, limit: Int = 80) async throws -> SectorCompaniesResponse {
        let query = [
            URLQueryItem(name: "sector", value: sector),
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return try await fetch(SectorCompaniesResponse.self, get("api/market/heatmap/sector-companies", query: query))
    }

    // MARK: - Favorites

    func fetchFavorites(token: String) async throws -> [Company] {
        try await fetch(CompaniesResponse.self, get("api/favorites", token: token)).companies
    }

    func addFavorite(ticker: String, token: String) async throws {
        // 409 = already a favourite, which is the state we wanted.
        try await send(request("POST", "api/favorites/\(ticker)", token: token), allowing: [409])
    }

    func removeFavorite(ticker: String, token: String) async throws {
        try await send(request("DELETE", "api/favorites/\(ticker)", token: token))
    }

    // MARK: - Pro endpoints

    func fetchMovers() async throws -> MoversResponse {
        try await fetch(MoversResponse.self, get("api/market/movers"))
    }

    func fetchScreener(params: [String: String], token: String?) async throws -> [Company] {
        let query = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await fetch(CompaniesResponse.self, get("api/screener", query: query, token: token)).companies
    }

    func fetchCompare(tickers: [String], token: String) async throws -> [Company] {
        let req = get("api/compare",
                      query: [URLQueryItem(name: "tickers", value: tickers.joined(separator: ","))],
                      token: token)
        return try await fetch(CompaniesResponse.self, req).companies
    }

    func fetchReturns(slug: String, token: String) async throws -> ReturnsResponse {
        try await fetch(ReturnsResponse.self, get("api/companies/\(slug)/returns", token: token))
    }

    // MARK: - Account

    func deleteAccount(token: String) async throws {
        try await send(request("DELETE", "auth/account", token: token))
    }

    // MARK: - AI Chat

    func sendChatMessage(message: String, history: [ChatMessage]) async throws -> ChatResponse {
        var req = request("POST", "api/ai/chat")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 180  // LLM inference can be slow
        req.httpBody = try JSONEncoder().encode(ChatRequest(message: message, history: history))
        return try await fetch(ChatResponse.self, req)
    }

    // MARK: - AI Screener

    func aiScreener(query: String) async throws -> AIScreenerResponse {
        var req = request("POST", "api/ai/screener")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        return try await fetch(AIScreenerResponse.self, req)
    }
}
