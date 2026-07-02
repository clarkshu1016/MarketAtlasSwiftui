import SwiftUI

struct StatsRowView: View {
    let stats: StatsResponse?

    var body: some View {
        HStack(spacing: 10) {
            StatCard(icon: "building.2.fill",    color: .accentColor,
                     value: stats.map { "\($0.total_companies)" } ?? "—",
                     label: "Companies")
            StatCard(icon: "globe.americas.fill", color: .green,
                     value: stats.map { "\($0.countries)" } ?? "—",
                     label: "Markets")
            StatCard(icon: "chart.pie.fill",      color: .orange,
                     value: stats?.total_market_cap_display ?? "—",
                     label: "Market Cap")
        }
        .padding(.horizontal, 16)
    }
}

private struct StatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        StatsRowView(stats: StatsResponse(
            total_companies: 892, total_market_cap: 65_279_000_000_000,
            total_market_cap_display: "$65.279T", countries: 52, last_updated: nil
        ))
        StatsRowView(stats: nil)
    }
    .padding(.vertical)
    .background(Color(UIColor.systemGroupedBackground))
}
