// ContentView.swift — MarketAtlas
import SwiftUI

struct ContentView: View {
    @State private var vm     = CompanyViewModel()
    @State private var favVM  = FavoritesViewModel()
    @State private var authVM = AuthViewModel()
    @AppStorage("app_appearance") private var appearance: String = "system"

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

            // ── Profile ──────────────────────────────────────────
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }

            // ── Settings ─────────────────────────────────────────
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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
    }
}

#Preview("ContentView") {
    ContentView()
}
