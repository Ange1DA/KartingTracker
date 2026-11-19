import SwiftUI
import SwiftData

struct ImproveView: View {
    @Query private var sessions: [Session]

    private var tracks: [String] {
        Array(Set(sessions.map(\.trackName))).sorted()
    }

    var body: some View {
        NavigationStack {
            List(tracks, id: \.self) { track in
                NavigationLink {
                    TrackImproveView(track: track)
                } label: {
                    VStack(alignment: .leading) {
                        Text(track).font(.headline)
                        Text("\(sessions.filter { $0.trackName == track }.count) sessions")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Improve")
            .overlay {
                if tracks.isEmpty {
                    ContentUnavailableView("Nothing to analyze yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Record a session to get suggestions."))
                }
            }
        }
    }
}
