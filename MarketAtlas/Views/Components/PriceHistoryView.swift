import SwiftUI
import Charts
import UIKit

// MARK: - Horizontal-only drag recognizer (allows ScrollView to scroll vertically)

private struct HorizontalDragRecognizer: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded:   () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handle(_:)))
        pan.delegate = context.coordinator
        v.addGestureRecognizer(pan)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded   = onEnded
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChanged: onChanged, onEnded: onEnded) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded:   () -> Void

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping () -> Void) {
            self.onChanged = onChanged; self.onEnded = onEnded
        }

        @objc func handle(_ g: UIPanGestureRecognizer) {
            switch g.state {
            case .changed:
                onChanged(g.location(in: g.view).x)
            case .ended, .cancelled, .failed:
                onEnded()
            default: break
            }
        }

        // Only begin if finger is moving more horizontally than vertically
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }

        // Always allow simultaneous recognition with the ScrollView
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

// MARK: - Enums

enum HistoryMetric: String, CaseIterable {
    case price     = "Price"
    case marketCap = "Market Cap"
}

enum PriceRange: String, CaseIterable {
    case oneYear  = "1Y"
    case twoYear  = "2Y"
    case fiveYear = "5Y"
    case max      = "MAX"

    func startDate(from first: Date) -> Date {
        switch self {
        case .oneYear:  return Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        case .twoYear:  return Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        case .fiveYear: return Calendar.current.date(byAdding: .year, value: -5, to: .now)!
        case .max:      return first
        }
    }
}

// MARK: - View

struct PriceHistoryView: View {
    let company: Company

