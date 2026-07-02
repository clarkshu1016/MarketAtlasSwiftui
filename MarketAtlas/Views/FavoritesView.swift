import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesViewModel.self) private var favVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        if authVM.isLoggedIn {
            favoritesList
        } else {
            notLoggedInView
        }
    }

    // MARK: - Favorites list

    private var favoritesList: some View {
        List {
            if favVM.companies.isEmpty && !favVM.isLoading {
                ContentUnavailableView(
                    "No Favourites Yet",
                    systemImage: "star",
                    description: Text("Open a company and tap ★ to save it here.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(Array(favVM.companies.enumerated()), id: \.element.id) { idx, company in
                    NavigationLink {
                        CompanyDetailView(company: company)
                    } label: {
                        CompanyRowView(company: company, rank: idx + 1, metric: .marketCap)
                    }
                    .listRowInsets(EdgeInsets(top: 3, leading: 14, bottom: 3, trailing: 14))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                    )
                    .listRowSeparator(.hidden)
                }
                .onDelete { offsets in
                    Task { await deleteFavorites(at: offsets) }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(UIColor.systemGroupedBackground))
        .refreshable {
            if let token = authVM.token { await favVM.load(token: token) }
        }
        .overlay {
            if favVM.isLoading && favVM.companies.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if let token = authVM.token, favVM.companies.isEmpty {
                await favVM.load(token: token)
            }
        }
    }

    private func deleteFavorites(at offsets: IndexSet) async {
        guard let token = authVM.token else { return }
        for idx in offsets {
            let company = favVM.companies[idx]
            await favVM.toggle(company: company, token: token)
        }
    }

    // MARK: - Not logged in

    private var notLoggedInView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "star.slash")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("Save Your Favourites")
                    .font(.title2.bold())
                Text("Sign in to save and sync your favourite companies across devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            GoogleSignInCustomButton(action: { authVM.signInWithGoogle() })
                .padding(.horizontal, 40)
            Spacer()
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Previews

#Preview("Favourites — with items") {
    let favVM: FavoritesViewModel = { let v = FavoritesViewModel(); v.companies = Company.mockSamples; return v }()
    let authVM: AuthViewModel = { let v = AuthViewModel(); v.setToken("preview"); return v }()
    NavigationStack { FavoritesView() }
        .environment(favVM)
        .environment(authVM)
}

#Preview("Favourites — empty") {
    let authVM: AuthViewModel = { let v = AuthViewModel(); v.setToken("preview"); return v }()
    NavigationStack { FavoritesView() }
        .environment(FavoritesViewModel())
        .environment(authVM)
}

#Preview("Favourites — not logged in") {
    NavigationStack {
        FavoritesView()
    }
    .environment(FavoritesViewModel())
    .environment(AuthViewModel())
}
