import SwiftUI

/// The Heatmap tab: countries or sectors, with one shared period.
struct HeatmapTabView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case countries, sectors
        var id: String { rawValue }
    }

    @State private var mode: Mode = .countries
    @State private var period: HeatmapView.Period = .ytd

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .countries: HeatmapView(period: $period)
                case .sectors:   SectorHeatmapView(period: $period)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Map", selection: $mode) {
                        Text("Countries").tag(Mode.countries)
                        Text("Sectors").tag(Mode.sectors)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }
}
