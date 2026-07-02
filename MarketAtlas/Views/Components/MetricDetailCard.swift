import SwiftUI

struct MetricDetailCard: View {
    let metric: MetricType
    let value: String

    private var accent: Color {
        switch metric {
        case .mcapLoss, .totalLiabilities, .totalDebt: return .red
        case .mcapGain, .earnings, .revenue:           return .green
        case .dividendYield, .operatingMargin:         return .mint
        case .cashOnHand, .netAssets:                  return .teal
        default:                                       return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: metric.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(metric.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        MetricDetailCard(metric: .marketCap,  value: "$5.103 T")
        MetricDetailCard(metric: .earnings,   value: "$141.70 B")
        MetricDetailCard(metric: .employees,  value: "36.0K")
        MetricDetailCard(metric: .peRatio,    value: "38.50×")
        MetricDetailCard(metric: .mcapGain,   value: "$1.200 T")
        MetricDetailCard(metric: .totalDebt,  value: "$8.50 B")
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
