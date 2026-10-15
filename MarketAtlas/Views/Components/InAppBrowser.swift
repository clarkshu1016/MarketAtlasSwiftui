import SwiftUI
import SafariServices

/// Safari inside the app (SFSafariViewController): the page opens over the current screen and closes with Done,
/// instead of leaving for the Safari app. Only http and https addresses can be shown.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct BrowsingURL: Identifiable {
    let url: URL
    var id: URL { url }
}

extension View {
    /// Presents `url` in the in-app browser while it is non-nil.
    func inAppBrowser(url: Binding<URL?>) -> some View {
        sheet(item: Binding(
            get: { url.wrappedValue.map(BrowsingURL.init) },
            set: { url.wrappedValue = $0?.url }
        )) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
    }
}

extension URL {
    /// A web address from loose text ("nvidia.com", "www.nvidia.com/en"), or nil when it is not http(s).
    static func web(_ text: String?) -> URL? {
        guard var s = text?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else { return nil }
        return url
    }
}
