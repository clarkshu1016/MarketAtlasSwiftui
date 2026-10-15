import SwiftUI

/// Where a company stands among its peers: rank by market cap in its main industry, in its country and worldwide,
/// a few neighbours in the same industry that open on tap, and the way into the comparison screen.
/// Uses only the list the app already holds.
struct PeersCard: View {
    let company: Company
    let pool: [Company]

    private struct Result {
        var industry: String
        var industryRank: Int
        var industryTotal: Int
        var countryRank: Int?
        var peers: [Company]
    }

    @State private var result: Result?
    @State private var computed = false

    var body: some View {
        VStack(spacing: 0) {
            // The task needs a view to hang on while the card itself is still empty.
            Color.clear.frame(height: 0).task(id: company.id) {
                result = Self.compute(company, in: pool)
                computed = true
            }
            if computed {
                VStack(alignment: .leading, spacing: 14) {
                    if let r = result {
                        Text("Peers")
                            .font(.headline)

                        // Rank chips
                        HStack(spacing: 8) {
                            rankChip("#\(r.industryRank)", DisplayName.tag(r.industry), of: r.industryTotal)
                            if let g = company.market_cap_rank { rankChip("#\(g)", "Worldwide") }
                            if let c = r.countryRank, let name = company.country {
                                rankChip("#\(c)", DisplayName.country(name))
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(r.peers) { peer in
                                    // The tile opens the company; the small button in its corner compares the two.
                                    NavigationLink {
                                        CompanyDetailView(company: peer)
                                    } label: {
                                        peerTile(peer)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .topTrailing) {
                                        NavigationLink {
                                            CompareView(pool: pool, initial: company, peers: [peer])
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.accentColor)
                                                .frame(width: 26, height: 26)
                                                .background(Color(UIColor.secondarySystemGroupedBackground), in: Circle())
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Compare")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, -16)
                        .contentMargins(.horizontal, 16, for: .scrollContent)
                    }

                    // Without an industry there are no peers to suggest; a plain Compare row opens the picker instead.
                    if result == nil {
                        NavigationLink {
                            CompareView(pool: pool, initial: company)
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Compare")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func rankChip(_ big: String, _ small: String, of total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(big).font(.system(size: 20, weight: .bold, design: .rounded))
                if let total {
                    Text("/ \(total)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(small)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func peerTile(_ peer: Company) -> some View {
        // Every tile reads the same way: logo and name, then the country, then market cap and the day's move.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CompanyLogoView(company: peer, size: 32)
                Text(peer.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .padding(.trailing, 24)   // room for the compare button in the corner
            }
            Text(peer.country.map(DisplayName.country) ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(peer.market_cap_display ?? "—")
                    .font(.subheadline.weight(.semibold))
                if let ch = peer.change_24h {
                    Text(String(format: "%+.1f%%", ch))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ch >= 0 ? Color.green : Color.red)
                }
            }
        }
        .padding(12)
        .frame(width: 150, alignment: .leading)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Industry = the company's first tag. Peers = up to five companies from that industry closest in market cap.
    private static func compute(_ company: Company, in pool: [Company]) -> Result? {
        guard let industry = company.tags?.first, let cap = company.market_cap else { return nil }
        let same = pool
            .filter { $0.market_cap != nil && ($0.tags?.contains(industry) ?? false) }
            .sorted { ($0.market_cap ?? 0) > ($1.market_cap ?? 0) }
        guard same.count > 1, let idx = same.firstIndex(where: { $0.id == company.id }) else { return nil }

        let neighbours = same.enumerated()
            .filter { $0.element.id != company.id }
            .sorted { abs($0.offset - idx) < abs($1.offset - idx) }
            .prefix(5)
            .sorted { $0.offset < $1.offset }
            .map(\.element)

        var countryRank: Int?
        if let country = company.country {
            countryRank = pool.filter { $0.country == country && ($0.market_cap ?? 0) > cap }.count + 1
        }
        return Result(industry: industry, industryRank: idx + 1, industryTotal: same.count,
                      countryRank: countryRank, peers: neighbours)
    }
}
