import SwiftUI

/// Live recording screen: speed, G-forces and the Start/Stop button.
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
