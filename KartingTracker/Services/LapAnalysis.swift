//
//  LapAnalysis.swift
//  KartingTracker
//
//  Turns a raw recording into per-lap traces (speed, G-forces and position by
//  distance into the lap) plus sector times, an ideal lap and time gaps.
//  Pure logic, no UI, so it can be tested on its own.
//

import Foundation

/// One point of a lap, measured from the moment the kart crossed the finish line.
struct TracePoint {
    var distance: Double   // m from the start of the lap
    var time: Double       // s from the start of the lap
    var lat: Double
    var lon: Double
    var speed: Double      // m/s
    var lonG: Double       // + accelerating, − braking
    var latG: Double       // sideways
}

struct LapTrace: Identifiable {
    let number: Int
    let start: Double      // Unix time
    let end: Double
    let points: [TracePoint]

    var id: Int { number }
    var time: Double { end - start }
    var length: Double { points.last?.distance ?? 0 }

    /// Any value at a distance into the lap, interpolated between GPS points.
    func value(_ key: KeyPath<TracePoint, Double>, atDistance d: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if d <= first.distance { return first[keyPath: key] }
        if d >= last.distance { return last[keyPath: key] }
        var lo = 0, hi = points.count - 1        // first point at or past d
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].distance < d { lo = mid + 1 } else { hi = mid }
        }
        let a = points[lo - 1], b = points[lo]
        let span = b.distance - a.distance
        let f = span > 0 ? (d - a.distance) / span : 0
        return a[keyPath: key] + (b[keyPath: key] - a[keyPath: key]) * f
    }

    /// Same, at a fraction (0…1) of the lap. Laps differ slightly in measured
    /// length because of GPS noise, so laps are compared by fraction.
    func value(_ key: KeyPath<TracePoint, Double>, atFraction f: Double) -> Double {
        value(key, atDistance: f * length)
    }
}

struct DistanceValue: Identifiable {
    let distance: Double
    let value: Double
    var id: Double { distance }
}

struct GGPoint {
    let lat: Double
    let lon: Double
}

struct SessionAnalysis {
    static let sectorCount = 3

    let laps: [LapTrace]
    /// Lateral vs. accel/brake G at 10 Hz while on track, for the G-G diagram
    let gg: [GGPoint]

    var best: LapTrace? { laps.min { $0.time < $1.time } }

    init?(recording: SessionFile, gate: Gate?) {
        guard let detection = LapDetector.detect(recording.gps, gate: gate) else { return nil }
        let gps = recording.gps
            .filter { $0.hAcc >= 0 && $0.hAcc <= LapDetector.maxAccuracy }
            .sorted { $0.t < $1.t }
        let motion = recording.motion.sorted { $0.t < $1.t }
        let windows = Array(zip(detection.crossings, detection.crossings.dropFirst()))

        laps = windows.enumerated().compactMap { i, w in
            Self.trace(number: i + 1, from: w.0, to: w.1, gps: gps, motion: motion)
        }
        gg = Self.ggPoints(motion, during: windows)
    }

    // MARK: Sectors

    /// Sector times of a lap; sectors split the lap into equal parts by distance.
    func sectorTimes(_ lap: LapTrace) -> [Double] {
        let n = Self.sectorCount
        let marks = (0...n).map { lap.value(\.time, atFraction: Double($0) / Double(n)) }
        return zip(marks.dropFirst(), marks).map { $0 - $1 }
    }

    var bestSectors: [Double] {
        let all = laps.map(sectorTimes)
        return (0..<Self.sectorCount).map { i in all.map { $0[i] }.min() ?? 0 }
    }

    /// Your best sectors added together: the lap you've shown you can drive.
    var theoreticalBest: Double? { laps.isEmpty ? nil : bestSectors.reduce(0, +) }

    /// Time lost (+) or gained (−) against `reference` along the lap, every `step` metres.
    func delta(_ lap: LapTrace, vs reference: LapTrace, step: Double = 5) -> [DistanceValue] {
        guard reference.length > 0, lap.length > 0 else { return [] }
        return stride(from: 0, through: reference.length, by: step).map { d in
            let f = d / reference.length
            return DistanceValue(distance: d,
                                 value: lap.value(\.time, atFraction: f) - reference.value(\.time, atDistance: d))
        }
    }

    // MARK: Building traces

