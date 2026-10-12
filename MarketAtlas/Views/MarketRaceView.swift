import SwiftUI

/// Animated bar-chart race: the ten largest companies by market cap, month by month since a chosen year.
struct MarketRaceView: View {
    /// The race always runs from here to today; the slider covers the whole range.
    private static let startYear = 2000
    private static let visibleBars = 10
    private static let rowHeight: CGFloat = 42

    @State private var response: RaceResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Playback: `frame` is a fractional month index. While playing it advances from `baseFrame`.
    @State private var baseFrame: Double = 0
    @State private var playStart: Date?
    @State private var speed: Double = 2

    private var frameCount: Int { response?.dates.count ?? 0 }
    private var lastFrame: Double { Double(max(frameCount - 1, 0)) }
    private var isPlaying: Bool { playStart != nil }
    /// One month per 0.25 s at 1×.
    private var monthsPerSecond: Double { 4 * speed }

    private func frame(at date: Date) -> Double {
        guard let playStart else { return baseFrame }
        return min(lastFrame, baseFrame + date.timeIntervalSince(playStart) * monthsPerSecond)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let response, frameCount > 1 {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { context in
                    let f = frame(at: context.date)
                    VStack(spacing: 12) {
                        RaceChart(response: response, frame: f, bars: Self.visibleBars, rowHeight: Self.rowHeight)
                        controls(frame: f)
                    }
                    .onChange(of: f >= lastFrame && isPlaying) { _, finished in
                        if finished { pause(at: lastFrame) }
                    }
                }
                .padding(.horizontal, 16)

                if let note = response.note {
                    Text(DisplayName.note(note))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            } else if isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
            }
            Spacer(minLength: 0)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Market Cap Race")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { pause(at: frame(at: .now)) }
    }

    // MARK: Pieces

    private func controls(frame f: Double) -> some View {
        HStack(spacing: 14) {
            Button {
                if isPlaying { pause(at: f) } else { play(from: f >= lastFrame ? 0 : f) }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : (f >= lastFrame ? "arrow.counterclockwise" : "play.fill"))
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isPlaying ? Text("Pause") : (f >= lastFrame ? Text("Replay") : Text("Play")))

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
            let loaded = try await APIService.shared.fetchRace(start: Self.startYear)
            response = loaded
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

// MARK: - The chart for one (fractional) frame

private struct RaceChart: View {
    let response: RaceResponse
    let frame: Double
    let bars: Int
    let rowHeight: CGFloat

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
        let parts = response.dates[index].split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2,
              let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
        else { return response.dates[index] }
        return date.formatted(.dateTime.year().month(.abbreviated))
    }

    var body: some View {
        let all = ranked
        let top = Array(all.prefix(bars))
        let maxValue = max(top.first?.value ?? 1, 1)
        let rankOf = Dictionary(uniqueKeysWithValues: top.enumerated().map { ($1.id, $0) })

        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top 10 by market cap")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dateLabel)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }

            ZStack(alignment: .topLeading) {
                // Every series stays in the tree so a bar slides in from below instead of popping in.
                ForEach(all.prefix(bars + 4)) { entry in
                    let rank = rankOf[entry.id] ?? bars + 1
                    RaceBar(series: entry.series, value: entry.value, maxValue: maxValue, rowHeight: rowHeight)
                        .offset(y: CGFloat(rank) * rowHeight)
                        .opacity(rank < bars ? 1 : 0)
                        .animation(.easeInOut(duration: 0.35), value: rank)
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

    private let nameWidth: CGFloat = 92

    /// A stable colour per company (Swift's `hashValue` changes every launch).
    private var color: Color {
        let seed = (series.ticker ?? series.name).unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }
        return Color(hue: Double(seed) / 360, saturation: 0.55, brightness: 0.85)
    }

    var body: some View {
        HStack(spacing: 6) {
            RaceLogo(urlString: series.logo_url, label: series.ticker ?? series.name, size: 24)
            Text(Company.shortName(series.name))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: nameWidth, alignment: .leading)

            GeometryReader { geo in
                let valueText = Money.short(value)
                let barWidth = max(4, (geo.size.width - 64) * CGFloat(value / maxValue))
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color.gradient)
                        .frame(width: barWidth)
                    Text(valueText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }

    private var initials: some View {
        Text(String(label.prefix(2)).uppercased())
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}
