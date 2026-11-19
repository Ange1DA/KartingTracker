//
//  LapDetector.swift
//  KartingTracker
//
//  Finds laps in a GPS trace by timing each pass through a virtual finish line ("gate").
//

import Foundation

/// A virtual finish line: a line through (lat, lon), perpendicular to `course`.
/// Only passes in the direction of `course` count.
struct Gate: Equatable {
    var lat: Double
    var lon: Double
    var course: Double   // degrees clockwise from north
}

struct LapDetection {
    let gate: Gate
    /// Unix times at which the kart crossed the gate
    let crossings: [Double]

    /// Time between consecutive crossings. The out-lap before the first crossing
    /// and the in-lap after the last one are partial, so they are not included.
    var lapTimes: [Double] { zip(crossings.dropFirst(), crossings).map { $0 - $1 } }
}

enum LapDetector {
    static let halfWidth = 15.0     // m either side of the gate point that still counts
    static let minLapTime = 15.0    // s; ignores GPS jitter re-crossing the line
    static let maxGap = 3.0         // s; don't interpolate across GPS dropouts
    static let maxAccuracy = 20.0   // m; drop poor fixes
    static let minSpeed = 5.0       // m/s; course is unreliable below this

    /// Detects laps. Pass the gate from an earlier session at the same track so
    /// lap times stay comparable; otherwise one is picked from this trace.
    static func detect(_ gps: [GPSSample], gate given: Gate? = nil) -> LapDetection? {
        let pts = gps.filter { $0.hAcc >= 0 && $0.hAcc <= maxAccuracy }.sorted { $0.t < $1.t }
        guard pts.count > 1, let gate = given ?? autoGate(pts) else { return nil }

        let rad = gate.course * .pi / 180
        let hx = sin(rad), hy = cos(rad)   // heading unit vector (x east, y north)

        var crossings: [Double] = []
        for (a, b) in zip(pts, pts.dropFirst()) where b.t - a.t <= maxGap {
            let pa = local(a, gate), pb = local(b, gate)
            let da = pa.x * hx + pa.y * hy   // distance along heading, before → after the line
            let db = pb.x * hx + pb.y * hy
            guard da < 0, db >= 0 else { continue }

            let f = -da / (db - da)
            let cx = pa.x + (pb.x - pa.x) * f
            let cy = pa.y + (pb.y - pa.y) * f
            guard abs(cx * hy - cy * hx) <= halfWidth else { continue }   // passed beside the line

            let t = a.t + (b.t - a.t) * f
            if let last = crossings.last, t - last < minLapTime { continue }
            crossings.append(t)
        }
        return LapDetection(gate: gate, crossings: crossings)
    }

    /// Picks a gate on the racing line: the moving sample nearest the middle of the session,
    /// when the driver is most likely on track rather than in the pits.
    static func autoGate(_ pts: [GPSSample]) -> Gate? {
        let moving = pts.filter { $0.speed > minSpeed && $0.course >= 0 }
        guard !moving.isEmpty else { return nil }
        let s = moving[moving.count / 2]
        return Gate(lat: s.lat, lon: s.lon, course: s.course)
    }

    /// True if the trace passes within `meters` of the gate, i.e. it was recorded at that track.
    static func isNear(_ gate: Gate, _ gps: [GPSSample], within meters: Double = 300) -> Bool {
        gps.contains {
            let p = local($0, gate)
            return (p.x * p.x + p.y * p.y).squareRoot() <= meters
        }
    }

    /// Equirectangular projection to meters around the gate; accurate at track scale.
    private static func local(_ s: GPSSample, _ g: Gate) -> (x: Double, y: Double) {
        let mPerDegLat = 111_320.0
        let mPerDegLon = mPerDegLat * cos(g.lat * .pi / 180)
        return ((s.lon - g.lon) * mPerDegLon, (s.lat - g.lat) * mPerDegLat)
    }
}
