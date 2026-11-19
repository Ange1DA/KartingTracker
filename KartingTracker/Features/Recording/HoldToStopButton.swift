import SwiftUI

/// A Stop button that has to be held for a second, so a touch through a
/// pocket can't end the session by accident. Fills up while it's held.
struct HoldToStopButton: View {
    var duration = 1.0
    var action: () -> Void

    @State private var pressing = false

    var body: some View {
        Text("Hold to stop")
            .font(.title3.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: 240)
            .padding(.vertical, 18)
            .background {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Color.red
                        Color.white.opacity(0.35)
                            .frame(width: pressing ? g.size.width : 0)
                    }
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: duration) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                action()
            } onPressingChanged: { isPressing in
                withAnimation(isPressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) {
                    pressing = isPressing
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Stop recording")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}
