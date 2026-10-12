// ContentView.swift — MarketAtlas
import SwiftUI

struct ContentView: View {
    @State private var vm     = CompanyViewModel()
    @State private var favVM  = FavoritesViewModel()
    @State private var authVM = AuthViewModel()
    @AppStorage("app_appearance") private var appearance: String = "system"
    @AppStorage("onboarding_seen") private var onboardingSeen = false
    @State private var notice: String?

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    @Environment(EntitlementManager.self) private var entitlements

    var body: some View {
        switch entitlements.access {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
        case .locked:
            // First launch without access: a short tour of what Pro unlocks, then the paywall.
            if onboardingSeen {
                PaywallView()
                    .preferredColorScheme(preferredScheme)
            } else {
                OnboardingView { withAnimation { onboardingSeen = true } }
                    .preferredColorScheme(preferredScheme)
            }
        case .unlocked:
            mainTabs
        }
    }

    private var mainTabs: some View {
        TabView {
            // ── Markets ──────────────────────────────────────────
            NavigationStack {
                CompanyListView(vm: vm)
            }
            .tabItem { Label("Markets", systemImage: "chart.bar.fill") }

            // ── Heatmap ──────────────────────────────────────────
            HeatmapTabView()
                .tabItem { Label("Heatmap", systemImage: "square.grid.3x3.fill") }

            // ── Chat (center) ─────────────────────────────────────
            ChatView()
                .tabItem { Label("Chat", systemImage: "sparkles") }

            // ── Favourites ───────────────────────────────────────
            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label("Favourites", systemImage: "star.fill") }

            // ── Profile (Settings lives behind the gear in its toolbar) ──
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .adaptiveTabStyle()
        .preferredColorScheme(preferredScheme)
        .environment(favVM)
        .environment(authVM)
        .alert("Connection Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("Retry")  { Task { await vm.refresh() } }
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        // Token expired / revoked → sign out instead of leaving the app in a half-logged-in state.
        .onReceive(NotificationCenter.default.publisher(for: .apiUnauthorized)) { _ in
            guard authVM.isLoggedIn else { return }
            authVM.signOut()
            favVM.companies = []
            notice = APIError.unauthorized.errorDescription
        }
        #if DEBUG
        // Debug server switch: the session and cached data belong to the previous server.
        .onReceive(NotificationCenter.default.publisher(for: .serverEnvironmentChanged)) { _ in
            authVM.signOut()
            favVM.companies = []
            Task { await vm.refresh() }
        }
        #endif
        // Surface favourite-sync failures (the optimistic change was already rolled back).
        .onChange(of: favVM.syncError) { _, message in
            guard let message else { return }
            notice = message
            favVM.syncError = nil
        }
        .alert("Heads Up", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }
}

private extension View {
    /// iOS 18+: sidebar-adaptable tabs, so a narrow iPad window gets a sidebar instead of an overflowing top bar.
    @ViewBuilder func adaptiveTabStyle() -> some View {
        if #available(iOS 18.0, *) { tabViewStyle(.sidebarAdaptable) } else { self }
    }
}

#Preview("ContentView") {
    ContentView()
        .environment(EntitlementManager())
}