    static func trace(number: Int, from start: Double, to end: Double,
                      gps: [GPSSample], motion: [MotionSample]) -> LapTrace? {
        guard let first = gps.lastIndex(where: { $0.t <= start }),
              let last = gps.firstIndex(where: { $0.t >= end }),
              last - first >= 2 else { return nil }

        // Clip the first and last samples to the exact finish-line crossings
        var samples = Array(gps[first...last])
        let n = samples.count
        samples[0] = interpolate(samples[0], samples[1], at: start)
        samples[n - 1] = interpolate(samples[n - 2], samples[n - 1], at: end)

        let mPerDegLat = 111_320.0
        let mPerDegLon = mPerDegLat * cos(samples[0].lat * .pi / 180)
        var distance = 0.0
        var points: [TracePoint] = []

        for (i, s) in samples.enumerated() {
            if i > 0 {
                let p = samples[i - 1]
                let dx = (s.lon - p.lon) * mPerDegLon, dy = (s.lat - p.lat) * mPerDegLat
                distance += (dx * dx + dy * dy).squareRoot()
            }
            let g = meanG(motion, around: s.t) ?? gpsG(samples, at: i)
            points.append(TracePoint(distance: distance, time: s.t - start,
                                     lat: s.lat, lon: s.lon, speed: max(s.speed, 0),
                                     lonG: g.lon, latG: g.lat))
        }
        return LapTrace(number: number, start: start, end: end, points: points)
    }

    private static func interpolate(_ a: GPSSample, _ b: GPSSample, at t: Double) -> GPSSample {
        let f = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * f }
        return GPSSample(t: t, lat: mix(a.lat, b.lat), lon: mix(a.lon, b.lon),
                         speed: mix(max(a.speed, 0), max(b.speed, 0)),
                         course: a.course, hAcc: max(a.hAcc, b.hAcc))
    }

    /// Average phone G-forces within ±0.5 s of `t`, in the same axes as the live
    /// display (phone upright in portrait, screen facing the driver).
    static func meanG(_ motion: [MotionSample], around t: Double,
                      halfWidth: Double = 0.5) -> (lat: Double, lon: Double)? {
        var i = lowerBound(motion, t - halfWidth)
        var lat = 0.0, lon = 0.0, n = 0.0
        while i < motion.count, motion[i].t <= t + halfWidth {
            lat += motion[i].ax
            lon += -motion[i].az
            n += 1; i += 1
        }
        return n > 0 ? (lat / n, lon / n) : nil
    }

    /// G-forces estimated from GPS alone (for recordings without motion data):
    /// change of speed for accel/brake, speed × turn rate for lateral.
    private static func gpsG(_ s: [GPSSample], at i: Int) -> (lat: Double, lon: Double) {
        let a = s[max(i - 1, 0)], b = s[min(i + 1, s.count - 1)]
        let dt = b.t - a.t
        guard dt > 0 else { return (0, 0) }
        let lon = (max(b.speed, 0) - max(a.speed, 0)) / dt / 9.81
        guard a.course >= 0, b.course >= 0 else { return (0, lon) }
        var turn = b.course - a.course
        if turn > 180 { turn -= 360 } else if turn < -180 { turn += 360 }
        let lat = max(s[i].speed, 0) * (turn * .pi / 180) / dt / 9.81
        return (lat, lon)
    }

    private static func lowerBound(_ motion: [MotionSample], _ t: Double) -> Int {
        var lo = 0, hi = motion.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if motion[mid].t < t { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// 50 Hz motion averaged in blocks of 5 (→ 10 Hz), only during timed laps.
    static func ggPoints(_ motion: [MotionSample], during laps: [(Double, Double)],
                         limit: Int = 4000) -> [GGPoint] {
        var points: [GGPoint] = []
        for (start, end) in laps {
            var i = lowerBound(motion, start)
            while i + 5 <= motion.count, motion[i + 4].t <= end {
                let block = motion[i..<(i + 5)]
                points.append(GGPoint(lat: block.map(\.ax).reduce(0, +) / 5,
                                      lon: block.map { -$0.az }.reduce(0, +) / 5))
                i += 5
            }
        }
        guard points.count > limit else { return points }
        let step = Double(points.count) / Double(limit)
        return (0..<limit).map { points[Int(Double($0) * step)] }
    }
}
