import SwiftUI

extension View {
    /// Keeps content at a comfortable reading width on iPad / wide windows (no effect on iPhone),
    /// centred, with `background` filling the full width behind it.
    func readableWidth(_ maxWidth: CGFloat = 720, background: Color = Color(UIColor.systemGroupedBackground)) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .background(background)
    }
}
