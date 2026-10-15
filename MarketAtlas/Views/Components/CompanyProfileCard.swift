import SwiftUI

/// What the company does, in a few lines, with its website and where the text came from.
/// Shown on the company page under the price chart; `CompanyProfileSection` loads it and hides it when there is none.
struct CompanyProfileCard: View {
    let profile: CompanyProfile
    @State private var expanded = false
    @State private var browsing: URL?

    private var isLong: Bool { profile.summary.count > 170 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            Text(profile.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            if isLong {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "Read more")
                        .font(.subheadline.weight(.semibold))
                }
            }

            if let site = profile.websiteDisplay {
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    fact("Website", site, link: profile.websiteURL)
                }
            }

            if let source = profile.sourceURL {
            Button { browsing = source } label: {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                    Text("Source: Wikipedia · CC BY-SA")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .inAppBrowser(url: $browsing)
    }

    private func fact(_ label: LocalizedStringKey, _ value: String, link: URL? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let link {
                Button { browsing = link } label: {
                    Text(value)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            } else {
                Text(value)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Loads the profile for a company in the app's language and shows the card, or nothing when there is none
/// (a company without a profile, offline, or any error: the page simply has no About card).
struct CompanyProfileSection: View {
    let slug: String?
    @State private var profile: CompanyProfile?

    var body: some View {
        VStack(spacing: 0) {
            // The task needs a view to hang on while there is no card (a Group with nothing in it never runs it).
            Color.clear.frame(height: 0)
                .task(id: slug) {
                    profile = nil
                    guard let slug else { return }
                    profile = try? await APIService.shared.fetchProfile(slug: slug, language: CompanyProfile.serverLanguage)
                }
            if let profile {
                CompanyProfileCard(profile: profile)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }
}
