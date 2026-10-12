import SwiftUI
import WidgetKit

// MARK: - Timeline

struct TopCompaniesEntry: TimelineEntry {
    let date: Date
    let companies: [TopCompany]
    let logos: [String: Data]
    let isStale: Bool
}

struct TopCompaniesProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopCompaniesEntry {
        TopCompaniesEntry(date: .now, companies: TopCompany.samples, logos: [:], isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TopCompaniesEntry) -> Void) {
        // The gallery preview must be instant; use sample data there.
        if context.isPreview { completion(placeholder(in: context)); return }
        Task {
            let loaded = await TopCompaniesLoader.load()
            completion(loaded.map { TopCompaniesEntry(date: .now, companies: $0.companies, logos: $0.logos, isStale: $0.isStale) }
                       ?? placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopCompaniesEntry>) -> Void) {
        Task {
            if let loaded = await TopCompaniesLoader.load() {
                let entry = TopCompaniesEntry(date: .now, companies: loaded.companies, logos: loaded.logos, isStale: loaded.isStale)
                // Prices move during the day; the ranking itself changes rarely. Retry sooner after a failure.
                let next = Calendar.current.date(byAdding: .minute, value: loaded.isStale ? 15 : 60, to: .now) ?? .now
                completion(Timeline(entries: [entry], policy: .after(next)))
            } else {
                let entry = TopCompaniesEntry(date: .now, companies: [], logos: [:], isStale: true)
                let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
                completion(Timeline(entries: [entry], policy: .after(next)))
            }
        }
    }
}

// MARK: - Widget

struct TopCompaniesWidget: Widget {
    let kind = "TopCompaniesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopCompaniesProvider()) { entry in
            TopCompaniesView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.09, green: 0.11, blue: 0.20), Color(red: 0.03, green: 0.04, blue: 0.09)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Top Companies")
        .description("The world's largest companies by market cap, with today's move.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// MARK: - Views

private enum Palette {
    static let up   = Color(red: 0.36, green: 0.86, blue: 0.52)
    static let down = Color(red: 1.00, green: 0.45, blue: 0.45)
    static func change(_ value: Double?) -> Color {
        guard let value else { return .white.opacity(0.6) }
        return value >= 0 ? up : down
    }
}

struct TopCompaniesView: View {
    let entry: TopCompaniesEntry
    @Environment(\.widgetFamily) private var family

    private var rowCount: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 5
        case .systemLarge: 10
        default: 3
        }
    }

    var body: some View {
        if entry.companies.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark").font(.title3)
                Text("Can't load data").font(.footnote.weight(.semibold))
                Text("Will retry shortly").font(.caption2).opacity(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if family == .accessoryRectangular {
            lockScreen
        } else {
            home
        }
    }

    // Home screen ------------------------------------------------------------------------------

    private var home: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 16
            let spacing: CGFloat = 4
            // Fit the rows to the space the widget really has (it differs per device and family).
            let rowHeight = (geo.size.height - headerHeight - spacing * CGFloat(rowCount)) / CGFloat(rowCount)

            VStack(alignment: .leading, spacing: spacing) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 11, weight: .bold))
                    Text(family == .systemSmall ? "Top by value" : "Top companies · market cap")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if entry.isStale {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 10)).opacity(0.7)
                    }
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(height: headerHeight)

                ForEach(entry.companies.prefix(rowCount)) { company in
                    Row(company: company, logo: entry.logos[company.ticker ?? ""],
                        compact: family == .systemSmall, height: rowHeight)
                        .frame(height: rowHeight)
                }
            }
            .foregroundStyle(.white)
        }
    }

    // Lock screen --------------------------------------------------------------------------------

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(entry.companies.prefix(3)) { c in
                HStack(spacing: 4) {
                    Text("\(c.rank)").font(.system(size: 11, weight: .bold)).frame(width: 12, alignment: .leading)
                    Text(c.shortLabel).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(c.capText).font(.system(size: 11)).lineLimit(1)
                    Text(c.changeText).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
            }
        }
    }
}

private struct Row: View {
    let company: TopCompany
    let logo: Data?
    let compact: Bool
    let height: CGFloat

    private var logoSize: CGFloat { min(26, max(16, height - 3)) }
    /// Two lines of text (name + ticker) only fit when the row is tall enough.
    private var twoLines: Bool { height >= 27 }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            if !compact {
                Text("\(company.rank)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 14, alignment: .center)
            }

            LogoView(data: logo, label: company.shortLabel, size: compact ? min(logoSize, 22) : logoSize)

            if compact {
                Text(company.shortLabel)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text(company.changeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.change(company.change_24h))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if twoLines {
                VStack(alignment: .leading, spacing: 0) {
                    Text(company.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(company.shortLabel).font(.system(size: 10, weight: .medium)).opacity(0.55)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(company.capText).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1)
                    Text(company.changeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.change(company.change_24h))
                }
            } else {
                Text(company.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Text(company.capText).font(.system(size: 12, weight: .bold, design: .rounded)).lineLimit(1)
                Text(company.changeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.change(company.change_24h))
                    .frame(width: 52, alignment: .trailing)
                    .lineLimit(1)
            }
        }
    }
}

private struct LogoView: View {
    let data: Data?
    let label: String
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(size * 0.12)
            } else {
                Text(String(label.prefix(2)))
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .background(data == nil ? Color.white.opacity(0.14) : Color.white, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}
