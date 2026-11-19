import SwiftUI
import Charts

/// Speed along the lap for the chosen lap and the best lap.
struct SpeedChart: View {
    let lap: LapTrace
    let best: LapTrace

    var body: some View {
        Chart {
            series(best, name: "Best · lap \(best.number)")
            if lap.number != best.number {
                series(lap, name: "Lap \(lap.number)")
            }
        }
        .chartXScale(domain: 0...max(best.length, 1))
        .chartXAxisLabel("Distance (m)")
        .chartYAxisLabel("km/h")
        .chartYScale(domain: .automatic(includesZero: false))
        .chartForegroundStyleScale(range: [Color.yellow, Color.accentColor])
        .frame(height: 200)
    }

    /// Distances are scaled to the best lap's length so both laps line up.
    private func series(_ trace: LapTrace, name: String) -> some ChartContent {
        let scale = trace.length > 0 ? best.length / trace.length : 1
        return ForEach(trace.points.indices, id: \.self) { i in
            LineMark(x: .value("Distance", trace.points[i].distance * scale),
                     y: .value("Speed", trace.points[i].speed * 3.6))
                .foregroundStyle(by: .value("Lap", name))
        }
    }
}

/// Time gap to the best lap along the lap.
struct DeltaChart: View {
    let points: [DistanceValue]

    var body: some View {
        Chart {
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.secondary.opacity(0.5))
            ForEach(points) { p in
                LineMark(x: .value("Distance", p.distance), y: .value("Gap", p.value))
                    .foregroundStyle(Color.red)
            }
        }
        .chartXScale(domain: 0...max(points.last?.distance ?? 1, 1))
        .chartXAxisLabel("Distance (m)")
        .chartYAxisLabel("s")
        .frame(height: 160)
    }
}

/// Lateral vs. accel/brake G-forces for the whole session.
struct GGDiagram: View {
    let points: [GGPoint]
    var maxG = 1.5

    var body: some View {
        Chart {
            RuleMark(x: .value("Zero", 0)).foregroundStyle(Color.secondary.opacity(0.4))
            RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.secondary.opacity(0.4))
            ForEach(points.indices, id: \.self) { i in
                PointMark(x: .value("Lateral", points[i].lat),
                          y: .value("Accel / brake", points[i].lon))
                    .symbolSize(10)
                    .foregroundStyle(Color.red.opacity(0.35))
            }
        }
        .chartXScale(domain: -maxG...maxG)
        .chartYScale(domain: -maxG...maxG)
        .chartXAxisLabel("Lateral g")
        .chartYAxisLabel("Accel / brake g")
        .chartPlotStyle { $0.clipped() }
        .aspectRatio(1, contentMode: .fit)
    }
}
