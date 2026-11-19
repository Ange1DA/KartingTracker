import SwiftUI

/// A small card showing one G-force reading, e.g. "Lateral +0.85 g".
struct GForceTile: View {
    let title: String
    let value: Double
    var signed = true

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(signed ? String(format: "%+.2f", value) : String(format: "%.2f", value))
                .font(.title2.bold()).monospacedDigit()
            Text("g").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
