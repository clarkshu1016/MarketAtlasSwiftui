import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sharing as an image
//
// Every shareable screen renders a fixed-size, dark, branded "card" with `ImageRenderer` and offers it
// through the system share sheet. Cards are self-contained (plain values in, no environment or async
// images), because `ImageRenderer` neither waits for `AsyncImage` nor sees the view hierarchy.

struct ShareableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shared in
            guard let data = shared.image.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
    }
}

enum ShareCard {
    /// Card width in points; rendered at 3× this is 1170 px — the width of a modern iPhone screenshot.
    static let width: CGFloat = 390
    static var message: String { String(localized: "MarketAtlas — rank and explore the world's biggest companies. https://apps.apple.com/app/id6784918078") }
}

private struct ShareCardModifier<Card: View>: ViewModifier {
    let title: String
    /// Identifies the data the card shows. `nil` means there is nothing to share yet.
    let key: String?
    let card: () -> Card

    @State private var rendered: ShareableImage?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let rendered {
                        ShareLink(item: rendered,
                                  message: Text(ShareCard.message),
                                  preview: SharePreview(title, image: Image(uiImage: rendered.image))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onChange(of: key, initial: true) { _, newKey in render(for: newKey) }
    }

    @MainActor
    private func render(for key: String?) {
        guard key != nil else { rendered = nil; return }
        let renderer = ImageRenderer(content: card())
        renderer.scale = 3
        rendered = renderer.uiImage.map(ShareableImage.init)
    }
}

extension View {
    /// Adds a Share button to the navigation bar that shares `card` as an image.
    /// `key` must change whenever the data behind the card changes; pass `nil` while there is no data.
    func shareCard<Card: View>(title: String, key: String?, @ViewBuilder card: @escaping () -> Card) -> some View {
        modifier(ShareCardModifier(title: title, key: key, card: card))
    }
}

// MARK: - Frame

/// The branded frame around every card: title, content, and a MarketAtlas footer.
struct ShareCardFrame<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
            }

            content

            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("MarketAtlas")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text(Date.now.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(20)
        .frame(width: ShareCard.width, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.19), Color(red: 0.03, green: 0.04, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom)
        )
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Shared pieces

enum ShareColors {
    static let up   = Color(red: 0.36, green: 0.86, blue: 0.52)
    static let down = Color(red: 1.00, green: 0.45, blue: 0.45)
    static func change(_ value: Double?) -> Color {
        guard let value else { return .white.opacity(0.6) }
        return value >= 0 ? up : down
    }
}

enum SharePeriod {
    /// Server period codes → a readable phrase.
    static func phrase(_ raw: String) -> String {
        switch raw {
        case "ytd": String(localized: "Since January 1")
        case "1y":  String(localized: "Past year")
        case "3y":  String(localized: "Past 3 years")
        case "5y":  String(localized: "Past 5 years")
        case "10y": String(localized: "Past 10 years")
        case "ath": String(localized: "Distance from all-time high")
        default:    raw.uppercased()
        }
    }
}

/// One ranked line: rank · name + detail · value (+ secondary value).
private struct ShareRankRow: View {
    let rank: Int
    let name: String
    let detail: String
    let value: String
    var valueColor: Color = .white
    var secondary: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(rank)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                if let secondary {
                    Text(secondary).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 9)
    }
}

private struct ShareRankList<Row: View>: View {
    let count: Int
    @ViewBuilder let row: (Int) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                row(i)
                if i < count - 1 { Divider().overlay(Color.white.opacity(0.12)) }
            }
        }
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Heatmap cards

struct CountryHeatmapShareCard: View {
    let response: CountryHeatmapResponse

    var body: some View {
        ShareCardFrame(
            title: String(localized: "World Market Heatmap"),
            subtitle: String(localized: "\(Money.short(response.world_market_cap)) world market cap · \(SharePeriod.phrase(response.period))")
        ) {
            VStack(spacing: 8) {
                TreemapView(weights: response.items.map(\.market_cap)) { i, size in
                    let item = response.items[i]
                    HeatTile(title: item.name, flag: item.flag, change: item.change_pct,
                             marketCap: item.market_cap, size: size)
                }
                .frame(width: ShareCard.width - 40, height: 400)
                HeatLegend()
            }
        }
    }
}

struct SectorHeatmapShareCard: View {
    let response: SectorHeatmapResponse

    var body: some View {
        ShareCardFrame(
            title: String(localized: "Market Heatmap by Sector"),
            subtitle: String(localized: "\(Money.short(response.total_market_cap)) total market cap · \(SharePeriod.phrase(response.period))")
        ) {
            VStack(spacing: 8) {
                TreemapView(weights: response.items.map(\.market_cap)) { i, size in
                    let item = response.items[i]
                    HeatTile(title: item.name, flag: item.icon, change: item.change_pct,
                             marketCap: item.market_cap, size: size)
                }
                .frame(width: ShareCard.width - 40, height: 400)
                HeatLegend()
            }
        }
    }
}

