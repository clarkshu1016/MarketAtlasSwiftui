import SwiftUI

struct SettingsView: View {
    @AppStorage("app_appearance") private var appearance: String = "system"

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                    Label("Light",  systemImage: "sun.max.fill").tag("light")
                    Label("Dark",   systemImage: "moon.fill").tag("dark")
                }
                .pickerStyle(.inline)
            }

            Section("About") {
                LabeledContent("Version", value: {
                    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    #if DEBUG
                    return "\(v) (\(b)) Debug"
                    #else
                    return "\(v) (\(b))"
                    #endif
                }())
            }

            Section {
                VStack(spacing: 4) {
                    Text("MarketAtlas")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("Stock rankings & financial data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
