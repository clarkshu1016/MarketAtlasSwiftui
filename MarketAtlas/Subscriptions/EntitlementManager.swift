import Foundation
import Observation
import StoreKit

/// The four ways to get in. The product IDs must match the ones created in App Store Connect.
enum PlanID: String, CaseIterable, Identifiable {
    case monthly, quarterly, yearly, lifetime

    var id: String { rawValue }
    var productID: String { "marketatlas.pro.\(rawValue)" }
    var isSubscription: Bool { self != .lifetime }

    /// Months covered by one payment, for the "per month" figure on the paywall.
    var months: Int? {
        switch self {
        case .monthly:   1
        case .quarterly: 3
        case .yearly:    12
        case .lifetime:  nil
        }
    }

    var title: String {
        switch self {
        case .monthly:   String(localized: "Monthly")
        case .quarterly: String(localized: "Quarterly")
        case .yearly:    String(localized: "Yearly")
        case .lifetime:  String(localized: "Lifetime")
        }
    }

    /// "month" / "3 months" / "year", used in "then $6.99 / month".
    var periodText: String {
        switch self {
        case .monthly:   String(localized: "month")
        case .quarterly: String(localized: "3 months")
        case .yearly:    String(localized: "year")
        case .lifetime:  ""
        }
    }
}

/// Decides whether the app is unlocked and runs purchases (StoreKit 2).
///
/// MarketAtlas used to be a paid download. Anyone who bought it keeps full access for good: StoreKit tells
/// us which build they first installed (`AppTransaction.originalAppVersion`), and every build up to
/// `lastPaidBuild` was sold for money.
@MainActor
@Observable
final class EntitlementManager {
    enum Reason: Equatable {
        case originalPurchaser
        case subscription(expires: Date?)
        case lifetime
        case debugOverride
    }

    enum Access: Equatable {
        case checking
        case locked
        case unlocked(Reason)
    }

    /// Builds up to and including this number were sold as a paid download (the live 1.0.0 is build 59;
    /// the first free build with the paywall is numbered above this).
    static let lastPaidBuild = 63
    private static let originalPurchaserKey = "entitlement_original_purchaser"

    private(set) var access: Access = .checking
    private(set) var products: [PlanID: Product] = [:]
    private(set) var productsLoaded = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    var isUnlocked: Bool {
        if case .unlocked = access { return true }
        return false
    }

    // MARK: Lifecycle

    func start() async {
        if updatesTask == nil {
            // Renewals, refunds and purchases made on another device arrive here.
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    await self?.refreshAccess()
                }
            }
        }
        await refreshAccess()
        await loadProducts()
    }

    func refreshAccess() async {
        #if DEBUG
        if DebugProOverride.isOn { access = .unlocked(.debugOverride); return }
        #endif

        if await isOriginalPurchaser() { access = .unlocked(.originalPurchaser); return }

        var reason: Reason?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == PlanID.lifetime.productID {
                reason = .lifetime
                break
            }
            if PlanID.allCases.contains(where: { $0.productID == transaction.productID }),
               let expires = transaction.expirationDate, expires > .now {
                reason = .subscription(expires: expires)
            }
        }
        access = reason.map { .unlocked($0) } ?? .locked
    }

    private func isOriginalPurchaser() async -> Bool {
        do {
            guard case .verified(let app) = try await AppTransaction.shared else { return false }
            // TestFlight / Xcode builds report a placeholder original version: never treat those as buyers.
            guard app.environment == .production else { return false }
            let isBuyer = (Int(app.originalAppVersion) ?? .max) <= Self.lastPaidBuild
            UserDefaults.standard.set(isBuyer, forKey: Self.originalPurchaserKey)
            return isBuyer
        } catch {
            // Offline on a first launch: fall back to what we learnt last time.
            return UserDefaults.standard.bool(forKey: Self.originalPurchaserKey)
        }
    }

    // MARK: Products and purchases

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: PlanID.allCases.map(\.productID))
            var map: [PlanID: Product] = [:]
            for product in loaded {
                if let plan = PlanID.allCases.first(where: { $0.productID == product.id }) { map[plan] = product }
            }
            products = map
        } catch {
            products = [:]
        }
        productsLoaded = true
    }

    func purchase(_ plan: PlanID) async {
        guard let product = products[plan], !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = String(localized: "The purchase couldn't be verified. Please try again.")
                    return
                }
                await transaction.finish()
                await refreshAccess()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshAccess()
        if !isUnlocked, errorMessage == nil {
            errorMessage = String(localized: "No previous purchases were found for this Apple Account.")
        }
    }
}

#if DEBUG
/// Debug builds can't see the App Store products (their bundle ID isn't an App Store Connect app), so they are
/// unlocked by default; switch it off in Settings → Developer to see the paywall.
enum DebugProOverride {
    static let key = "debug_pro_override"
    static var isOn: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}
#endif
