import SwiftUI
import MapKit

/// The lap drawn on satellite imagery, colored by speed, with braking points.
struct TrackMapView: View {
    let lap: LapTrace
    /// Braking starts when accel/brake G drops below this
    var brakingThreshold = -0.3

    var body: some View {
        let pts = lap.points
        let speeds = pts.map(\.speed)
        let slow = speeds.min() ?? 0
        let fast = max(speeds.max() ?? 1, slow + 0.1)

        Map(initialPosition: .automatic) {
            ForEach(1..<max(pts.count, 1), id: \.self) { i in
                MapPolyline(coordinates: [coordinate(pts[i - 1]), coordinate(pts[i])])
                    .stroke(color((pts[i - 1].speed + pts[i].speed) / 2, slow, fast), lineWidth: 5)
            }
            ForEach(brakingPoints, id: \.self) { i in
                Annotation("", coordinate: coordinate(pts[i])) {
                    Circle()
                        .fill(.white)
                        .stroke(.black, lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .mapStyle(.imagery)
        .id(lap.number)   // re-center when another lap is chosen
    }

    private var brakingPoints: [Int] {
        let p = lap.points
        return p.indices.dropFirst().filter { p[$0].lonG < brakingThreshold && p[$0 - 1].lonG >= brakingThreshold }
    }

    private func coordinate(_ p: TracePoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
    }

    /// Red (slowest) → yellow → green (fastest)
    private func color(_ speed: Double, _ slow: Double, _ fast: Double) -> Color {
        let f = min(max((speed - slow) / (fast - slow), 0), 1)
        return Color(hue: 0.33 * f, saturation: 0.9, brightness: 0.95)
    }
}
