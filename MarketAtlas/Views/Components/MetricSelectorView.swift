import SwiftUI

struct MetricSelectorView: View {
    @Bindable var vm: CompanyViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MetricType.allCases) { metric in
                    let selected = vm.selectedMetric == metric
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.selectMetric(metric)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(metric.label)
                                .font(.system(size: 13, weight: .semibold))
                            if selected {
                                Image(systemName: vm.sortDescending ? "chevron.down" : "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(
                            Capsule().fill(selected ? Color.accentColor : Color(UIColor.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    let vm = CompanyViewModel()
    return MetricSelectorView(vm: vm)
        .padding(.vertical)
        .background(Color(UIColor.systemGroupedBackground))
}
