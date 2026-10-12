import SwiftUI
#if DEBUG
import PulseUI

/// A draggable floating bubble that opens the Pulse network console from any tab,
/// so you don't have to navigate to Settings to inspect requests.
private struct PulseFloatingBubbleModifier: ViewModifier {
    @State private var committedOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var showConsole = false

    private let bubbleSize: CGFloat = 44
    private let hideBubble = UserDefaults.standard.bool(forKey: "hide_pulse_bubble")

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    let defaultPosition = CGPoint(x: size.width - 36, y: size.height - 140)
                    let raw = CGPoint(
                        x: defaultPosition.x + committedOffset.width + dragOffset.width,
                        y: defaultPosition.y + committedOffset.height + dragOffset.height
                    )
                    let clamped = CGPoint(
                        x: min(max(raw.x, bubbleSize / 2), size.width - bubbleSize / 2),
                        y: min(max(raw.y, bubbleSize / 2), size.height - bubbleSize / 2)
                    )

                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Image(systemName: "network")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(width: bubbleSize, height: bubbleSize)
                        .shadow(radius: 3, y: 1)
                        .position(clamped)
                        .opacity(hideBubble ? 0 : 1)          // `defaults write … hide_pulse_bubble -bool true` for clean screenshots
                        .allowsHitTesting(!hideBubble)
                        .onTapGesture { showConsole = true }
                        .gesture(
                            DragGesture()
                                .onChanged { dragOffset = $0.translation }
                                .onEnded { value in
                                    committedOffset.width += value.translation.width
                                    committedOffset.height += value.translation.height
                                    dragOffset = .zero
                                }
                        )
                }
            }
            .sheet(isPresented: $showConsole) {
                NavigationStack { ConsoleView() }
            }
    }
}

extension View {
    func pulseFloatingBubble() -> some View {
        modifier(PulseFloatingBubbleModifier())
    }
}
#endif
