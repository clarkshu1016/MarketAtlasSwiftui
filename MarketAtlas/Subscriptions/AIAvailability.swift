import Foundation
import Observation
import StoreKit

/// Whether the AI features (chat, AI screener, voice input for chat) are offered.
///
/// Mainland China requires a licence for generative-AI services, and App Review rejected 1.0.1 over it (guideline 5,
/// "Legal"). So the AI features are switched off for the China mainland App Store. Two signals, either one is enough:
///  - the App Store storefront of the Apple Account (`Storefront.current`, "CHN"), which is what App Review looks at;
///  - the device region, for someone in mainland China using an Apple Account from another storefront.
/// Hong Kong, Macau and Taiwan are separate regions and keep the features.
///
/// Until the storefront is known the features stay hidden, so they never flash on for a China user.
@MainActor
@Observable
final class AIAvailability {
    private(set) var storefrontCountry: String?
    private(set) var isResolved = false

    var isEnabled: Bool {
        guard isResolved else { return false }
        return !Self.isMainlandChina(storefront: storefrontCountry, deviceRegion: Locale.current.region?.identifier)
    }

    /// One line for Settings → About, so "why is AI missing?" can be answered from the phone itself.
    /// Not localized on purpose: it is a diagnostic. Store = App Store country the app reads (ISO alpha-3), Device = region setting.
    var statusText: String {
        let store = isResolved ? (storefrontCountry ?? "none") : "…"
        let device = Locale.current.region?.identifier ?? "none"
        let state = !isResolved ? "checking" : (isEnabled ? "on" : "off")
        return "Store \(store) · Device \(device) · AI \(state)"
    }

    #if DEBUG
    static let debugStorefrontKey = "debug_storefront"
    #endif

    /// Re-reads the storefront (the Debug-only country picker in Settings uses this).
    func refresh() async {
        storefrontCountry = await Self.currentStorefront()
    }

    nonisolated static func isMainlandChina(storefront: String?, deviceRegion: String?) -> Bool {
        storefront?.uppercased() == "CHN" || deviceRegion?.uppercased() == "CN"
    }

    func start() async {
        storefrontCountry = await Self.currentStorefront()
        isResolved = true
        // The account can switch storefront while the app is running.
        for await storefront in Storefront.updates {
            storefrontCountry = storefront.countryCode
        }
    }

    private static func currentStorefront() async -> String? {
        #if DEBUG
        // Simulate a storefront without changing the Apple Account: `-debug_storefront CHN` or the same key in UserDefaults.
        if let forced = UserDefaults.standard.string(forKey: debugStorefrontKey), !forced.isEmpty { return forced }
        #endif
        return await Storefront.current?.countryCode
    }
}
