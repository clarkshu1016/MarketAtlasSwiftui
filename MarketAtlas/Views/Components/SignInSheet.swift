import SwiftUI

/// Bottom sheet shown when a signed-out user tries something that needs an account
/// (e.g. starring a company). Offers the same sign-in options as the Profile tab.
struct SignInSheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Sign In Required")
                    .font(.title3.bold())
                Text("Sign in to save favourites across your devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SignInButtons()

            Button("Not Now") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 28)
        .padding(.horizontal)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .onChange(of: authVM.isLoggedIn) { _, loggedIn in
            if loggedIn { dismiss() }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { SignInSheet() }
        .environment(AuthViewModel())
}
