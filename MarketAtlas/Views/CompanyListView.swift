import SwiftUI

struct CompanyListView: View {
    @Bindable var vm: CompanyViewModel
    @State private var showScrollToTop = false
    @State private var showScreener = false
    @State private var exploreDestination: ExploreDestination?

    private enum ExploreDestination: Hashable { case heatmap, performance, timeMachine }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Stats
                    StatsRowView(stats: vm.stats)
                        .id("list-top")
                        .onAppear  { showScrollToTop = false }
                        .onDisappear { showScrollToTop = true }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // Metric selector
                    MetricSelectorView(vm: vm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // Country chips
                    CountryChipBar(vm: vm)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // Tag chips
                    if !vm.availableTags.isEmpty {
                        TagChipBar(vm: vm)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    // Count label
                    let companies = vm.filteredCompanies
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countLabel(count: companies.count))
                            .foregroundStyle(.tertiary)
                        if let updated = vm.dataUpdatedAt {
                            FreshnessLabel(updatedAt: updated)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    // Company rows
                    if companies.isEmpty && !vm.isLoading {
                        if vm.allCompanies.isEmpty {
                            // Nothing was ever loaded — this is a load failure, not an empty search.
                            ContentUnavailableView {
                                Label("Couldn't Load Companies", systemImage: "wifi.exclamationmark")
                            } description: {
                                Text(vm.errorMessage ?? "Check your connection and try again.")
                            } actions: {
                                Button("Try Again") { Task { await vm.refresh() } }
                                    .buttonStyle(.borderedProminent)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ContentUnavailableView.search(text: vm.searchText)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        ForEach(Array(companies.enumerated()), id: \.element.id) { idx, company in
                            NavigationLink {
                                CompanyDetailView(company: company)
                            } label: {
                                CompanyRowView(company: company, rank: idx + 1, metric: vm.selectedMetric)
                            }
                            .listRowInsets(EdgeInsets(top: 3, leading: 14, bottom: 3, trailing: 14))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 10)
                            )
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.refresh() }
                .background(Color(UIColor.systemGroupedBackground))
                .overlay {
                    if vm.isLoading && vm.allCompanies.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(UIColor.systemGroupedBackground))
                    }
                }

                // Scroll-to-top FAB
                if showScrollToTop {
                    Button {
                        withAnimation { proxy.scrollTo("list-top", anchor: .top) }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.accentColor, in: Circle())
                    }
                    .accessibilityLabel("Scroll to top")
                    .padding(.trailing, 20)
                    .padding(.bottom, 88)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("MarketAtlas")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $vm.searchText, prompt: "Search company or ticker…")
        .task { await vm.load() }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showScrollToTop)
        .animation(.default, value: vm.selectedMetric)
        .animation(.default, value: vm.selectedCountry)
        .animation(.default, value: vm.selectedTag)
        .navigationDestination(item: $exploreDestination) { destination in
            switch destination {
            case .heatmap:     HeatmapView()
            case .performance: PerformanceView()
            case .timeMachine: TimeMachineView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { exploreDestination = .heatmap } label: {
                        Label("Heatmap", systemImage: "square.grid.3x3.fill")
                    }
                    Button { exploreDestination = .performance } label: {
                        Label("Performance", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button { exploreDestination = .timeMachine } label: {
                        Label("Time Machine", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Explore")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showScreener = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Screener")
            }
        }
        .sheet(isPresented: $showScreener) {
            ScreenerView()
        }
    }

    private func countLabel(count: Int) -> String {
        let regionLabel = vm.selectedCountry
            .flatMap { $0.split(separator: " ", maxSplits: 1).last.map(String.init) }
            .map { " · \($0)" } ?? ""
        let tagLabel = vm.selectedTag.map { " · \($0)" } ?? ""
        return "\(count) \(count == 1 ? "company" : "companies")\(regionLabel)\(tagLabel) · sorted by \(vm.selectedMetric.label)"
    }
}

/// "Updated 3 months ago" — turns orange when the data is more than 2 days old.
private struct FreshnessLabel: View {
    let updatedAt: Date

    private var isStale: Bool { Date().timeIntervalSince(updatedAt) > 2 * 24 * 3600 }

    var body: some View {
        let relative = updatedAt.formatted(.relative(presentation: .named))
        HStack(spacing: 4) {
            Image(systemName: isStale ? "exclamationmark.triangle.fill" : "clock")
            Text("Data updated \(relative)")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(isStale ? Color.orange : Color.secondary.opacity(0.6))
    }
}

#Preview {
    let vm = CompanyViewModel()
    return NavigationStack {
        CompanyListView(vm: vm)
    }
}
