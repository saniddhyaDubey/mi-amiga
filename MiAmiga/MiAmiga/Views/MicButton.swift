import SwiftUI

/// Hold-to-talk button. Reports press and release; the ring around it breathes
/// with the live input level so it's obvious the mic is actually hearing you.
struct MicButton: View {
    let isListening: Bool
    let level: Float
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringScale: CGFloat {
        guard isListening, !reduceMotion else { return 1 }
        return 1 + CGFloat(level) * 0.35
    }

    var body: some View {
        ZStack {
            // Outer level ring
            Circle()
                .fill(Color.miAmiga.opacity(0.18))
                .frame(width: 132, height: 132)
                .scaleEffect(ringScale)
                .animation(.easeOut(duration: 0.12), value: ringScale)
                .opacity(isListening ? 1 : 0)

            Circle()
                .fill(Color.miAmiga.opacity(0.28))
                .frame(width: 108, height: 108)
                .scaleEffect(isListening ? 1 + CGFloat(level) * 0.18 : 1)
                .animation(.easeOut(duration: 0.12), value: level)
                .opacity(isListening ? 1 : 0)

            Circle()
                .fill(
                    LinearGradient(
                        colors: isListening
                            ? [Color.red, Color.red.opacity(0.82)]
                            : [Color.miAmiga, Color.miAmiga.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 92, height: 92)
                .shadow(
                    color: (isListening ? Color.red : Color.miAmiga).opacity(0.35),
                    radius: isPressed ? 6 : 14,
                    y: isPressed ? 2 : 6
                )
                .scaleEffect(isPressed ? 0.94 : 1)
                .animation(.spring(duration: 0.22), value: isPressed)

            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 140, height: 140)
        .contentShape(Circle())
        // A 0-distance drag gesture is the reliable way to get true press/release
        // semantics; `Button` only fires on a completed tap.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    onPress()
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Hold to speak English")
        .accessibilityHint("Hold this button, say your phrase in English, then release to translate it to Spanish.")
        .accessibilityAddTraits(.isButton)
    }
}
