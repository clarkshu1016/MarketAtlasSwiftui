import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(FavoritesViewModel.self) private var favVM

    var body: some View {
        if authVM.isLoggedIn {
            profileContent
        } else {
            signInPrompt
        }
    }

    // MARK: - Profile content

    private var profileContent: some View {
        List {
            // ── Avatar + name ─────────────────────────────────────
            Section {
                HStack(spacing: 16) {
                    avatarView
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authVM.userName ?? "User")
                            .font(.title3.bold())
                        if let email = authVM.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // ── Stats ─────────────────────────────────────────────
            Section("Activity") {
                Label("\(favVM.companies.count) companies favourited", systemImage: "star.fill")
                    .foregroundStyle(.primary)
            }

            // ── Actions ───────────────────────────────────────────
            Section {
                Button(role: .destructive) {
                    favVM.companies = []
                    authVM.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        if let urlStr = authVM.userAvatar, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        let initials = authVM.userName?
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined() ?? "?"
        return Text(initials)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor)
    }

    // MARK: - Not logged in

    private var signInPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("Sign In")
                    .font(.title2.bold())
                Text("Sign in to save favourites and sync across devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            GoogleSignInCustomButton(action: { authVM.signInWithGoogle() })
                .padding(.horizontal, 40)
            Spacer()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Previews

#Preview("Profile — logged in") {
    let authVM: AuthViewModel = {
        let v = AuthViewModel()
        v.setToken("preview")
        return v
    }()
    let favVM: FavoritesViewModel = {
        let v = FavoritesViewModel()
        v.companies = Company.mockSamples
        return v
    }()
    NavigationStack { ProfileView() }
        .environment(authVM)
        .environment(favVM)
}

#Preview("Profile — signed out") {
    NavigationStack { ProfileView() }
        .environment(AuthViewModel())
        .environment(FavoritesViewModel())
}
