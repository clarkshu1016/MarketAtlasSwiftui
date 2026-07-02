import SwiftUI

struct ChangeBadge: View {
    let value: Double
    private var color: Color { value >= 0 ? .green : .red }

    var body: some View {
        Text(String(format: "%+.2f%%", value))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

#Preview {
    HStack(spacing: 12) {
        ChangeBadge(value: 2.95)
        ChangeBadge(value: -1.72)
        ChangeBadge(value: 0.00)
    }.padding()
}
