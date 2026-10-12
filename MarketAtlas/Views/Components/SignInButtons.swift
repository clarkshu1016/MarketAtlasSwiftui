import AuthenticationServices
import SwiftUI

/// Google + Apple sign-in, shared by Profile, Favourites and the "sign in required" sheet
/// so every entry point offers the same options (Apple requires Sign in with Apple
/// whenever a third-party login is offered).
struct SignInButtons: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            GoogleSignInCustomButton(action: { authVM.signInWithGoogle() })

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard
                        let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                        let tokenData = credential.identityToken,
                        let token = String(data: tokenData, encoding: .utf8)
                    else {
                        authVM.authError = String(localized: "Apple sign-in failed. Please try again.")
                        return
                    }
                    let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    authVM.signInWithApple(
                        identityToken: token,
                        fullName: fullName.isEmpty ? nil : fullName,
                        email: credential.email
                    )
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        authVM.authError = String(localized: "Apple sign-in failed. Please try again.")
                    }
                }
            }
            // A black button disappears on a dark background — invert it in dark mode.
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
        }
        .padding(.horizontal, 40)
        .alert("Sign In Failed", isPresented: Binding(
            get: { authVM.authError != nil },
            set: { if !$0 { authVM.authError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authVM.authError ?? "")
        }
    }
}

#Preview {
    SignInButtons()
        .environment(AuthViewModel())
}
