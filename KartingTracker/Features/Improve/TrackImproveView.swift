import SwiftUI
import SwiftData

/// Stats and coaching suggestions for one track.
struct TrackImproveView: View {
    let track: String
    @Query private var sessions: [Session]

    private var trackSessions: [Session] { sessions.filter { $0.trackName == track } }
    private var lapTimes: [Double] {
        trackSessions.flatMap { $0.laps.filter(\.lapKind.countsForBest).map(\.time) }
    }

    private var best: Double? { lapTimes.min() }
    private var average: Double? {
        lapTimes.isEmpty ? nil : lapTimes.reduce(0, +) / Double(lapTimes.count)
    }
    private var consistency: Double? {
        guard let avg = average, lapTimes.count > 1 else { return nil }
        let variance = lapTimes.map { pow($0 - avg, 2) }.reduce(0, +) / Double(lapTimes.count)
        return variance.squareRoot()
    }

    var body: some View {
        List {
            Section("Your numbers") {
                LabeledContent("Best lap", value: best.map(formatLap) ?? "--")
                LabeledContent("Average lap", value: average.map(formatLap) ?? "--")
                LabeledContent("Consistency (std)",
                               value: consistency.map { String(format: "±%.2f s", $0) } ?? "--")
            }
            Section("Suggestions") {
                // Placeholder: the AI coach will fill this from the Python backend
                Label("Coaching tips for this track will appear here once the AI analysis is connected.",
                      systemImage: "sparkles")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(track)
    }
}
