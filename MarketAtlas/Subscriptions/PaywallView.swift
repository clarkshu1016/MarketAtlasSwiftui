import StoreKit
import SwiftUI

/// Full-screen gate shown until the user has a subscription or the lifetime unlock.
struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlements
    @State private var selected: PlanID = .yearly
    @State private var showError = false

    private static let termsURL = URL(string: "https://marketatlas.appdevgpt.com/terms")!
    private static let privacyURL = URL(string: "https://marketatlas.appdevgpt.com/privacy")!

    /// What one plan looks like on screen.
    private struct Option: Identifiable {
        let plan: PlanID
        let price: String
        let perMonth: String?
        let trial: String?
        var id: PlanID { plan }
    }

    private var options: [Option] {
        PlanID.allCases.map { plan in
            if let product = entitlements.products[plan] {
                let perMonth = plan.months.flatMap { $0 > 1 ? (product.price / Decimal($0)).formatted(product.priceFormatStyle) : nil }
                return Option(plan: plan, price: product.displayPrice, perMonth: perMonth, trial: Self.trialText(for: product))
            }
            #if DEBUG
            return Self.placeholder(plan)   // so the layout can be reviewed without App Store products
            #else
            return Option(plan: plan, price: "—", perMonth: nil, trial: nil)
            #endif
        }
    }

    private var pricesAvailable: Bool {
        #if DEBUG
        true
        #else
        !entitlements.products.isEmpty
        #endif
    }

    private static func trialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let days: Int
        switch offer.period.unit {
        case .day:  days = offer.period.value
        case .week: days = offer.period.value * 7
        default:    return nil
        }
        return String(localized: "\(days)-day free trial")
    }

    #if DEBUG
    private static func placeholder(_ plan: PlanID) -> Option {
        switch plan {
        case .monthly:   Option(plan: plan, price: "$6.99", perMonth: nil, trial: String(localized: "\(7)-day free trial"))
        case .quarterly: Option(plan: plan, price: "$17.99", perMonth: "$6.00", trial: String(localized: "\(7)-day free trial"))
        case .yearly:    Option(plan: plan, price: "$49.99", perMonth: "$4.17", trial: String(localized: "\(7)-day free trial"))
        case .lifetime:  Option(plan: plan, price: "$199.99", perMonth: nil, trial: nil)
        }
    }
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                features
                plans
                purchaseButton
                fineprint
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(UIColor.systemGroupedBackground))
        .task { if !entitlements.productsLoaded { await entitlements.loadProducts() } }
        .onChange(of: entitlements.errorMessage) { _, message in showError = message != nil }
        .alert("Heads Up", isPresented: $showError) {
            Button("OK", role: .cancel) { entitlements.errorMessage = nil }
        } message: {
            Text(entitlements.errorMessage ?? "")
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(LinearGradient(colors: [Color(red: 0.20, green: 0.50, blue: 1.0), Color(red: 0.45, green: 0.30, blue: 0.95)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("MarketAtlas Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("The world's biggest companies, ranked and explained.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("globe.europe.africa.fill", "11,000+ companies in 81 markets")
            feature("square.grid.3x3.fill", "Heatmaps by country/region and sector")
            feature("flag.checkered", "Ranking Race and Time Machine")
            feature("sparkles", "AI chat and AI screener")
            feature("rectangle.on.rectangle", "Home Screen and Lock Screen widgets")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text).font(.subheadline)
        }
    }

    private var plans: some View {
        let all = options
        return VStack(spacing: 10) {
            ForEach([PlanID.yearly, .quarterly, .monthly], id: \.self) { plan in
                if let option = all.first(where: { $0.plan == plan }) { card(option) }
            }
            if let lifetime = all.first(where: { $0.plan == .lifetime }) {
                card(lifetime)
            }
        }
    }

    private func card(_ option: Option) -> some View {
        let isSelected = selected == option.plan
        return Button { selected = option.plan } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.plan.title).font(.system(size: 16, weight: .semibold))
                        if option.plan == .yearly {
                            Text("Best value")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    if let trial = option.trial {
                        Text(trial).font(.caption).foregroundStyle(Color.accentColor)
                    } else if option.plan == .lifetime {
                        Text("Pay once, keep it forever").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(option.price).font(.system(size: 16, weight: .bold, design: .rounded))
                    if let perMonth = option.perMonth {
                        Text("\(perMonth) / month").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedOption: Option? { options.first { $0.plan == selected } }

    private var buttonTitle: String {
        guard let option = selectedOption else { return "" }
        if option.plan == .lifetime { return String(localized: "Buy Lifetime Access") }
        return option.trial != nil ? String(localized: "Start Free Trial") : String(localized: "Subscribe")
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await entitlements.purchase(selected) }
            } label: {
                Group {
                    if entitlements.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonTitle).font(.system(size: 17, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(entitlements.isPurchasing || entitlements.products[selected] == nil)

            if entitlements.productsLoaded, entitlements.products.isEmpty {
                Text("Prices couldn't be loaded. Check your connection and try again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await entitlements.loadProducts() } }
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var terms: String {
        guard let option = selectedOption else { return "" }
        if option.plan == .lifetime {
            return String(localized: "One-time purchase of \(option.price). No subscription, no renewal.")
        }
        let period = option.plan.periodText
        if let trial = option.trial {
            return String(localized: "\(trial), then \(option.price) / \(period). The subscription renews automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel any time in Settings > Apple Account > Subscriptions.")
        }
        return String(localized: "\(option.price) / \(period). The subscription renews automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel any time in Settings > Apple Account > Subscriptions.")
    }

    private var fineprint: some View {
        VStack(spacing: 12) {
            Text(terms)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Restore Purchases") { Task { await entitlements.restore() } }
                Link("Terms of Use", destination: Self.termsURL)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.caption.weight(.semibold))

            #if DEBUG
            Button("Unlock for testing") {
                UserDefaults.standard.set(true, forKey: DebugProOverride.key)
                Task { await entitlements.refreshAccess() }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            #endif
        }
    }
}
