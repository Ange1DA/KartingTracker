import SwiftUI
import SwiftData

/// Shown after Stop: names the session, detects laps and saves it to Records.
struct SaveSessionView: View {
    let recording: SessionFile
    let fileURL: URL?
    var onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    @State private var trackName = ""
    @State private var kartClass = ""
    @State private var notes = ""

    private var name: String { trackName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var knownTracks: [String] { Array(Set(sessions.map(\.trackName))).sorted() }

    /// Finish line from the latest session at this track, so lap times are comparable
    private var savedGate: Gate? {
        guard !name.isEmpty else { return nil }
        return sessions.lazy
            .filter { $0.trackName.caseInsensitiveCompare(name) == .orderedSame }
            .compactMap(\.gate)
            .first { LapDetector.isNear($0, recording.gps) }
    }

    private var detection: LapDetection? { LapDetector.detect(recording.gps, gate: savedGate) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    HStack {
                        TextField("Track name", text: $trackName)
                        if !knownTracks.isEmpty {
                            Menu {
                                ForEach(knownTracks, id: \.self) { t in
                                    Button(t) { trackName = t }
                                }
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                        }
                    }
                    TextField("Kart class (optional)", text: $kartClass)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                }

                Section {
                    if let laps = detection?.lapTimes, !laps.isEmpty {
                        LabeledContent("Laps", value: "\(laps.count)")
                        LabeledContent("Best lap", value: formatLap(laps.min()!))
                    } else {
                        Label("No complete laps found. You can still save the session.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Laps")
                } footer: {
                    if detection?.lapTimes.isEmpty == false {
                        Text(savedGate != nil
                             ? "Timed at the finish line saved for this track."
                             : "Timed at a line picked from this session. Later sessions at this track will reuse it.")
                    }
                }
            }
            .navigationTitle("Save session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        let s = Session(date: Date(timeIntervalSince1970: recording.start),
                        trackName: name,
                        kartClass: kartClass.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        if let d = detection {
            s.laps = d.lapTimes.enumerated().map { Lap(number: $0.offset + 1, time: $0.element) }
            s.bestLap = d.lapTimes.min()
            s.gate = d.gate
        }
        s.rawFile = fileURL?.lastPathComponent
        context.insert(s)
        onSaved()
    }
}
