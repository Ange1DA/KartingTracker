import SwiftUI

/// A "friction circle": a dot that moves with the current lateral and
/// accel/brake G-forces, with reference rings at 0.5, 1.0 and 1.5 g.
struct GGCircle: View {
    let lateral: Double
    let longitudinal: Double
    var maxG = 1.5
    var size: CGFloat = 220

    private func clamp(_ v: Double) -> Double { min(max(v / maxG, -1), 1) }

    var body: some View {
        let r = size / 2
        let lineColor = Color.secondary.opacity(0.35)

        ZStack {
            // Reference rings at 0.5 g, 1.0 g, 1.5 g
            ForEach([0.5, 1.0, 1.5], id: \.self) { g in
                Circle()
                    .stroke(lineColor, lineWidth: 1)
                    .frame(width: size * g / maxG, height: size * g / maxG)
            }

            // Crosshair
            Rectangle()
                .fill(lineColor)
                .frame(width: 1, height: size)
            Rectangle()
                .fill(lineColor)
                .frame(width: size, height: 1)

            // Current G dot
            Circle()
                .fill(Color.red)
                .frame(width: 18, height: 18)
                .offset(x: clamp(lateral) * r, y: -clamp(longitudinal) * r)
                .animation(.easeOut(duration: 0.1), value: lateral)
                .animation(.easeOut(duration: 0.1), value: longitudinal)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)   // centers the circle horizontally
    }
}
