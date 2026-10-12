import SwiftUI

/// Animated bar-chart race: the ten largest companies month by month (market cap) or year by year
/// (earnings, revenue), optionally limited to one country and/or sector.
struct MarketRaceView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case marketCap = "market_cap", earnings, revenue
        var id: String { rawValue }
        var label: String {
            switch self {
            case .marketCap: String(localized: "Market Cap")
            case .earnings:  String(localized: "Earnings")
            case .revenue:   String(localized: "Revenue")
            }
        }
        var title: String {
            switch self {
            case .marketCap: String(localized: "Top 10 by market cap")
            case .earnings:  String(localized: "Top 10 by earnings")
            case .revenue:   String(localized: "Top 10 by revenue")
            }
        }
    }

    private struct Query: Hashable {
        var metric: Metric
        var country: String?
        var sector: String?
    }

    private static let sectors = ["Technology", "Finance", "Consumer", "Industrials", "Healthcare", "Energy",
                                  "Materials", "Media & Telecom", "Real Estate", "Services", "Unclassified"]
    /// The race always runs from here to today; the slider covers the whole range.
    private static let startYear = 2000
    private static let visibleBars = 10
    private static let rowHeight: CGFloat = 42
    /// Wider windows (iPad) get taller rows so the chart fills the screen instead of floating in blank space.
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var rowHeight: CGFloat { sizeClass == .regular ? 66 : Self.rowHeight }

    let countries: [String]

    @State private var query = Query(metric: .marketCap, country: nil, sector: nil)
    @State private var showCountryPicker = false
    @State private var response: RaceResponse?
    @State private var colors: [String: Int] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Playback: `frame` is a fractional frame index. While playing it advances from `baseFrame`.
    @State private var baseFrame: Double = 0
    @State private var playStart: Date?
    @State private var speed: Double = 1

    private var frameCount: Int { response?.dates.count ?? 0 }
    private var lastFrame: Double { Double(max(frameCount - 1, 0)) }
    private var isPlaying: Bool { playStart != nil }
    private var isAnnual: Bool { response?.granularity == "year" }
    /// Monthly data: one frame per 0.25 s at 1×; annual data: one per second.
    private var framesPerSecond: Double { (isAnnual ? 1 : 4) * speed }

    private func frame(at date: Date) -> Double {
        guard let playStart else { return baseFrame }
        return min(lastFrame, baseFrame + date.timeIntervalSince(playStart) * framesPerSecond)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            // Scrollable so a short screen (or large text) never squeezes the chart or hides the footnote;
            // on a tall screen the content is still centred.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        raceContent
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Ranking Race")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) { await load() }
        .onDisappear { pause(at: frame(at: .now)) }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(countries: countries, selected: $query.country)
        }
    }

    @ViewBuilder private var raceContent: some View {
        Group {
            if let response, frameCount > 1 {
                VStack(spacing: 12) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
                        let f = frame(at: context.date)
                        RaceChart(response: response, frame: f, bars: Self.visibleBars, rowHeight: rowHeight,
                                  title: query.metric.title, annual: isAnnual, colors: colors)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .onChange(of: f >= lastFrame && isPlaying) { _, finished in
                                if finished { pause(at: lastFrame) }
                            }
                    }
                    controls
                }
                .padding(.horizontal, 16)
                .opacity(isLoading ? 0.35 : 1)

                if let note = response.note {
                    Text(DisplayName.note(note))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
            } else if response != nil {
                ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis",
                                       description: Text("No history for this combination."))
            }
        }
    }

    // MARK: Filters

    /// Three compact chips; a chip is highlighted when it narrows the race.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Metric", selection: $query.metric) {
                        ForEach(Metric.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    chip(query.metric.label, systemImage: "chart.bar.fill", active: query.metric != .marketCap)
                }

                Button { showCountryPicker = true } label: {
                    chip(query.country.map(DisplayName.country) ?? String(localized: "Country/Region"),
                         systemImage: "globe", active: query.country != nil)
                }

                Menu {
                    Picker("Sector", selection: $query.sector) {
                        Text("Any sector").tag(String?.none)
                        ForEach(Self.sectors, id: \.self) { Text(Sector.displayName($0)).tag(String?.some($0)) }
                    }
                } label: {
                    chip(query.sector.map(Sector.displayName) ?? String(localized: "Sector"),
                         systemImage: "square.grid.2x2", active: query.sector != nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chip(_ title: String, systemImage: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.system(size: 12))
            Text(title).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: 120, alignment: .leading)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .font(.system(size: 13, weight: active ? .semibold : .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(active ? Color.accentColor : .primary)
        .background(Capsule().fill(active ? Color.accentColor.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground)))
        .overlay(Capsule().strokeBorder(active ? Color.accentColor.opacity(0.8) : Color(UIColor.separator).opacity(0.4),
                                        lineWidth: active ? 1.5 : 0.5))
    }

    // MARK: Pieces

    /// Only the slider is driven by the timeline. The play button and the speed menu stay outside it:
    /// a menu inside a view that re-renders every frame is dismissed (or can't be tapped) while playing.
    private var controls: some View {
        HStack(spacing: 14) {
            let finished = !isPlaying && baseFrame >= lastFrame
            Button {
                if isPlaying { pause(at: frame(at: .now)) } else { play(from: finished ? 0 : baseFrame) }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : (finished ? "arrow.counterclockwise" : "play.fill"))
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isPlaying ? Text("Pause") : (finished ? Text("Replay") : Text("Play")))

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
                let f = frame(at: context.date)
                VStack(spacing: 2) {
                    Slider(value: Binding(
                        get: { f },
                        set: { newValue in
                            baseFrame = newValue
                            if isPlaying { playStart = .now }
                        }
                    ), in: 0...max(lastFrame, 1))
                    HStack {
                        Text(verbatim: response?.dates.first.map { String($0.prefix(4)) } ?? "")
                        Spacer()
                        Text(verbatim: response?.dates.last.map { String($0.prefix(4)) } ?? "")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Menu {
                ForEach([0.5, 1, 2, 4], id: \.self) { s in
                    Button {
                        let now = frame(at: .now)
                        baseFrame = now
                        if isPlaying { playStart = .now }
                        speed = s
                    } label: {
                        Text(verbatim: "\(s.formatted())×")
                    }
                }
            } label: {
                Text(verbatim: "\(speed.formatted())×")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(minWidth: 36)
            }
            .accessibilityLabel("Speed")
        }
    }

    // MARK: Actions

    private func play(from f: Double) {
        baseFrame = f
        playStart = .now
    }

    private func pause(at f: Double) {
        baseFrame = f
        playStart = nil
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        pause(at: 0)
        do {
            let loaded = try await APIService.shared.fetchRace(metric: query.metric.rawValue, start: Self.startYear,
                                                               country: query.country, sector: query.sector)
            response = loaded
            colors = RacePalette.assign(for: loaded, visible: Self.visibleBars)
            play(from: 0)
        } catch is CancellationError {
            return
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Country picker

private struct CountryPickerSheet: View {
    let countries: [String]
    @Binding var selected: String?
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        guard !search.isEmpty else { return countries }
        return countries.filter {
            $0.localizedCaseInsensitiveContains(search) || DisplayName.country($0).localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Button { selected = nil; dismiss() } label: {
                        row("🌍 " + String(localized: "All countries/regions"), isSelected: selected == nil)
                    }
                }
                ForEach(filtered, id: \.self) { country in
                    Button { selected = country; dismiss() } label: {
                        row(DisplayName.country(country), isSelected: selected == country)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search countries/regions")
            .navigationTitle("Country/Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ text: String, isSelected: Bool) -> some View {
        HStack {
            Text(text).foregroundStyle(.primary)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
        }
    }
}

// MARK: - The chart for one (fractional) frame

private struct RaceChart: View {
    let response: RaceResponse
    let frame: Double
    let bars: Int
    let rowHeight: CGFloat
    let title: String
    let annual: Bool
    let colors: [String: Int]

    private struct Entry: Identifiable {
        let series: RaceSeries
        let value: Double
        var id: String { series.id }
    }

    /// Market cap of every series at this fractional frame, largest first.
    private var ranked: [Entry] {
        let last = max(response.dates.count - 1, 0)
        let i0 = min(max(Int(frame.rounded(.down)), 0), last)
        let i1 = min(i0 + 1, last)
        let t = frame - Double(i0)
        return response.series
            .map { s -> Entry in
                // A missing month counts as zero, so a company grows in from nothing rather than popping in.
                let a = s.values[i0] ?? 0, b = s.values[i1] ?? 0
                return Entry(series: s, value: a * (1 - t) + b * t)
            }
            .sorted { $0.value > $1.value }
    }

    private var dateLabel: String {
        let index = min(max(Int(frame.rounded()), 0), response.dates.count - 1)
        if annual {
            // Yearly data has no months. Format the year for the language ("2018", "2018年").
            guard let year = Int(response.dates[index]),
                  let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))
            else { return response.dates[index] }
            return date.formatted(.dateTime.year())
        }
        let parts = response.dates[index].split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
        else { return response.dates[index] }
        return date.formatted(.dateTime.year().month(.abbreviated))
    }

    var body: some View {
        let all = ranked
        // Companies with no data yet (value 0) are not part of the ranking.
        let top = Array(all.filter { $0.value > 0 }.prefix(bars))
        let maxValue = max(top.first?.value ?? 1, 1)
        let rankOf = Dictionary(uniqueKeysWithValues: top.enumerated().map { ($1.id, $0) })

        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(dateLabel)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
            }

            ZStack(alignment: .topLeading) {
                // Every series stays in the tree so a bar slides in from below instead of popping in.
                ForEach(all.prefix(bars + 4)) { entry in
                    let rank = rankOf[entry.id] ?? bars + 1
                    RaceBar(series: entry.series, value: entry.value, maxValue: maxValue, rowHeight: rowHeight,
                            palette: RacePalette.pair(colors[entry.id] ?? 0))
                        .offset(y: CGFloat(rank) * rowHeight)
                        .opacity(rank < bars ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: rank)
                }
            }
            .frame(maxWidth: .infinity, minHeight: CGFloat(bars) * rowHeight, maxHeight: CGFloat(bars) * rowHeight, alignment: .topLeading)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(dateLabel): " + top.prefix(3).map { "\($0.series.name) \(Money.short($0.value))" }.joined(separator: ", ")))
    }
}

private struct RaceBar: View {
    let series: RaceSeries
    let value: Double
    let maxValue: Double
    let rowHeight: CGFloat
    let palette: (Color, Color)

    /// Fonts, logo and name column grow with the row on iPad (1 on iPhone).
    private var scale: CGFloat { max(1, rowHeight / 42) }
    private var nameWidth: CGFloat { 92 * scale }

    var body: some View {
        HStack(spacing: 6) {
            RaceLogo(urlString: series.logo_url, label: series.ticker ?? series.name, size: 24 * scale)
            Text(Company.shortName(series.name))
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: nameWidth, alignment: .leading)

            GeometryReader { geo in
                let barWidth = max(4, (geo.size.width - 64 * scale) * CGFloat(value / maxValue))
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(colors: [palette.0, palette.1], startPoint: .leading, endPoint: .trailing))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: palette.1.opacity(0.28), radius: 4, y: 2)
                        .frame(width: barWidth)
                    Text(Money.short(value))
                        .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: rowHeight - 6)
        .padding(.vertical, 3)
    }
}

/// A curated set of vivid gradients, assigned so the bars on screen at the same time never share one.
enum RacePalette {
    /// Twelve clearly different hues (blue, violet, magenta, pink, red, orange, yellow, lime, green, teal, cyan,
    /// indigo); each bar fades from a light to a deeper shade of its hue.
    private static let hues: [Double] = [0.60, 0.74, 0.84, 0.93, 0.995, 0.07, 0.14, 0.24, 0.38, 0.47, 0.53, 0.67]
    private static let pairs: [(Color, Color)] = hues.map { h in
        (Color(hue: h, saturation: 0.50, brightness: 1.0), Color(hue: (h + 0.03).truncatingRemainder(dividingBy: 1), saturation: 0.78, brightness: 0.95))
    }

    static func pair(_ index: Int) -> (Color, Color) { pairs[((index % pairs.count) + pairs.count) % pairs.count] }

    /// Walks the frames in order; a company gets the first colour not used by anyone currently in the top ten.
    static func assign(for response: RaceResponse, visible: Int) -> [String: Int] {
        var assigned: [String: Int] = [:]
        let frames = response.dates.count
        for i in 0..<frames {
            let top = response.series
                .map { ($0, $0.values[i] ?? 0) }
                .sorted { $0.1 > $1.1 }
                .prefix(visible)
                .filter { $0.1 > 0 }
                .map(\.0)
            var used = Set(top.compactMap { assigned[$0.id] })
            for s in top where assigned[s.id] == nil {
                let free = (0..<pairs.count).first { !used.contains($0) } ?? abs(s.id.hashValue) % pairs.count
                assigned[s.id] = free
                used.insert(free)
            }
        }
        return assigned
    }
}

private struct RaceLogo: View {
    let urlString: String?
    let label: String
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit().padding(2)
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private var initials: some View {
        Text(String(label.prefix(2)).uppercased())
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(Color(white: 0.35))
    }
}
