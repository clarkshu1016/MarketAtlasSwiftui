import SwiftUI

/// Google-branded Sign-In button: pill shape, white/neutral background,
/// Google G logo left, dark text — per Google branding guidelines.
struct GoogleSignInCustomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleGLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.122, green: 0.122, blue: 0.122)) // #1F1F1F
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 0.949, green: 0.949, blue: 0.949)) // #F2F2F2
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(red: 0.455, green: 0.467, blue: 0.459), lineWidth: 1)) // #747775
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 24) {
        GoogleSignInCustomButton(action: {})
            .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}
