import Foundation
import GoogleSignIn
import Observation
import UIKit

@Observable
final class AuthViewModel {
    private(set) var token: String?   = UserDefaults.standard.string(forKey: "jwt_token")
    private(set) var userName: String? = UserDefaults.standard.string(forKey: "user_name")
    private(set) var userEmail: String? = UserDefaults.standard.string(forKey: "user_email")
    private(set) var userAvatar: String? = UserDefaults.standard.string(forKey: "user_avatar")

    var isLoggedIn: Bool { token != nil }

    /// Set when a sign-in attempt fails (not when the user cancels); shown by `SignInButtons`.
    var authError: String?

    // MARK: - Sign in

    @MainActor
    func signInWithGoogle() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.keyWindow?.rootViewController
        else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            if let error {
                // The user backing out of the Google sheet is not an error worth reporting.
                if (error as NSError).code != GIDSignInError.canceled.rawValue {
                    self?.authError = String(localized: "Google sign-in failed. Please try again.")
                }
                return
            }
            guard let result, let idToken = result.user.idToken?.tokenString else {
                self?.authError = String(localized: "Google sign-in failed. Please try again.")
                return
            }
            let avatarURL = result.user.profile?.imageURL(withDimension: 96)?.absoluteString
            Task { await self?.exchangeWithBackend(idToken: idToken, avatarURL: avatarURL) }
        }
    }

    private func exchangeWithBackend(idToken: String, avatarURL: String?) async {
        var req = URLRequest(url: APIService.baseURL.appendingPathComponent("auth/google/native"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["id_token": idToken])

        guard let session = await exchange(req) else { return }
        await MainActor.run {
            persist(token: session.token, name: session.name, email: session.email, avatar: avatarURL)
        }
    }

    /// Posts the sign-in request and extracts the session. Reports failures via `authError`.
    private func exchange(_ request: URLRequest) async -> (token: String, name: String?, email: String?)? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true,
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let token = json["token"] as? String
            else { throw APIError.decoding }
            let user = json["user"] as? [String: Any]
            return (token, user?["name"] as? String, user?["email"] as? String)
        } catch is CancellationError {
            return nil
        } catch {
            await MainActor.run { authError = String(localized: "Sign-in failed. Check your connection and try again.") }
            return nil
        }
    }

    // MARK: - Sign in with Apple

    @MainActor
    func signInWithApple(identityToken: String, fullName: String?, email: String?) {
        Task { await exchangeAppleWithBackend(identityToken: identityToken, fullName: fullName, email: email) }
    }

    private func exchangeAppleWithBackend(identityToken: String, fullName: String?, email: String?) async {
        var req = URLRequest(url: APIService.baseURL.appendingPathComponent("auth/apple/native"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["id_token": identityToken]
        if let fullName, !fullName.isEmpty { body["full_name"] = fullName }
        if let email { body["email"] = email }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let session = await exchange(req) else { return }
        await MainActor.run {
            persist(token: session.token, name: session.name, email: session.email, avatar: nil)
        }
    }

    // MARK: - Delete account

    func deleteAccount() async throws {
        guard let token else { return }
        try await APIService.shared.deleteAccount(token: token)
        await MainActor.run { signOut() }
    }

    // MARK: - Sign out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        token     = nil
        userName  = nil
        userEmail = nil
        userAvatar = nil
        ["jwt_token", "user_name", "user_email", "user_avatar"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    // MARK: - Helpers

    func setToken(_ token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: "jwt_token")
    }

    private func persist(token: String, name: String?, email: String?, avatar: String?) {
        self.token      = token
        self.userName   = name
        self.userEmail  = email
        self.userAvatar = avatar
        UserDefaults.standard.set(token,  forKey: "jwt_token")
        UserDefaults.standard.set(name,   forKey: "user_name")
        UserDefaults.standard.set(email,  forKey: "user_email")
        UserDefaults.standard.set(avatar, forKey: "user_avatar")
    }
}
