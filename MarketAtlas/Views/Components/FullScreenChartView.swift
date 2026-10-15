import SwiftUI
import Charts

/// One point of a price or market-cap series.
struct ChartSeriesPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// The price chart on its own screen, in landscape: pinch to zoom, drag to pan, press and drag for a crosshair.
/// Shown from the expand button on the price card. The card itself is unchanged apart from that button.
struct FullScreenChartView: View {
    let title: String
    let points: [ChartSeriesPoint]          // oldest first, the whole history
    let format: (Double) -> String          // headline and crosshair value
    let axisFormat: (Double) -> String
    var initialRange: PriceRange = .fiveYear
    @Binding var isPresented: Bool

    @Environment(\.colorScheme) private var colorScheme

    @State private var range: PriceRange?   // nil while the zoom is free (no preset matches)
    @State private var visibleLength: TimeInterval = 5 * 365 * 86_400
    @State private var scrollPosition: Date = .now
    @State private var selectedDate: Date?
    @State private var pinchBase: TimeInterval?

    private static let day: TimeInterval = 86_400
    private static let minLength: TimeInterval = 30 * day

    init(title: String, points: [ChartSeriesPoint], initialRange: PriceRange = .fiveYear, isPresented: Binding<Bool>,
         format: @escaping (Double) -> String, axisFormat: @escaping (Double) -> String) {
        self.title = title
        self.points = points
        self.initialRange = initialRange
        self._isPresented = isPresented
        self.format = format
        self.axisFormat = axisFormat
        _range = State(initialValue: initialRange)
    }

    // MARK: Derived

    private var first: Date { points.first?.date ?? .now }
    private var last: Date { points.last?.date ?? .now }
    private var fullLength: TimeInterval { max(last.timeIntervalSince(first), Self.minLength) }

    /// The points inside the window the chart is showing now.
    private var visible: [ChartSeriesPoint] {
        let end = scrollPosition.addingTimeInterval(visibleLength)
        let inside = points.filter { $0.date >= scrollPosition && $0.date <= end }
        return inside.isEmpty ? points : inside
    }

