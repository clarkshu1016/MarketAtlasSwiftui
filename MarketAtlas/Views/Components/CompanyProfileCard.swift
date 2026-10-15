import SwiftUI

/// What a company does, in a few lines, plus a few facts. Shown on the company page under the tags.
/// (Prototype: the content comes from `CompanyProfile.sample`; the real version will load it from the server.)
struct CompanyProfile {
    var summary: String
    var founded: Int?
    var headquarters: String?
    var website: String?
    var sourceURL: URL
}

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

            if profile.founded != nil || profile.headquarters != nil || profile.website != nil {
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    if let f = profile.founded { fact("Founded", String(f)) }
                    if let h = profile.headquarters { fact("Headquarters", h) }
                    if let w = profile.website { fact("Website", w, link: URL.web(w)) }
                }
            }

            Button { browsing = profile.sourceURL } label: {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                    Text("Source: Wikipedia · CC BY-SA")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
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

extension CompanyProfile {
    /// Real Wikipedia text for a few companies, until the profiles come from the server.
    static func sample(slug: String?, japanese: Bool) -> CompanyProfile? {
        switch slug {
        case "nvidia":
            return japanese
            ? CompanyProfile(summary: "NVIDIA Corporation（エヌビディア・コーポレーション）は、アメリカ合衆国に本社を置く、主にGPGPU（汎用計算用GPU）やAI（人工知能）関連の半導体を開発・研究・販売する世界的企業である。",
                             founded: 1993, headquarters: "カリフォルニア州サンタクララ", website: "nvidia.com",
                             sourceURL: URL(string: "https://ja.wikipedia.org/wiki/NVIDIA")!)
            : CompanyProfile(summary: "Nvidia Corporation is an American multinational technology company headquartered in Santa Clara, California. The company develops graphics processing units (GPUs), systems on chips (SoCs), and application programming interfaces (APIs) for data science, high-performance computing, and mobile and automotive applications. Nvidia is the world's largest supplier of artificial intelligence hardware and software.",
                             founded: 1993, headquarters: "Santa Clara, US", website: "nvidia.com",
                             sourceURL: URL(string: "https://en.wikipedia.org/wiki/Nvidia")!)
        case "toyota":
            return CompanyProfile(summary: "Toyota Motor Corporation is a Japanese multinational automotive manufacturer headquartered in Toyota City, Aichi, Japan. It was founded by Kiichiro Toyoda and incorporated on August 28, 1937.",
                                  founded: 1937, headquarters: "Toyota City, Japan", website: "toyota.com",
                                  sourceURL: URL(string: "https://en.wikipedia.org/wiki/Toyota")!)
        default:
            return nil
        }
    }
}
