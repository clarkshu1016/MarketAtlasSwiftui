import StoreKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("app_appearance") private var appearance: String = "system"
    @AppStorage(VoiceLanguage.storageKey) private var voiceLanguage: String = VoiceLanguage.auto.rawValue
    @Environment(EntitlementManager.self) private var entitlements
    @State private var showManageSubscriptions = false
    #if DEBUG
    @AppStorage(DebugProOverride.key) private var proOverride: Bool = false
    #endif
    #if DEBUG
    @AppStorage(ServerEnvironment.storageKey) private var server: String = ServerEnvironment.default.rawValue
    #endif

    var body: some View {
        List {
            #if DEBUG
            Section {
                Toggle("Pro unlocked (debug)", isOn: $proOverride)
                    .onChange(of: proOverride) { _, _ in Task { await entitlements.refreshAccess() } }
                Picker("Server", selection: $server) {
                    ForEach(ServerEnvironment.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .onChange(of: server) { _, _ in
                    NotificationCenter.default.post(name: .serverEnvironmentChanged, object: nil)
                }
                LabeledContent("URL", value: ServerEnvironment.current.url.absoluteString)
                    .font(.footnote)
            } header: {
                Text("Developer")
            } footer: {
                Text("Debug builds only. Switching signs you out, because accounts live on each server separately. “Production” is the live server; “Local Mac” needs the backend running on your Mac.")
            }
            #endif

            subscriptionSection

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light",  systemImage: "sun.max.fill").tag("light")
                    Label("Dark",   systemImage: "moon.fill").tag("dark")
                }
                .pickerStyle(.inline)
            }

            Section {
                Picker("Language", selection: $voiceLanguage) {
                    ForEach(VoiceLanguage.allCases) { Text($0.label).tag($0.rawValue) }
                }
            } header: {
                Text("Voice Input")
            } footer: {
                Text("Language used when you tap the microphone in AI Chat. Automatic follows your device language.")
            }


            Section("About") {
                LabeledContent("Version", value: {
                    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    #if DEBUG
                    return "\(v) (\(b)) Debug"
                    #else
                    return "\(v) (\(b))"
                    #endif
                }())
            }

            Section {
                VStack(spacing: 4) {
                    Text("MarketAtlas")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("Stock rankings & financial data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: Subscription

    private var subscriptionSection: some View {
        Section {
            LabeledContent("Plan") { Text(planText).foregroundStyle(.secondary) }
            Button("Manage Subscription") { showManageSubscriptions = true }
            Button("Restore Purchases") { Task { await entitlements.restore() } }
        } header: {
            Text("MarketAtlas Pro")
        }
    }

    private var planText: String {
        switch entitlements.access {
        case .unlocked(.originalPurchaser):
            return String(localized: "Lifetime — thank you for buying MarketAtlas")
        case .unlocked(.lifetime):
            return String(localized: "Lifetime")
        case .unlocked(.subscription(let expires)):
            if let expires { return String(localized: "Active until \(expires.formatted(date: .abbreviated, time: .omitted))") }
            return String(localized: "Active")
        case .unlocked(.debugOverride):
            return String(localized: "Unlocked (debug)")
        case .locked, .checking:
            return String(localized: "Not subscribed")
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