struct CompanyHeatmapShareCard: View {
    let countryName: String
    let response: CompanyHeatmapResponse
    /// Small tiles cannot hold a label (logos don't render into an image), so keep the biggest ones.
    var limit = 40

    private var items: [CompanyHeatItem] { Array(response.items.prefix(limit)) }

    var body: some View {
        ShareCardFrame(
            title: String(localized: "\(countryName) — Largest Companies"),
            subtitle: String(localized: "Top \(items.count) of \(Money.short(response.country_market_cap)) total · \(SharePeriod.phrase(response.period))")
        ) {
            VStack(spacing: 8) {
                TreemapView(weights: items.map(\.market_cap)) { i, size in
                    let item = items[i]
                    HeatTile(title: item.company.tileName, code: item.company.readableTicker, flag: nil,
                             change: item.change_pct, marketCap: item.market_cap, size: size)
                }
                .frame(width: ShareCard.width - 40, height: 400)
                HeatLegend()
            }
        }
    }
}

// MARK: - Performance card

struct PerformanceShareCard: View {
    let response: PerformanceResponse
    var limit = 10

    private var isPeak: Bool { response.period == "ath" }
    /// Best-first or worst-first, read from the data so the card always matches what is on screen.
    private var worstFirst: Bool {
        guard let first = response.items.first, let last = response.items.last else { return false }
        return first.change_pct < last.change_pct
    }
    private var title: String {
        if isPeak { return worstFirst ? String(localized: "Furthest Below Their Peak") : String(localized: "Closest to Their Peak") }
        return worstFirst ? String(localized: "Biggest Losers") : String(localized: "Top Performers")
    }
    private var items: [PerformanceItem] { Array(response.items.prefix(limit)) }

    var body: some View {
        ShareCardFrame(title: title, subtitle: String(localized: "\(SharePeriod.phrase(response.period)) · market-cap change")) {
            ShareRankList(count: items.count) { i in
                let item = items[i]
                ShareRankRow(rank: i + 1, name: item.company.name, detail: item.detailText(isPeak: isPeak),
                             value: item.changeText, valueColor: ShareColors.change(item.change_pct))
            }
        }
    }
}

// MARK: - Time machine card

struct TimeMachineShareCard: View {
    let response: TimeMachineResponse
    var limit = 10

    private var items: [TimeMachineItem] { Array(response.items.prefix(limit)) }

    var body: some View {
        ShareCardFrame(
            title: String(localized: "Biggest in \(Money.monthYear(fromISO: response.date))"),
            subtitle: String(localized: "The largest companies by market cap — and where they stand today")
        ) {
            ShareRankList(count: items.count) { i in
                let item = items[i]
                ShareRankRow(rank: item.rank_then, name: item.company.name, detail: Money.short(item.value_then),
                             value: item.multipleText, valueColor: ShareColors.change(item.multiple.map { ($0 - 1) * 100 }),
                             secondary: item.todayText)
            }
        }
    }
}

// MARK: - Company card

struct CompanyShareCard: View {
    let company: Company

    /// Fundamentals worth showing on a card, in priority order (the first six that have data).
    private static let cardMetrics: [MetricType] = [
        .earnings, .revenue, .peRatio, .operatingMargin, .dividendYield, .employees, .priceToSales, .netCash,
    ]

    private var metrics: [(label: String, value: String)] {
        Self.cardMetrics
            .compactMap { m in
                let v = m.display(from: company)
                return v == "—" ? nil : (m.label, v)
            }
            .prefix(6)
            .map { $0 }
    }

    private var priceText: String {
        company.price_display ?? company.price.map { String(format: "$%.2f", $0) } ?? "—"
    }

    var body: some View {
        ShareCardFrame(title: company.name,
                       subtitle: [company.ticker, company.country].compactMap { $0 }.joined(separator: " · ")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(priceText).font(.system(size: 32, weight: .bold, design: .rounded))
                    if let change = company.change_24h {
                        Text(HeatColor.text(change))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ShareColors.change(change))
                    }
                }

                HStack(spacing: 10) {
                    stat(String(localized: "Market Cap"), company.market_cap_display ?? "—")
                    stat(String(localized: "World Rank"), company.market_cap_rank.map { "#\($0)" } ?? "—")
                }

                if !metrics.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(metrics, id: \.label) { m in stat(m.label, m.value, compact: true) }
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: compact ? 16 : 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
