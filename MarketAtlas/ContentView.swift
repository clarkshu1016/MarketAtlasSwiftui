// ContentView.swift — MarketAtlas
import SwiftUI

struct ContentView: View {
    @State private var vm     = CompanyViewModel()
    @State private var favVM  = FavoritesViewModel()
    @State private var authVM = AuthViewModel()
    @AppStorage("app_appearance") private var appearance: String = "system"
    @State private var notice: String?

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView {
            // ── Markets ──────────────────────────────────────────
            NavigationStack {
                CompanyListView(vm: vm)
            }
            .tabItem { Label("Markets", systemImage: "chart.bar.fill") }

            // ── Favourites ───────────────────────────────────────
            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label("Favourites", systemImage: "star.fill") }

            // ── Chat (center) ─────────────────────────────────────
            ChatView()
                .tabItem { Label("Chat", systemImage: "sparkles") }

            // ── Heatmap ──────────────────────────────────────────
            HeatmapTabView()
                .tabItem { Label("Heatmap", systemImage: "square.grid.3x3.fill") }

            // ── Profile (Settings lives behind the gear in its toolbar) ──
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
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

#Preview("ContentView") {
    ContentView()
}
