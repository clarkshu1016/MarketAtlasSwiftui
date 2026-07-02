import SwiftUI

// MARK: - Private cell views

private struct ValueCell: View {
    let value: Int64
    let width: CGFloat

    var body: some View {
        Text(fmt(value))
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(value >= 0 ? Color.primary : Color.red)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: width, alignment: .center)
    }

    private func fmt(_ v: Int64) -> String {
        let d = Double(v)
        let sign = d < 0 ? "-" : ""
        let a = Swift.abs(d)
        switch a {
        case 1e12...: return "\(sign)$\(String(format: "%.2f", a / 1e12))T"
        case 1e9...:  return "\(sign)$\(String(format: "%.2f", a / 1e9))B"
        case 1e6...:  return "\(sign)$\(String(format: "%.1f", a / 1e6))M"
        default:      return "\(sign)$\(Int64(a))"
        }
    }
}

private struct YoyCell: View {
    let yoy: Double?
    let width: CGFloat

    var body: some View {
        Group {
            if let y = yoy {
                Text(String(format: "%+.2f%%", y))
                    .foregroundStyle(y >= 0 ? Color.green : Color.red)
            } else {
                Text("—").foregroundStyle(.quaternary)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(width: width, alignment: .center)
    }
}

// MARK: - Main table

struct FinancialDataTable: View {
    let points: [BarChartPoint]

    private static let colW: CGFloat = 72
    private static let iconW: CGFloat = 28

    private var sorted: [BarChartPoint] { points.sorted { $0.year < $1.year } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Year header row
                HStack(spacing: 0) {
                    Color.clear.frame(width: Self.iconW, height: 1)
                    ForEach(sorted) { pt in
                        Text(pt.yearStr)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: Self.colW, alignment: .center)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))

                Divider()

                // Value row
                HStack(spacing: 0) {
                    Image(systemName: "square.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.blue.opacity(0.85))
                        .frame(width: Self.iconW)
                    ForEach(sorted) { pt in
                        ValueCell(value: pt.value, width: Self.colW)
                    }
                }
                .padding(.vertical, 10)

                Divider()

                // YoY row
                HStack(spacing: 0) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.orange)
                        .frame(width: Self.iconW)
                    ForEach(sorted) { pt in
                        YoyCell(yoy: pt.yoy, width: Self.colW)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
