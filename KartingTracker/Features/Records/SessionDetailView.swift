import SwiftUI
import Charts

/// One session: its details and every lap (grouped into qualifying, formation and
/// race when a race start was found), with the gap to the best lap of each group.
struct SessionDetailView: View {
    let session: Session

    // SwiftData doesn't keep relationship order, so sort by lap number
    private var laps: [Lap] { session.laps.sorted { $0.number < $1.number } }
    private var best: Double? { laps.filter(\.lapKind.countsForBest).map(\.time).min() }
    private var kinds: [LapKind] { LapKind.allCases.filter { k in laps.contains { $0.lapKind == k } } }

    /// Laps of one kind with their number within it (Q1, Q2, …)
    private func laps(of kind: LapKind) -> [(lap: Lap, n: Int)] {
        laps.filter { $0.lapKind == kind }.enumerated().map { ($1, $0 + 1) }
    }

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
                        if kinds.count > 1 {
                            LineMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                                .foregroundStyle(by: .value("Part", lap.lapKind.title))
                            PointMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                                .foregroundStyle(by: .value("Part", lap.lapKind.title))
                                .symbolSize(lap.time == best ? 120 : 40)
                        } else {
                            LineMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                            PointMark(x: .value("Lap", lap.number), y: .value("Time", lap.time))
                                .foregroundStyle(lap.time == best ? Color.yellow : Color.accentColor)
                        }
                    }
                    .chartXScale(domain: 1...laps.count)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis { AxisMarks(values: .stride(by: laps.count > 12 ? 5 : 1)) }
                    .frame(height: 180)
                }
            }

            if laps.isEmpty {
                Section("Laps") {
                    Text("No laps were detected in this session.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(kinds, id: \.self) { kind in
                let group = laps(of: kind)
                let groupBest = group.map(\.lap.time).min()
                Section(kind.title) {
                    ForEach(group, id: \.lap.id) { lap, n in
                        HStack {
                            Text(kind.label(n))
                            if lap.time == groupBest && kind.countsForBest {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(lap.time == best ? .yellow : .secondary)
                            }
                            Spacer()
                            if let groupBest, lap.time != groupBest {
                                Text(String(format: "+%.3f", lap.time - groupBest))
                                    .font(.caption).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Text(formatLap(lap.time))
                                .monospacedDigit()
                                .fontWeight(lap.time == best ? .bold : .regular)
                        }
                        .foregroundStyle(kind.countsForBest ? .primary : .secondary)
                    }
                }
            }
        }
        .navigationTitle(session.trackName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
