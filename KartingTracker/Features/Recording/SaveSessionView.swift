import SwiftUI
import SwiftData

/// Shown after Stop: names the session, detects laps and saves it to Records.
struct SaveSessionView: View {
    let recording: SessionFile
    let recordingID: String?
    var onSaved: () -> Void
    var onDiscard: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    @State private var trackName = ""
    @State private var kartClass = ""
    @State private var notes = ""
    @State private var confirmDiscard = false
    /// Time laps from the grid stop when a race start was found
    @State private var useGridStart = true
    private let phases: SessionPhases?

    init(recording: SessionFile, recordingID: String?,
         onSaved: @escaping () -> Void, onDiscard: @escaping () -> Void) {
        self.recording = recording
        self.recordingID = recordingID
        self.onSaved = onSaved
        self.onDiscard = onDiscard
        phases = SessionPhases.detect(recording.gps)
    }

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

    private var racePhases: SessionPhases? { useGridStart ? phases : nil }

    /// The laps that will be saved
    private var windows: [LapWindow] {
        racePhases?.laps ?? detection.map(LapWindow.practice) ?? []
    }

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
                    if let phases {
                        Toggle("Time from the grid stop", isOn: $useGridStart)
                        if useGridStart {
                            LabeledContent("Race start", value: Duration.seconds(phases.raceStart - recording.start)
                                .formatted(.time(pattern: .minuteSecond)))
                        }
                    }
                    if windows.isEmpty {
                        Label("No complete laps found. You can still save the session.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(LapKind.allCases, id: \.self) { kind in
                        let times = windows.filter { $0.kind == kind }.map(\.time)
                        if let best = times.min() {
                            LabeledContent(kind == .practice ? "Laps" : kind.title,
                                           value: "\(times.count) · best \(formatLap(best))")
                        }
                    }
                } header: {
                    Text("Laps")
                } footer: {
                    if racePhases != nil {
                        Text("The kart stopped and then drove a full lap from that spot, so the race started there. Laps are timed from that spot; earlier laps are qualifying.")
                    } else if !windows.isEmpty {
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
                    Button("Discard", role: .destructive) { confirmDiscard = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.isEmpty)
                }
            }
            .confirmationDialog("Discard this recording?", isPresented: $confirmDiscard,
                                titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) {
                    onDiscard()
                    dismiss()
                }
            } message: {
                Text("The sensor data will be deleted. This can't be undone.")
            }
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        let s = Session(date: Date(timeIntervalSince1970: recording.start),
                        trackName: name,
                        kartClass: kartClass.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        if let racePhases {
            s.applyLaps(racePhases.laps, gate: racePhases.gate)
        } else if let detection {
            s.applyLaps(detection)
        }
        s.rawFile = recordingID
        context.insert(s)
        onSaved()
    }
}
