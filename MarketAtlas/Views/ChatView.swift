import SwiftUI
import Charts

// MARK: - ChatView

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !vm.messages.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { vm.clear() } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationDestination(for: Company.self) { company in
                CompanyDetailView(company: company)
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if vm.messages.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(vm.messages) { msg in
                        MessageRow(message: msg)
                            .id(msg.id)
                    }
                    if vm.isLoading {
                        TypingIndicatorView()
                            .padding(.horizontal)
                            .id("typing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { inputFocused = false })
            .onChange(of: vm.messages.count) {
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: vm.isLoading) {
                if vm.isLoading {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom") }
                }
            }
        }
    }

    // MARK: - Empty State

    private let suggestions = [
        "Top 10 by market cap",
        "Most employees worldwide",
        "NVIDIA revenue history",
        "Compare Apple vs Microsoft",
        "Highest dividend yield",
        "Best operating margin",
    ]

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            // Icon + title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                Text("MarketAtlas AI")
                    .font(.title2.bold())
                Text("Ask anything about markets, companies,\nor financial metrics.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 40)

            // Suggestion chips — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { s in
                        Button {
                            vm.inputText = s
                            Task { await vm.send() }
                        } label: {
                            Text(s)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Input Bar (ChatGPT-style: single pill, integrated mic/send)

    private var inputBar: some View {
        let hasText = !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isRec   = SpeechRecognizer.shared.isRecording

        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                // Pill: text field + trailing action button
                HStack(alignment: .bottom, spacing: 0) {
                    TextField(isRec ? "Listening…" : "Message MarketAtlas AI",
                              text: $vm.inputText, axis: .vertical)
                        .lineLimit(1...6)
                        .padding(.leading, 16)
                        .padding(.trailing, 6)
                        .padding(.vertical, 11)
                        .focused($inputFocused)
                        .onChange(of: vm.inputText) { _, newValue in
                            guard newValue.last == "\n" else { return }
                            vm.inputText = String(newValue.dropLast())
                            guard !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  !vm.isLoading else { return }
                            inputFocused = false
                            Task { await vm.send() }
                        }

                    // Mic / Stop / Send — one button
                    Button {
                        if isRec {
                            SpeechRecognizer.shared.stop()
                        } else if hasText {
                            inputFocused = false
                            Task { await vm.send() }
                        } else {
                            inputFocused = false
                            SpeechRecognizer.shared.toggle { vm.inputText = $0 }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(hasText ? Color.accentColor : (isRec ? Color.red.opacity(0.15) : Color(.tertiarySystemFill)))
                                .frame(width: 32, height: 32)
                            Image(systemName: isRec ? "stop.fill" : (hasText ? "arrow.up" : "mic.fill"))
                                .font(.system(size: isRec ? 11 : (hasText ? 13 : 14), weight: .semibold))
                                .foregroundStyle(hasText ? .white : (isRec ? .red : .secondary))
                                .symbolEffect(.pulse, isActive: isRec)
                        }
                    }
                    .disabled(vm.isLoading && !isRec)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isRec ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.background)
        }
        .alert("Microphone Access Required", isPresented: Binding(
            get: { SpeechRecognizer.shared.permissionDenied },
            set: { if !$0 { SpeechRecognizer.shared.permissionDenied = false } }
        )) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Microphone and Speech Recognition in Settings.")
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ChatViewModel.Message

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 64)
                if let text = message.userText {
                    Text(text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 16)
        } else if let response = message.response {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.blue.gradient)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(response.blocks.enumerated()), id: \.offset) { _, block in
                        ChatBlockView(block: block)
                    }
                    let speechText = response.blocks.compactMap { block -> String? in
                        if case .text(let t) = block { return t.content }
                        return nil
                    }.joined(separator: ". ")
                    if !speechText.isEmpty {
                        let isSpeaking = SpeechManager.shared.speakingMessageId == message.id
                        Button {
                            SpeechManager.shared.toggle(text: speechText, messageId: message.id)
                        } label: {
                            Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 13))
                                .foregroundStyle(isSpeaking ? Color.accentColor : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var phase = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue.gradient)
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: phase ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Spacer()
        }
        .onAppear { phase = true }
    }
}

// MARK: - Block Dispatcher

struct ChatBlockView: View {
    let block: ChatBlock

