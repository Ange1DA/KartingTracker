import SwiftUI
import SwiftData

struct RecordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var search = ""

    private var filtered: [Session] {
        search.isEmpty ? sessions
        : sessions.filter { $0.trackName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { s in
                    NavigationLink {
                        SessionDetailView(session: s)
                    } label: {
                        SessionRow(session: s, isPB: isPB(s, in: sessions))
                    }
                }
                .onDelete { idx in idx.forEach { context.delete(filtered[$0]) } }
            }
            .navigationTitle("Records")
            .searchable(text: $search, prompt: "Search track")
            .toolbar {
                #if DEBUG
                // Fake data for trying the UI in the simulator, where there's no real GPS track
                Button("Add sample") {
                    let s = Session(date: .now.addingTimeInterval(-Double.random(in: 0...2_000_000)),
                                    trackName: ["Kartodromo A", "Circuit B"].randomElement()!)
                    s.laps = (1...10).map { Lap(number: $0, time: Double.random(in: 48.0...50.5)) }
                    s.bestLap = s.laps.map(\.time).min()
                    context.insert(s)
                }
                #endif
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No sessions yet", systemImage: "list.bullet.rectangle")
                }
            }
        }
    }
}
