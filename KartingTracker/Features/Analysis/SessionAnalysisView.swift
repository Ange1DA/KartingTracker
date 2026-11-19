import SwiftUI

/// Detailed analysis of one session from its raw sensor data:
/// sectors, speed trace, gap to best lap, track map and G-G diagram.
struct SessionAnalysisView: View {
    let session: Session

    @State private var analysis: SessionAnalysis?
    @State private var loaded = false
    @State private var compareNumber: Int?

    var body: some View {
        Group {
            if let analysis, let best = analysis.best {
                content(analysis, best: best)
            } else if loaded {
                ContentUnavailableView("No laps to analyze",
                    systemImage: "chart.xyaxis.line",
                    description: Text("The sensor data for this session is missing or has no complete laps."))
            } else {
                ProgressView("Loading sensor data…")
            }
        }
        .navigationTitle("Lap analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ a: SessionAnalysis, best: LapTrace) -> some View {
        let lap = a.laps.first { $0.number == compareNumber } ?? best
        List {
            Section {
                Picker("Compare lap", selection: $compareNumber) {
                    ForEach(a.laps) { l in
                        Text("\(l.label) · \(formatLap(l.time))").tag(Optional(l.number))
                    }
                }
            } footer: {
                Text("Compared with your best lap (\(best.label)).")
            }

            Section {
                SectorTable(analysis: a)
            } header: {
                Text("Sectors")
            } footer: {
                Text("Purple = your best sector. Ideal = your best sectors added together.")
            }

            Section("Speed") {
                SpeedChart(lap: lap, best: best)
            }

            Section {
                DeltaChart(points: a.delta(lap, vs: best))
            } header: {
                Text("Gap to best lap")
            } footer: {
                Text("Going up = losing time against your best lap at that point of the track.")
            }

            Section {
                TrackMapView(lap: lap)
                    .frame(height: 320)
                    .listRowInsets(EdgeInsets())
            } header: {
                Text("Track map · \(lap.label)")
            } footer: {
                Text("Red = slow, green = fast. White dots = where braking starts.")
            }

            Section {
                GGDiagram(points: a.gg)
            } header: {
                Text("G-G diagram")
            } footer: {
                Text("Every dot is your grip at one moment. The fuller the circle, the more of the kart's grip you use.")
            }
        }
    }

    private func load() async {
        guard !loaded else { return }   // .task runs again when coming back to this screen
        let id = session.rawFile, gate = session.gate
        // Use the saved lap windows when every lap has them (sessions saved since they're stored)
        let saved = session.laps.compactMap { lap in
            lap.start.flatMap { s in lap.end.map { LapWindow(start: s, end: $0, kind: lap.lapKind) } }
        }
        let windows = !saved.isEmpty && saved.count == session.laps.count ? saved : nil
        let result = await Task.detached(priority: .userInitiated) {
            id.flatMap(SessionStore.load).flatMap { recording -> SessionAnalysis? in
                if let windows { return SessionAnalysis(recording: recording, windows: windows) }
                return SessionAnalysis(recording: recording, gate: gate)
            }
        }.value
        analysis = result
        // Start by comparing the second-fastest lap with the fastest
        let byTime = result?.timedLaps.sorted { $0.time < $1.time } ?? []
        compareNumber = (byTime.dropFirst().first ?? byTime.first)?.number
        loaded = true
    }
}
