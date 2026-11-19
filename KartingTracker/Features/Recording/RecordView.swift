import SwiftUI
import AudioToolbox

/// Live recording screen: speed, G-forces and the Start/Stop button.
struct RecordView: View {
    /// Seconds to put the phone away before recording starts
    static let countdownSeconds = 5

    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = Recorder()
    @State private var showSave = false
    /// Seconds left before recording starts, nil when not counting down
    @State private var countdown: Int?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Close") { dismiss() }
                    .disabled(rec.isRecording || countdown != nil)   // stop first to avoid losing data
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

            if rec.isRecording && !rec.gCalibrated {
                Text("G-forces line up with the kart after a few corners")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if rec.isRecording {
                HoldToStopButton {
                    rec.stop()
                    showSave = rec.lastRecording != nil
                }
                Text("You can lock the phone, recording continues")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Start") { countdown = Self.countdownSeconds }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .tint(.green)
            }

            if let id = rec.recordingID {
                ShareLink(items: SessionStore.files(id)) {
                    Label("Export last session", systemImage: "square.and.arrow.up")
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .overlay {
            if let countdown {
                countdownOverlay(countdown)
            }
        }
        .task(id: countdown) {
            guard let left = countdown else { return }
            guard left > 0 else { return startRecording() }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()   // felt through a pocket
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { countdown = left - 1 }
        }
        .sheet(isPresented: $showSave) {
            if let recording = rec.lastRecording {
                SaveSessionView(recording: recording, recordingID: rec.recordingID,
                                onSaved: { dismiss() },   // close the recorder, back to Home
                                onDiscard: { rec.discardLast() })
            }
        }
    }

    /// Gives time to put the phone in a pocket or mount before recording starts.
    private func countdownOverlay(_ left: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Put the phone away")
                .font(.title2.bold())
            Text("\(left)")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: left)
            Text("Recording starts with a vibration")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Start now") { startRecording() }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .tint(.green)
            Button("Cancel", role: .cancel) { countdown = nil }
                .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial)
    }

    private func startRecording() {
        countdown = nil
        guard !rec.isRecording else { return }
        rec.start()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1113)   // "begin recording" sound
    }
}