    private var selected: ChartSeriesPoint? {
        guard let d = selectedDate else { return nil }
        // Only points that are on screen: pressing at the very edge must not pick one just outside the window.
        return visible.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) }
    }

    private var yDomain: ClosedRange<Double> {
        let vals = visible.map(\.value)
        guard let lo = vals.min(), let hi = vals.max(), hi > lo else {
            let v = vals.first ?? 0
            return (v * 0.9)...(v * 1.1 + 1)
        }
        let pad = (hi - lo) * 0.08
        return (lo - pad)...(hi + pad)
    }

    /// True once the window has been dragged away from the newest data.
    private var awayFromLatest: Bool {
        scrollPosition.addingTimeInterval(visibleLength) < last.addingTimeInterval(-7 * Self.day)
    }

    private func jumpToLatest() {
        withAnimation(.easeInOut(duration: 0.25)) {
            scrollPosition = last.addingTimeInterval(-visibleLength)
            selectedDate = nil
        }
    }

    private var windowStart: Double { visible.first?.value ?? 0 }
    private var windowEnd: Double { visible.last?.value ?? 0 }
    private var isUp: Bool { windowEnd >= windowStart }
    private var lineColor: Color { isUp ? Color(red: 0.2, green: 0.85, blue: 0.6) : .red }
    private var secondary: Color { colorScheme == .dark ? .white.opacity(0.55) : .secondary }

    /// The point before the selected one, for "change since the previous point" (a month, with the data we have).
    private var previousOfSelected: ChartSeriesPoint? {
        guard let s = selected, let i = points.firstIndex(where: { $0.date == s.date }), i > 0 else { return nil }
        return points[i - 1]
    }

    private var shownValue: Double { selected?.value ?? windowEnd }
    private var changePercent: Double {
        guard windowStart > 0 else { return 0 }
        return (shownValue - windowStart) / windowStart * 100
    }

    // MARK: Body

    var body: some View {
        // The app stays upright: the chart is laid out as a landscape screen and turned a quarter turn, so opening it
        // is one step with no rotation animation. If the phone itself is already on its side, it is shown as it is.
        GeometryReader { geo in
            let full = geo.size                       // the whole screen: this view ignores the safe areas
            let win = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.safeAreaInsets ?? .zero
            let upright = full.height >= full.width
            ZStack {
                if upright {
                    // Turned a quarter turn clockwise: the screen's top (the island) is now the chart's left edge.
                    content(leading: win.top, trailing: win.bottom, top: win.right, bottom: win.left)
                        .frame(width: full.height, height: full.width)
                        .rotationEffect(.degrees(90))
                } else {
                    content(leading: win.left, trailing: win.right, top: win.top, bottom: win.bottom)
                        .frame(width: full.width, height: full.height)
                }
            }
            .frame(width: full.width, height: full.height)
        }
        .ignoresSafeArea()
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .statusBarHidden(true)
        .onAppear { apply(initialRange, animated: false) }
    }

    private func content(leading: CGFloat, trailing: CGFloat, top: CGFloat, bottom: CGFloat) -> some View {
        VStack(spacing: 10) {
            header
            chart
        }
        .padding(.leading, leading + 16)
        .padding(.trailing, trailing + 16)
        .padding(.top, top + 12)
        .padding(.bottom, bottom + 12)
        .background(Color(UIColor.systemBackground))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                // The top line is the name; while a point is picked it becomes that point's date (same slot, same style).
                Group {
                    if let s = selected {
                        Text(s.date, format: .dateTime.year().month(.abbreviated).day())
                    } else {
                        Text(title)
                    }
                }
                .font(.footnote.weight(.semibold)).foregroundStyle(secondary).lineLimit(1)
                .frame(height: 16, alignment: .leading)

                HStack(alignment: .center, spacing: 10) {
                    Text(format(shownValue))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(minWidth: 118, alignment: .leading)
                    if let s = selected {
                        if let p = previousOfSelected, p.value > 0 {
                            changePill((s.value - p.value) / p.value * 100, arrow: false)
                        }
                    } else {
                        changePill(changePercent, arrow: true)
                    }
                }
                .frame(height: 32, alignment: .leading)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(PriceRange.allCases, id: \.self) { r in
                    Button { apply(r, animated: true) } label: {
                        Text(r.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(range == r ? Color(UIColor.systemBackground) : secondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(range == r ? Color(UIColor.label) : Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { isPresented = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.tertiarySystemGroupedBackground), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private func changePill(_ pct: Double, arrow: Bool) -> some View {
        let color: Color = pct >= 0 ? Color(red: 0.12, green: 0.72, blue: 0.5) : .red
        return HStack(spacing: 3) {
            if arrow { Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right").font(.system(size: 10, weight: .bold)) }
            Text(String(format: "%+.2f%%", pct)).monospacedDigit()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var chart: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                    .interpolationMethod(.monotone)
            }
            if let s = selected {
                RuleMark(x: .value("Date", s.date))
                    .foregroundStyle(secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(x: .value("Date", s.date), y: .value("Value", s.value))
                    .foregroundStyle(lineColor).symbolSize(70)
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.date)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleLength)
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3, 3]))
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text(axisFormat(d)).font(.system(size: 10)).foregroundStyle(secondary) }
                }
            }
        }
        .chartXAxis {
            // Long spans: one tick a year, so a year is never printed twice.
            AxisMarks(values: xAxisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel(format: xFormat, centered: false).font(.system(size: 10)).foregroundStyle(secondary)
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { jumpToLatest() })
        .overlay(alignment: .topTrailing) {
            if awayFromLatest {
                Button { jumpToLatest() } label: {
                    Label("Latest", systemImage: "forward.end.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(UIColor.tertiarySystemGroupedBackground), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6).padding(.trailing, 44)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: awayFromLatest)
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { g in
                    if pinchBase == nil { pinchBase = visibleLength }
                    zoom(to: (pinchBase ?? visibleLength) / max(g.magnification, 0.01))
                }
                .onEnded { _ in pinchBase = nil }
        )
    }

    /// Long spans: whole years only, spaced so that about eight labels fit (every year, every 2, 5, 10 years).
    private var xAxisValues: AxisMarkValues {
        guard visibleLength > 900 * Self.day else { return .automatic(desiredCount: 8) }
        let years = visibleLength / (365 * Self.day)
        let step = [1, 2, 5, 10, 20].first { years / Double($0) <= 8 } ?? 20
        return .stride(by: .year, count: step)
    }

    private var xFormat: Date.FormatStyle {
        let days = visibleLength / Self.day
        if days < 120 { return .dateTime.month(.abbreviated).day() }
        if days < 900 { return .dateTime.year(.twoDigits).month(.abbreviated) }
        return .dateTime.year()
    }

    // MARK: Zoom and range

    private func apply(_ r: PriceRange, animated: Bool) {
        range = r
        let length: TimeInterval
        switch r {
        case .oneYear:  length = 365 * Self.day
        case .twoYear:  length = 2 * 365 * Self.day
        case .fiveYear: length = 5 * 365 * Self.day
        case .max:      length = fullLength
        }
        let set = {
            visibleLength = min(max(length, Self.minLength), fullLength)
            scrollPosition = last.addingTimeInterval(-visibleLength)
            selectedDate = nil
        }
        if animated { withAnimation(.easeInOut(duration: 0.25)) { set() } } else { set() }
    }

    /// Change the window length around its centre, keeping it inside the data.
    private func zoom(to newLength: TimeInterval) {
        let length = min(max(newLength, Self.minLength), fullLength)
        let centre = scrollPosition.addingTimeInterval(visibleLength / 2)
        var start = centre.addingTimeInterval(-length / 2)
        if start < first { start = first }
        if start.addingTimeInterval(length) > last { start = last.addingTimeInterval(-length) }
        visibleLength = length
        scrollPosition = start
        range = nil
    }
}
