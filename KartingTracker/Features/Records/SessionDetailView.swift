import SwiftUI
import Charts

/// One session: its details and every lap, with the gap to the session's best lap.
struct SessionDetailView: View {
    let session: Session

    // SwiftData doesn't keep relationship order, so sort by lap number
    private var laps: [Lap] { session.laps.sorted { $0.number < $1.number } }
    private var best: Double? { laps.map(\.time).min() }

    var body: some View {
        List {
            Section {
                LabeledContent("Date",
                               value: session.date.formatted(date: .abbreviated, time: .shortened))
                if !session.kartClass.isEmpty {
                    LabeledContent("Kart class", value: session.kartClass)
                }
                LabeledContent("Best lap", value: best.map(formatLap) ?? "--")
                if !session.notes.isEmpty {
                    Text(session.notes)
                }
            }

            if session.rawFile != nil {
                Section {
                    NavigationLink {
                        SessionAnalysisView(session: session)
                    } label: {
                        Label("Lap analysis", systemImage: "chart.xyaxis.line")
                    }
                }
            }

            if laps.count > 1, let best {
                Section("Lap times") {
                    Chart(laps) { lap in
                        LineMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                        PointMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                            .foregroundStyle(lap.time == best ? Color.yellow : Color.accentColor)
                    }
                    .chartXScale(domain: 1...laps.count)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis { AxisMarks(values: .stride(by: laps.count > 12 ? 5 : 1)) }
                    .frame(height: 180)
                }
            }

            Section("Laps") {
                if laps.isEmpty {
                    Text("No laps were detected in this session.")
                        .foregroundStyle(.secondary)
                }
                ForEach(laps) { lap in
                    HStack {
                        Text("Lap \(lap.number)")
                        if lap.time == best {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                        Spacer()
                        if let best, lap.time != best {
                            Text(String(format: "+%.3f", lap.time - best))
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Text(formatLap(lap.time))
                            .monospacedDigit()
                            .fontWeight(lap.time == best ? .bold : .regular)
                    }
                }
            }
        }
        .navigationTitle(session.trackName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
