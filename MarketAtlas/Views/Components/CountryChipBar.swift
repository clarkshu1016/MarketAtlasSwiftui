import SwiftUI

struct CountryChipBar: View {
    @Bindable var vm: CompanyViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                chip(label: "\u{1F30D} All", selected: vm.selectedCountry == nil) {
                    vm.selectedCountry = nil
                }
                ForEach(vm.availableCountries, id: \.self) { country in
                    chip(label: country, selected: vm.selectedCountry == country) {
                        vm.selectedCountry = vm.selectedCountry == country ? nil : country
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.accentColor : .secondary)
                .background(
                    Capsule()
                        .fill(selected
                              ? Color.accentColor.opacity(0.1)
                              : Color(UIColor.secondarySystemGroupedBackground))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            selected ? Color.accentColor.opacity(0.8) : Color(UIColor.separator).opacity(0.4),
                            lineWidth: selected ? 1.5 : 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let vm = CompanyViewModel()
    return CountryChipBar(vm: vm)
        .padding(.vertical)
        .background(Color(UIColor.systemGroupedBackground))
}
