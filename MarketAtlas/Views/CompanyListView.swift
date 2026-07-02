import SwiftUI

struct CompanyListView: View {
    @Bindable var vm: CompanyViewModel
    @State private var showScrollToTop = false
    @State private var showScreener = false

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
                    Text(countLabel(count: companies.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // Company rows
                    if companies.isEmpty && !vm.isLoading {
                        ContentUnavailableView.search(text: vm.searchText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showScreener = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
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
        return "\(count) companies\(regionLabel)\(tagLabel) · sorted by \(vm.selectedMetric.label)"
    }
}

#Preview {
    let vm = CompanyViewModel()
    return NavigationStack {
        CompanyListView(vm: vm)
    }
}
