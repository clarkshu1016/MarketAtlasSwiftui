import SwiftUI

struct CompanyRowView: View {
    let company: Company
    let rank: Int
    let metric: MetricType

    private var metricColor: Color {
        switch metric {
        case .mcapLoss: return (company.mcap_loss ?? 0) < 0 ? .red : .green
        case .mcapGain: return .green
        default:        return .primary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text(verbatim: "\(rank)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: 30, alignment: .center)

            // Logo
            CompanyLogoView(company: company, size: 44)

            // Name / ticker / country
            VStack(alignment: .leading, spacing: 2) {
                Text(company.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    if let t = company.ticker {
                        Text(t)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let c = company.country,
                       let flag = c.split(separator: " ", maxSplits: 1).first.map(String.init),
                       flag.unicodeScalars.first.map({ (0x1F1E6...0x1F1FF).contains($0.value) }) == true {
                        Text("·").foregroundStyle(.quaternary).font(.caption2)
                        Text(flag)
                            .font(.system(size: 13))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Metric + change
            VStack(alignment: .trailing, spacing: 3) {
                Text(metric.display(from: company))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(metricColor)
                if let ch = company.change_24h {
                    ChangeBadge(value: ch)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        CompanyRowView(company: .mockNVIDIA,  rank: 1,    metric: .marketCap)
        CompanyRowView(company: .mockApple,   rank: 2,    metric: .marketCap)
        CompanyRowView(company: .mockWalmart, rank: 1005, metric: .marketCap)
    }
    .listStyle(.plain)
    .background(Color(UIColor.systemGroupedBackground))
}
