import SwiftUI

/// Sector times for every lap, best sectors highlighted, plus the ideal lap.
struct SectorTable: View {
    let analysis: SessionAnalysis

    var body: some View {
        let best = analysis.bestSectors
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("Lap").gridColumnAlignment(.leading)
                ForEach(1...SessionAnalysis.sectorCount, id: \.self) { Text("S\($0)") }
                Text("Time")
            }
            .font(.caption).foregroundStyle(.secondary)

            ForEach(analysis.laps) { lap in
                let sectors = analysis.sectorTimes(lap)
                GridRow {
                    Text("\(lap.number)")
                    ForEach(sectors.indices, id: \.self) { i in
                        Text(String(format: "%.2f", sectors[i]))
                            .foregroundStyle(sectors[i] == best[i] ? Color.purple : Color.primary)
                            .fontWeight(sectors[i] == best[i] ? .bold : .regular)
                    }
                    Text(formatLap(lap.time))
                        .fontWeight(lap.number == analysis.best?.number ? .bold : .regular)
                }
            }

            Divider()

            if let ideal = analysis.theoreticalBest {
                GridRow {
                    Text("Ideal")
                    ForEach(best.indices, id: \.self) { i in Text(String(format: "%.2f", best[i])) }
                    Text(formatLap(ideal)).bold()
                }
                .foregroundStyle(.purple)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }
}
