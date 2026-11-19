import SwiftUI

struct RecordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = Recorder()
    @State private var showSave = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Close") { dismiss() }
                    .disabled(rec.isRecording)   // stop first to avoid losing data
                Spacer()
            }

            Spacer(minLength: 0)

            Text(String(format: "%.0f", rec.speedKmh))
                .font(.system(size: 110, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("km/h").font(.title2).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                GForceTile(title: "Accel / Brake", value: rec.longitudinalG)
                GForceTile(title: "Lateral", value: rec.lateralG)
                GForceTile(title: "Total", value: rec.totalG, signed: false)
            }

            GGCircle(lateral: rec.lateralG, longitudinal: rec.longitudinalG, size: 180)
              

            Text(String(format: "Peak: %.2f g", rec.peakG))
                .font(.headline).monospacedDigit()

            Button(rec.isRecording ? "Stop" : "Start") {
                if rec.isRecording {
                    rec.stop()
                    showSave = rec.lastRecording != nil
                } else {
                    rec.start()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .tint(rec.isRecording ? .red : .green)

            if let url = rec.lastFile {
                ShareLink(item: url) {
                    Label("Export last session", systemImage: "square.and.arrow.up")
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .sheet(isPresented: $showSave) {
            if let recording = rec.lastRecording {
                SaveSessionView(recording: recording, fileURL: rec.lastFile) {
                    dismiss()   // saved: close the recorder and go back to Home
                }
            }
        }
    }
}

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