    @State private var priceResponse: PriceHistoryResponse?    = nil
    @State private var mcapResponse:  MarketCapHistoryResponse? = nil
    @State private var isLoadingPrice = true
    @State private var isLoadingMcap  = true
    @State private var metric: HistoryMetric = .price
    @State private var range:  PriceRange    = .fiveYear
    // Scrubbing state
    @State private var isDragging    = false
    @State private var selectedPrice: PricePoint?     = nil
    @State private var selectedMcap:  MarketCapPoint? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthViewModel.self) private var authVM

    // MARK: Colours
    private var isDark: Bool         { colorScheme == .dark }
    private var bgColor: Color       { isDark ? Color(red: 0.07, green: 0.10, blue: 0.18) : Color(UIColor.secondarySystemGroupedBackground) }
    private var primaryText: Color   { isDark ? .white : .primary }
    private var secondaryText: Color { isDark ? .white.opacity(0.55) : .secondary }
    private var gridColor: Color     { isDark ? .white.opacity(0.18) : Color(UIColor.separator).opacity(0.5) }
    private var btnUnsel: Color      { isDark ? .white.opacity(0.10) : Color(UIColor.tertiarySystemGroupedBackground) }
    private var btnSel: Color        { isDark ? .white : Color(UIColor.label) }
    private var btnSelText: Color    { isDark ? .black : Color(UIColor.systemBackground) }
    private var btnUnselText: Color  { isDark ? .white.opacity(0.6) : .secondary }

    // MARK: Data
    private var firstPriceDate: Date { priceResponse?.points.first?.date ?? .distantPast }
    private var firstMcapDate:  Date { mcapResponse?.points.first?.date  ?? .distantPast }

    private var filteredPrice: [PricePoint] {
        guard let pts = priceResponse?.points else { return [] }
        let start = range.startDate(from: firstPriceDate)
        return pts.filter { $0.date >= start }
    }

    private var filteredMcap: [MarketCapPoint] {
        guard let pts = mcapResponse?.points else { return [] }
        let start = range.startDate(from: firstMcapDate)
        return pts.filter { $0.date >= start }
    }

    private var isEmpty: Bool   { metric == .price ? filteredPrice.isEmpty : filteredMcap.isEmpty }
    private var isLoading: Bool { metric == .price ? isLoadingPrice : isLoadingMcap }

    // Display value: scrubbing shows selected, otherwise shows latest
    private var displayValue: Double {
        if metric == .price {
            return isDragging ? (selectedPrice?.price ?? 0) : (filteredPrice.last?.price ?? 0)
        } else {
            return isDragging ? (selectedMcap?.value ?? 0) : (filteredMcap.last?.value ?? 0)
        }
    }

    private var displayDate: Date? {
        isDragging ? (metric == .price ? selectedPrice?.date : selectedMcap?.date) : nil
    }

    private var startValue: Double {
        metric == .price ? (filteredPrice.first?.price ?? 0) : (filteredMcap.first?.value ?? 0)
    }

    // Overall period change — used for line color (never changes during drag)
    private var periodLatest: Double {
        metric == .price ? (filteredPrice.last?.price ?? 0) : (filteredMcap.last?.value ?? 0)
    }
    private var isPositive: Bool {
        guard startValue > 0 else { return true }
        return periodLatest >= startValue
    }
    private var lineColor: Color { isPositive ? Color(red: 0.2, green: 0.85, blue: 0.6) : .red }

    // Display change — shows selected-vs-start when dragging
    private var changePercent: Double {
        guard startValue > 0 else { return 0 }
        return (displayValue - startValue) / startValue * 100
    }

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top row: metric + range pills ─────────────────────
            HStack(spacing: 8) {
                // Metric pills (Price | Market Cap)
                HStack(spacing: 3) {
                    ForEach(HistoryMetric.allCases, id: \.self) { m in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                metric = m
                                isDragging = false
                                selectedPrice = nil
                                selectedMcap  = nil
                            }
                        } label: {
                            Text(m.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(metric == m ? btnSelText : btnUnselText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(metric == m ? btnSel : btnUnsel)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Range pills
                HStack(spacing: 3) {
                    ForEach(PriceRange.allCases, id: \.self) { r in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                range = r
                                isDragging = false
                                selectedPrice = nil
                                selectedMcap  = nil
                            }
                        } label: {
                            Text(r.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(range == r ? btnSelText : btnUnselText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(range == r ? btnSel : btnUnsel)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Value + date display ──────────────────────────────
            if !isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formatValue(displayValue))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .contentTransition(.numericText())

                    if isDragging, let d = displayDate {
                        Text(d, format: .dateTime.month(.abbreviated).year())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(secondaryText)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text(String(format: "%+.2f%%", changePercent))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(lineColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
            }

            // ── Chart ─────────────────────────────────────────────
            if isLoading {
                ProgressView().tint(primaryText)
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .padding(.bottom, 12)
            } else if isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(minHeight: 130)
                    .padding(.bottom, 12)
            } else {
                GeometryReader { geo in
                    let maxLabels = Int(geo.size.width / 52)
                    Chart {
                        if metric == .price {
                            ForEach(filteredPrice) { pt in
                                AreaMark(x: .value("Date", pt.date), y: .value("Value", pt.price))
                                    .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Date", pt.date), y: .value("Value", pt.price))
                                    .foregroundStyle(lineColor)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                                    .interpolationMethod(.catmullRom)
                            }
                            if let sel = selectedPrice, isDragging {
                                RuleMark(x: .value("Date", sel.date))
                                    .foregroundStyle(secondaryText.opacity(0.6))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                PointMark(x: .value("Date", sel.date), y: .value("Value", sel.price))
                                    .foregroundStyle(lineColor)
                                    .symbolSize(55)
                                    .annotation(position: .top, spacing: 4) {
                                        Text(formatValue(sel.price))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(primaryText)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(bgColor.opacity(0.9))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                            }
                        } else {
                            ForEach(filteredMcap) { pt in
                                AreaMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                                    .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                                    .foregroundStyle(lineColor)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                                    .interpolationMethod(.catmullRom)
                            }
                            if let sel = selectedMcap, isDragging {
                                RuleMark(x: .value("Date", sel.date))
                                    .foregroundStyle(secondaryText.opacity(0.6))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                PointMark(x: .value("Date", sel.date), y: .value("Value", sel.value))
                                    .foregroundStyle(lineColor)
                                    .symbolSize(55)
                                    .annotation(position: .top, spacing: 4) {
                                        Text(formatValue(sel.value))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(primaryText)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(bgColor.opacity(0.9))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3, 3]))
                                .foregroundStyle(gridColor)
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text(formatAxisY(v))
                                        .font(.system(size: 10))
                                        .foregroundStyle(secondaryText)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: maxLabels)) { _ in
                            AxisValueLabel(format: xFormat, centered: true)
                                .font(.system(size: 10))
                                .foregroundStyle(isDragging ? .clear : secondaryText)
                        }
                    }
                    .chartOverlay { proxy in
                        HorizontalDragRecognizer(
                            onChanged: { xPos in
                                if !isDragging {
                                    isDragging = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                updateSelection(at: xPos, proxy: proxy)
                            },
                            onEnded: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    isDragging    = false
                                    selectedPrice = nil
                                    selectedMcap  = nil
                                }
                            }
                        )
                    }
                    .frame(width: geo.size.width, height: 140)
                }
                .frame(height: 140)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task(id: company.slug) { await loadAll() }
    }

    // MARK: - Selection

    private func updateSelection(at xPos: CGFloat, proxy: ChartProxy) {
        if metric == .price {
            guard let date: Date = proxy.value(atX: xPos),
                  let nearest = filteredPrice.min(by: {
                      abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                  }) else { return }
            if nearest.id != selectedPrice?.id {
                selectedPrice = nearest
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            guard let date: Date = proxy.value(atX: xPos),
                  let nearest = filteredMcap.min(by: {
                      abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                  }) else { return }
            if nearest.id != selectedMcap?.id {
                selectedMcap = nearest
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: - Helpers

    private var xFormat: Date.FormatStyle {
        // Use the actual visible data span rather than the selected range pill.
        // This prevents repeated year labels for newly-listed companies whose
        // entire history fits within a single calendar year.
        let dates: [Date] = metric == .price
            ? filteredPrice.map(\.date)
            : filteredMcap.map(\.date)

        if let first = dates.first, let last = dates.last {
            let spanDays = last.timeIntervalSince(first) / 86_400
            if spanDays < 60 {         // < 2 months  → "Jun 5"
                return .dateTime.month(.abbreviated).day()
            } else if spanDays < 548 { // < ~18 months → "Jan"
                return .dateTime.month(.abbreviated)
            }
        }
        return .dateTime.year()
    }

    private func formatValue(_ v: Double) -> String {
        if metric == .price {
            return String(format: "$%.2f", v)
        }
        return formatLarge(v)
    }

    private func formatAxisY(_ v: Double) -> String {
        metric == .price
            ? (v >= 1000 ? String(format: "$%.0fK", v / 1000) : String(format: "$%.0f", v))
            : formatLarge(v)
    }

    private func formatLarge(_ v: Double) -> String {
        switch v {
        case 1e12...: return String(format: "$%.2fT", v / 1e12)
        case 1e9...:  return String(format: "$%.1fB", v / 1e9)
        case 1e6...:  return String(format: "$%.0fM", v / 1e6)
        default:      return String(format: "$%.0f", v)
        }
    }

    private func loadAll() async {
        guard let slug = company.slug else {
            isLoadingPrice = false
            isLoadingMcap  = false
            return
        }
        async let p: () = loadPrice(slug: slug)
        async let m: () = loadMcap(slug: slug)
        _ = await (p, m)
    }

    private func loadPrice(slug: String) async {
        isLoadingPrice = true
        priceResponse = try? await APIService.shared.fetchPriceHistory(slug: slug, range: "max", token: authVM.token)
        isLoadingPrice = false
    }

    private func loadMcap(slug: String) async {
        isLoadingMcap = true
        mcapResponse = try? await APIService.shared.fetchMarketCapHistory(slug: slug)
        isLoadingMcap = false
    }
}
