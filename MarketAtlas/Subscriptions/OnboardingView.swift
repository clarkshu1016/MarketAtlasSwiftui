import SwiftUI

/// Three short pages shown once, before the paywall, so people see what they are about to unlock.
/// Illustrations are drawn in SwiftUI (no image assets), so they follow dark mode, language and screen size.
struct OnboardingView: View {
    let onFinish: () -> Void
    @Environment(AIAvailability.self) private var ai
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    private let allPages: [Page] = [
        Page(id: 0, title: "The whole market at a glance",
             message: "Every country and sector on one screen. Tile size is market cap, colour is the change."),
        Page(id: 1, title: "Watch the giants race",
             message: "See how the world's biggest companies overtook each other, from 2000 to today."),
        Page(id: 2, title: "Ask anything",
             message: "Rankings, comparisons and revenue history in plain language. Type or speak."),
    ]

    /// The "Ask anything" page is left out where the AI features are not offered.
    private var pages: [Page] { ai.isEnabled ? allPages : allPages.filter { $0.id != 2 } }

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { onFinish() }
                    .font(.subheadline.weight(.semibold))
                    .opacity(isLast ? 0 : 1)
                    .disabled(isLast)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(pages) { p in
                    pageView(p).tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if isLast { onFinish() } else { withAnimation { page += 1 } }
            } label: {
                Text(isLast ? "Continue" : "Next")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Group {
                switch p.id {
                case 0:  HeatmapIllustration()
                case 1:  RaceIllustration()
                default: ChatIllustration()
                }
            }
            .frame(maxWidth: 360)
            .frame(height: 300)
            .padding(.horizontal, 24)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(p.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(p.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 24) // room for the page dots
    }
}

// MARK: - Illustrations

private struct IllustrationCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// A tiny treemap: tile size = market cap, colour = change.
private struct HeatmapIllustration: View {
    private struct Tile: Identifiable {
        let id = UUID()
        let label: String
        let change: String
        let color: Color
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat   // fractions of the card
    }

    private let tiles: [Tile] = [
        Tile(label: "USA", change: "+12.0%", color: Color(red: 0.16, green: 0.62, blue: 0.38), x: 0, y: 0, w: 1, h: 0.46),
        Tile(label: "CN", change: "−7.7%", color: Color(red: 0.78, green: 0.30, blue: 0.34), x: 0, y: 0.46, w: 0.34, h: 0.54),
        Tile(label: "JP", change: "+17.5%", color: Color(red: 0.12, green: 0.70, blue: 0.42), x: 0.34, y: 0.46, w: 0.26, h: 0.54),
        Tile(label: "UK", change: "+7.8%", color: Color(red: 0.30, green: 0.58, blue: 0.45), x: 0.60, y: 0.46, w: 0.20, h: 0.27),
        Tile(label: "IN", change: "−15%", color: Color(red: 0.82, green: 0.28, blue: 0.30), x: 0.80, y: 0.46, w: 0.20, h: 0.27),
        Tile(label: "TW", change: "+63%", color: Color(red: 0.10, green: 0.74, blue: 0.40), x: 0.60, y: 0.73, w: 0.20, h: 0.27),
        Tile(label: "FR", change: "−14%", color: Color(red: 0.70, green: 0.34, blue: 0.38), x: 0.80, y: 0.73, w: 0.20, h: 0.27),
    ]

    var body: some View {
        IllustrationCard {
            GeometryReader { geo in
                let gap: CGFloat = 3
                ZStack(alignment: .topLeading) {
                    ForEach(tiles) { t in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(t.color)
                            .overlay(
                                VStack(spacing: 1) {
                                    Text(t.label).font(.system(size: t.w > 0.5 ? 20 : 13, weight: .bold))
                                    Text(t.change).font(.system(size: t.w > 0.5 ? 14 : 10, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            )
                            .frame(width: t.w * geo.size.width - gap, height: t.h * geo.size.height - gap)
                            .offset(x: t.x * geo.size.width, y: t.y * geo.size.height)
                    }
                }
            }
        }
    }
}

/// Bars that keep overtaking each other, like the Ranking Race.
private struct RaceIllustration: View {
    private struct Row: Identifiable {
        let id: String
        let color: [Color]
    }

    private let rows: [Row] = [
        Row(id: "Apple", color: [Color(red: 0.72, green: 0.48, blue: 1.0), Color(red: 0.64, green: 0.22, blue: 0.95)]),
        Row(id: "Microsoft", color: [Color(red: 0.48, green: 0.67, blue: 1.0), Color(red: 0.22, green: 0.40, blue: 0.95)]),
        Row(id: "Aramco", color: [Color(red: 1.0, green: 0.50, blue: 0.46), Color(red: 0.95, green: 0.32, blue: 0.22)]),
        Row(id: "Alphabet", color: [Color(red: 0.98, green: 0.90, blue: 0.40), Color(red: 0.92, green: 0.92, blue: 0.20)]),
        Row(id: "Amazon", color: [Color(red: 1.0, green: 0.50, blue: 0.70), Color(red: 0.95, green: 0.20, blue: 0.40)]),
    ]

    /// Two orderings and widths that the bars move between.
    private let frames: [[String: CGFloat]] = [
        ["Apple": 1.0, "Microsoft": 0.84, "Aramco": 0.70, "Alphabet": 0.60, "Amazon": 0.46],
        ["Microsoft": 1.0, "Apple": 0.92, "Alphabet": 0.74, "Amazon": 0.66, "Aramco": 0.52],
        ["Alphabet": 1.0, "Apple": 0.96, "Amazon": 0.84, "Microsoft": 0.78, "Aramco": 0.58],
    ]
    @State private var frameIndex = 0

    private var order: [String] {
        frames[frameIndex].sorted { $0.value > $1.value }.map(\.key)
    }

    var body: some View {
        IllustrationCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top 10 by market cap")
                    .font(.caption).foregroundStyle(.secondary)
                GeometryReader { geo in
                    let rowH = geo.size.height / CGFloat(rows.count)
                    ZStack(alignment: .topLeading) {
                        ForEach(rows) { r in
                            let rank = order.firstIndex(of: r.id) ?? 0
                            let w = frames[frameIndex][r.id] ?? 0.5
                            HStack(spacing: 8) {
                                Text(r.id)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 66, alignment: .leading)
                                    .lineLimit(1)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(LinearGradient(colors: r.color, startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, (geo.size.width - 74) * w))
                                Spacer(minLength: 0)
                            }
                            .frame(height: rowH - 8)
                            .offset(y: CGFloat(rank) * rowH)
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 0.9)) { frameIndex = (frameIndex + 1) % frames.count }
            }
        }
    }
}

/// A question and a short answer.
private struct ChatIllustration: View {
    var body: some View {
        IllustrationCard {
            VStack(spacing: 12) {
                HStack {
                    Spacer(minLength: 40)
                    Text("Top 10 by market cap")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(["NVIDIA", "Apple", "Alphabet", "Microsoft"].enumerated()), id: \.offset) { i, name in
                        HStack {
                            Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 18)
                            Text(name).font(.subheadline.weight(.semibold))
                            Spacer()
                            RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.25))
                                .frame(width: CGFloat(110 - i * 16), height: 8)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Text("Message MarketAtlas AI")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "mic.fill").foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color(UIColor.tertiarySystemGroupedBackground), in: Capsule())
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environment(AIAvailability())
}
