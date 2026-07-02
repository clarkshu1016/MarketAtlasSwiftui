import SwiftUI

// MARK: - Particle model
private struct StarParticle: Identifiable {
    let id: Int
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
}

private let kBurstParticles: [StarParticle] = [
    .init(id: 0,  angle: 0,   distance: 60, size: 10),
    .init(id: 1,  angle: 30,  distance: 72, size: 8),
    .init(id: 2,  angle: 60,  distance: 55, size: 12),
    .init(id: 3,  angle: 90,  distance: 68, size: 9),
    .init(id: 4,  angle: 120, distance: 75, size: 8),
    .init(id: 5,  angle: 150, distance: 58, size: 11),
    .init(id: 6,  angle: 180, distance: 65, size: 9),
    .init(id: 7,  angle: 210, distance: 70, size: 10),
    .init(id: 8,  angle: 240, distance: 52, size: 8),
    .init(id: 9,  angle: 270, distance: 66, size: 12),
    .init(id: 10, angle: 300, distance: 58, size: 9),
    .init(id: 11, angle: 330, distance: 73, size: 8),
]

// MARK: - Burst overlay
private struct FavoriteBurstView: View {
    @State private var animate = false
    private let colors: [Color] = [.yellow, .orange, Color(red: 1, green: 0.85, blue: 0.2)]

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(Color.yellow.opacity(animate ? 0 : 0.7), lineWidth: animate ? 1 : 4)
                .frame(width: animate ? 90 : 8, height: animate ? 90 : 8)

            // Inner ring
            Circle()
                .stroke(Color.orange.opacity(animate ? 0 : 0.4), lineWidth: animate ? 1 : 3)
                .frame(width: animate ? 50 : 8, height: animate ? 50 : 8)

            // Star particles
            ForEach(kBurstParticles) { p in
                Image(systemName: "star.fill")
                    .font(.system(size: p.size))
                    .foregroundStyle(colors[p.id % colors.count])
                    .opacity(animate ? 0 : 1)
                    .offset(
                        x: animate ? cos(p.angle * .pi / 180) * p.distance : 0,
                        y: animate ? sin(p.angle * .pi / 180) * p.distance : 0
                    )
                    .scaleEffect(animate ? 0.2 : 1)
                    .rotationEffect(.degrees(animate ? Double(p.id) * 40 : 0))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                animate = true
            }
        }
    }
}

// MARK: - Main view
struct CompanyDetailView: View {
    let company: Company
    @Environment(FavoritesViewModel.self) private var favVM
    @Environment(AuthViewModel.self) private var authVM
    @State private var showSignInPrompt = false
    @State private var starScale: CGFloat = 1.0
    @State private var starRotation: Double = 0
    @State private var showBurst = false

    private var priceText: String {
        company.price_display ?? company.price.map { String(format: "$%.2f", $0) } ?? "—"
    }

    private var availableMetrics: [(MetricType, String)] {
        MetricType.allCases.compactMap { m in
            let d = m.display(from: company)
            return d == "—" ? nil : (m, d)
        }
    }

    private var changeColor: Color {
        guard let ch = company.change_24h else { return .clear }
        return ch >= 0 ? Color.green.opacity(0.08) : Color.red.opacity(0.08)
    }

    private func handleFavorite() {
        guard let ticker = company.ticker else { return }
        let adding = !favVM.isFavorite(ticker)
        Task { await favVM.toggle(company: company, token: authVM.token!) }

        if adding {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            showBurst = true
            withAnimation(.spring(response: 0.22, dampingFraction: 0.32)) {
                starScale = 1.7
                starRotation = 20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) {
                    starScale = 1.0
                    starRotation = -8
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    starRotation = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                showBurst = false
            }
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                starScale = 0.65
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                    starScale = 1.0
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero Header ──────────────────────────────────
                VStack(spacing: 16) {
                    CompanyLogoView(company: company, size: 80)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                    VStack(spacing: 6) {
                        Text(company.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        HStack(spacing: 6) {
                            if let t = company.ticker {
                                Text(t)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            if let c = company.country {
                                Text(c)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Price row
                    HStack(spacing: 12) {
                        Text(priceText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        if let ch = company.change_24h {
                            ChangeBadge(value: ch)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        Color(UIColor.secondarySystemGroupedBackground)
                        changeColor
                    }
                )

                // ── Tags ─────────────────────────────────────────
                if let tags = company.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(.secondary)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                }

                // ── Price History ─────────────────────────────────
                if company.slug != nil {
                    PriceHistoryView(company: company)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                // ── Financial Chart ───────────────────────────────
                if company.slug != nil {
                    VStack(spacing: 0) {
                        FinancialChartView(company: company)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // ── Metrics ───────────────────────────────────────
                if !availableMetrics.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Financial Metrics")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(availableMetrics, id: \.0) { metric, value in
                                MetricDetailCard(metric: metric, value: value)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                } else {
                    ContentUnavailableView(
                        "No Metrics",
                        systemImage: "chart.bar.xaxis",
                        description: Text("No financial data available.")
                    )
                }

                Spacer(minLength: 100)
            }
        }
        .navigationTitle(company.ticker ?? company.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        // Particle burst positioned near top-trailing toolbar button
        .overlay(alignment: .topTrailing) {
            if showBurst {
                FavoriteBurstView()
                    .offset(x: -20, y: 48)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            if let ticker = company.ticker {
                Button {
                    if authVM.isLoggedIn {
                        handleFavorite()
                    } else {
                        showSignInPrompt = true
                    }
                } label: {
                    Image(systemName: favVM.isFavorite(ticker) ? "star.fill" : "star")
                        .foregroundStyle(favVM.isFavorite(ticker) ? Color.yellow : Color.primary)
                        .scaleEffect(starScale)
                        .rotationEffect(.degrees(starRotation))
                }
            }
        }
        .alert("Sign In Required", isPresented: $showSignInPrompt) {
            Button("Sign in with Google") { authVM.signInWithGoogle() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in to save favourites across your devices.")
        }
    }
}

#Preview("Detail") {
    let authVM: AuthViewModel = { let v = AuthViewModel(); v.setToken("preview"); return v }()
    NavigationStack { CompanyDetailView(company: .mockNVIDIA) }
        .environment(FavoritesViewModel())
        .environment(authVM)
}
