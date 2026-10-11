import SwiftUI

/// Squarified treemap layout (Bruls, Huizing & van Wijk): tiles stay close to square so labels fit.
enum Treemap {
    /// `values` must be positive and sorted descending. The result has one rect per value, in order,
    /// and the rects exactly tile `bounds`.
    static func layout(values: [Double], in bounds: CGRect) -> [CGRect] {
        guard !values.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }
        let total = values.reduce(0, +)
        guard total > 0 else { return Array(repeating: .zero, count: values.count) }

        let scale = Double(bounds.width * bounds.height) / total
        let areas = values.map { CGFloat($0 * scale) }
        var rects = Array(repeating: CGRect.zero, count: values.count)
        var free = bounds
        var start = 0

        while start < areas.count {
            let side = min(free.width, free.height)

            // Grow the current row while that doesn't make the worst tile less square.
            var end = start + 1
            var best = worstRatio(areas[start..<end], side: side)
            while end < areas.count {
                let candidate = worstRatio(areas[start...end], side: side)
                if candidate > best { break }
                best = candidate
                end += 1
            }

            let rowArea = areas[start..<end].reduce(0, +)
            if free.width >= free.height {           // vertical strip on the left
                let w = rowArea / free.height
                var y = free.minY
                for i in start..<end {
                    let h = areas[i] / w
                    rects[i] = CGRect(x: free.minX, y: y, width: w, height: h)
                    y += h
                }
                free = CGRect(x: free.minX + w, y: free.minY, width: max(free.width - w, 0), height: free.height)
            } else {                                  // horizontal strip on top
                let h = rowArea / free.width
                var x = free.minX
                for i in start..<end {
                    let w = areas[i] / h
                    rects[i] = CGRect(x: x, y: free.minY, width: w, height: h)
                    x += w
                }
                free = CGRect(x: free.minX, y: free.minY + h, width: free.width, height: max(free.height - h, 0))
            }
            start = end
        }
        return rects
    }

    private static func worstRatio(_ row: ArraySlice<CGFloat>, side: CGFloat) -> CGFloat {
        let sum = row.reduce(0, +)
        guard sum > 0, side > 0, let maxA = row.max(), let minA = row.min(), minA > 0 else { return .infinity }
        return max(side * side * maxA / (sum * sum), (sum * sum) / (side * side * minA))
    }
}

/// Lays out one tile per weight; `tile` builds the tile content for index `i` at the given size.
struct TreemapView<Tile: View>: View {
    let weights: [Double]
    var spacing: CGFloat = 1.5
    @ViewBuilder let tile: (Int, CGSize) -> Tile

    var body: some View {
        GeometryReader { geo in
            let rects = Treemap.layout(values: weights, in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(rects.indices, id: \.self) { i in
                    let r = rects[i].insetBy(dx: spacing / 2, dy: spacing / 2)
                    if r.width > 0, r.height > 0 {
                        tile(i, r.size)
                            .frame(width: r.width, height: r.height)
                            .offset(x: r.minX, y: r.minY)
                    }
                }
            }
        }
    }
}

/// Red ← grey → green scale shared by the heatmaps. ±`range` percent saturates the colour.
enum HeatColor {
    static let range = 30.0

    static func color(for change: Double?) -> Color {
        guard let change else { return Color(red: 0.43, green: 0.43, blue: 0.46) }   // no data
        let t = max(-1, min(1, change / range))
        let neutral = (r: 0.36, g: 0.37, b: 0.41)
        let target = t >= 0 ? (r: 0.12, g: 0.65, b: 0.32) : (r: 0.82, g: 0.20, b: 0.22)
        let k = abs(t)
        return Color(red: neutral.r + (target.r - neutral.r) * k,
                     green: neutral.g + (target.g - neutral.g) * k,
                     blue: neutral.b + (target.b - neutral.b) * k)
    }

    /// Colour for a change figure shown as text on a normal (non-tile) background.
    static func textColor(_ change: Double?) -> Color {
        guard let change else { return Color.secondary }
        return change >= 0 ? Color.green : Color.red
    }

    static func text(_ change: Double?) -> String {
        guard let change else { return "—" }
        return String(format: "%+.1f%%", change)
    }
}
