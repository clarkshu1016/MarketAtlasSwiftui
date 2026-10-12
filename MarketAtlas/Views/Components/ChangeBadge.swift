import SwiftUI

struct ChangeBadge: View {
    let value: Double
    // Round first so "-0.004" reads as an unchanged 0.00%, not a red "-0.00%".
    private var rounded: Double { (value * 100).rounded() / 100 }
    private var color: Color { rounded > 0 ? .green : rounded < 0 ? .red : .secondary }
    private var spoken: String {
        let amount = String(format: "%.2f", abs(rounded))
        if rounded == 0 { return String(localized: "unchanged") }
        return rounded > 0 ? String(localized: "up \(amount) percent") : String(localized: "down \(amount) percent")
    }

    var body: some View {
        Text(String(format: "%+.2f%%", rounded))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityLabel(spoken)
    }
}

#Preview {
    HStack(spacing: 12) {
        ChangeBadge(value: 2.95)
        ChangeBadge(value: -1.72)
        ChangeBadge(value: 0.00)
    }.padding()
}
