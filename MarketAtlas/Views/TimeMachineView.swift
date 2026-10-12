import SwiftUI

/// "What were the largest companies on <date>, and where are they now?"
struct TimeMachineView: View {
    private static let earliest = Calendar.current.date(from: DateComponents(year: 1996, month: 1, day: 31))!
    private static let quickYears = [2000, 2005, 2010, 2015, 2020]

    @State private var date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))!
    @State private var response: TimeMachineResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var latest: Date { Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now }

    var body: some View {
        List {
            Section {
                DatePicker("Date", selection: $date,
                           in: Self.earliest...latest, displayedComponents: .date)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quickYears, id: \.self) { year in
                            Button(String(year)) { jump(to: year) }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(Calendar.current.component(.year, from: date) == year ? .accentColor : .secondary)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } footer: {
                Text("The ranking is by market capitalisation on that date.")
            }

            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Time Machine")
        .navigationBarTitleDisplayMode(.inline)
        .shareCard(title: "Time Machine", key: response.map { "\($0.date)|\($0.items.count)" }) {
            if let response { TimeMachineShareCard(response: response) }
        }
        .task(id: date) {
            try? await Task.sleep(for: .milliseconds(350))   // debounce the date wheel
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let response, !response.items.isEmpty {
            Section {
                ForEach(response.items) { item in
                    NavigationLink {
                        CompanyDetailView(company: item.company)
                    } label: {
                        TimeMachineRow(item: item)
                    }
                }
            } header: {
                Text("Largest on \(date.formatted(date: .long, time: .omitted))")
            } footer: {
                if let note = response.note { Text(DisplayName.note(note)) }
            }
        } else if isLoading {
            ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }.buttonStyle(.borderedProminent)
            }
            .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView("No Data", systemImage: "clock.arrow.circlepath",
                                   description: Text("No market-cap history for that date."))
                .listRowBackground(Color.clear)
        }
    }

    private func jump(to year: Int) {
        date = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? date
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIService.shared.fetchTimeMachine(date: date)
        } catch is CancellationError {
            return
        } catch {
            response = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TimeMachineRow: View {
    let item: TimeMachineItem

    private var multipleColor: Color {
        guard let m = item.multiple else { return .secondary }
        return m >= 1 ? .green : .red
    }

    private var multipleText: String { item.multipleText }
    private var todayText: String { item.todayText }

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(item.rank_then)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            CompanyLogoView(company: item.company, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.company.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(Money.short(item.value_then))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(multipleText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(multipleColor)
                Text(todayText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)   // the name truncates before this does
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(item.rank_then), \(item.company.name), \(Money.short(item.value_then)) then, \(multipleText) since, \(todayText)")
    }
}