    var body: some View {
        switch block {
        case .text(let b):
            Text(b.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

        case .companyTable(let b):
            if b.title == "Comparison", b.companies.count >= 2 {
                ChatCompareView(companies: b.companies)
            } else {
                CompanyChatTableView(block: b)
            }

        case .barChart(let b):
            ChatBarChartView(block: b)

        case .priceChart(let b):
            Label("\(b.company_name) — Price Chart", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Company Table Block

struct CompanyChatTableView: View {
    let block: CompanyTableBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = block.title {
                Text(title).font(.subheadline.bold())
            }
            VStack(spacing: 0) {
                ForEach(Array(block.companies.enumerated()), id: \.offset) { index, company in
                    NavigationLink(value: company.asCompany) {
                        CompanyChatRowView(company: company, rank: index + 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < block.companies.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct CompanyChatRowView: View {
    let company: CompanyChatItem
    let rank: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 16, alignment: .trailing)

            if let url = company.logo_url.flatMap(URL.init) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.15))
                }
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(company.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let ticker = company.ticker {
                    Text(ticker)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if let mcap = company.market_cap_display {
                    Text(mcap)
                        .font(.subheadline.monospacedDigit())
                }
                if let change = company.change_24h {
                    let sign = change >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.2f", change))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(change >= 0 ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Compare Block

struct ChatCompareView: View {
    let companies: [CompanyChatItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparison").font(.subheadline.bold())
            if companies.count == 2 {
                TwoWayCompareCard(a: companies[0], b: companies[1])
            } else {
                MultiCompareCard(companies: companies)
            }
        }
    }
}

private struct CompareMetric: Identifiable {
    let id: String
    let label: String
    let aVal: String
    let bVal: String
    let aRaw: Double?
    let bRaw: Double?
    let higherBetter: Bool
    var aWins: Bool? {
        guard let a = aRaw, let b = bRaw, a != b else { return nil }
        return higherBetter ? a > b : a < b
    }
    var visible: Bool { aVal != "—" || bVal != "—" }
}

struct TwoWayCompareCard: View {
    let a: CompanyChatItem
    let b: CompanyChatItem

    private var metrics: [CompareMetric] {
        [
            CompareMetric(id: "mcap", label: "Market Cap",
                          aVal: a.market_cap_display ?? "—", bVal: b.market_cap_display ?? "—",
                          aRaw: a.market_cap, bRaw: b.market_cap, higherBetter: true),
            CompareMetric(id: "rev", label: "Revenue",
                          aVal: a.revenue_display ?? "—", bVal: b.revenue_display ?? "—",
                          aRaw: nil, bRaw: nil, higherBetter: true),
            CompareMetric(id: "earn", label: "Earnings",
                          aVal: a.earnings_display ?? "—", bVal: b.earnings_display ?? "—",
                          aRaw: nil, bRaw: nil, higherBetter: true),
            CompareMetric(id: "pe", label: "P/E Ratio",
                          aVal: a.pe_ratio.map { String(format: "%.1f×", $0) } ?? "—",
                          bVal: b.pe_ratio.map { String(format: "%.1f×", $0) } ?? "—",
                          aRaw: a.pe_ratio, bRaw: b.pe_ratio, higherBetter: false),
            CompareMetric(id: "div", label: "Div. Yield",
                          aVal: a.dividend_yield.map { String(format: "%.2f%%", $0) } ?? "—",
                          bVal: b.dividend_yield.map { String(format: "%.2f%%", $0) } ?? "—",
                          aRaw: a.dividend_yield, bRaw: b.dividend_yield, higherBetter: true),
            CompareMetric(id: "margin", label: "Op. Margin",
                          aVal: a.operating_margin.map { String(format: "%.1f%%", $0) } ?? "—",
                          bVal: b.operating_margin.map { String(format: "%.1f%%", $0) } ?? "—",
                          aRaw: a.operating_margin, bRaw: b.operating_margin, higherBetter: true),
            CompareMetric(id: "chg", label: "24h Change",
                          aVal: a.change_24h.map { String(format: "%+.2f%%", $0) } ?? "—",
                          bVal: b.change_24h.map { String(format: "%+.2f%%", $0) } ?? "—",
                          aRaw: a.change_24h, bRaw: b.change_24h, higherBetter: true),
        ].filter(\.visible)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                CompanyHeaderCol(company: a, alignment: .leading)
                Spacer()
                Text("VS")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                Spacer()
                CompanyHeaderCol(company: b, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ForEach(Array(metrics.enumerated()), id: \.element.id) { idx, m in
                CompareMetricRow(label: m.label, leftVal: m.aVal, rightVal: m.bVal, leftWins: m.aWins)
                if idx < metrics.count - 1 {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct CompanyHeaderCol: View {
    let company: CompanyChatItem
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            if let url = company.logo_url.flatMap(URL.init) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15))
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Text(company.name)
                .font(.subheadline.bold())
                .lineLimit(1)
            if let ticker = company.ticker {
                Text(ticker)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let price = company.price_display {
                Text(price)
                    .font(.caption.monospacedDigit())
            }
            if let ch = company.change_24h {
                Text(String(format: "%+.2f%%", ch))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(ch >= 0 ? .green : .red)
            }
        }
    }
}

struct CompareMetricRow: View {
    let label: String
    let leftVal: String
    let rightVal: String
    let leftWins: Bool?

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(leftVal)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(leftWins == true ? .semibold : .regular)
                    .foregroundStyle(leftWins == true ? Color.accentColor : .primary)
                if leftWins == true {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 72)

            HStack(spacing: 4) {
                if leftWins == false {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.accentColor)
                }
                Text(rightVal)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(leftWins == false ? .semibold : .regular)
                    .foregroundStyle(leftWins == false ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

struct MultiCompareCard: View {
    let companies: [CompanyChatItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(companies.enumerated()), id: \.element.id) { idx, company in
                NavigationLink(value: company.asCompany) {
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                        if let url = company.logo_url.flatMap(URL.init) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15))
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(company.name).font(.subheadline.weight(.medium)).lineLimit(1)
                            if let ticker = company.ticker {
                                Text(ticker).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let pe = company.pe_ratio {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%.1f×", pe))
                                    .font(.caption2.monospacedDigit())
                                Text("P/E")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(width: 44)
                        }
                        VStack(alignment: .trailing, spacing: 1) {
                            if let mcap = company.market_cap_display {
                                Text(mcap).font(.caption.monospacedDigit())
                            }
                            if let ch = company.change_24h {
                                Text(String(format: "%+.2f%%", ch))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(ch >= 0 ? .green : .red)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < companies.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Bar Chart Block

struct ChatBarChartView: View {
    let block: BarChartBlock

    private func fmt(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1e12 { return String(format: "$%.1fT", v / 1e12) }
        if a >= 1e9  { return String(format: "$%.1fB", v / 1e9) }
        if a >= 1e6  { return String(format: "$%.1fM", v / 1e6) }
        return String(format: "$%.0f", v)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(block.title)
                .font(.subheadline.bold())

            Chart(block.data, id: \.year) { point in
                BarMark(
                    x: .value("Year", String(point.year)),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(fmt(v)).font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
