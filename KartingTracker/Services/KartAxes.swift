//
//  KartAxes.swift
//  KartingTracker
//
//  Turns phone accelerations into kart G-forces (accel/brake and lateral)
//  whatever way the phone is carried: mounted, in a chest harness or in a pocket.
//
//  1. The phone's attitude rotates each acceleration into a level frame that
//     stays still while the phone moves; only the horizontal part is kept.
//  2. That level frame points in an unknown compass direction (and slowly
//     drifts), so it's lined up with the acceleration GPS measures (change of
//     velocity between fixes), refitted over the last minute or so.
//  3. The GPS course says which way the kart points, which splits the result
//     into accel/brake and lateral.
//
//  Lining up with GPS also settles the signs: + is always accelerating or
//  turning right, whatever conventions the phone's sensors use.
//

import Foundation
import simd

enum KartAxes {
    /// Horizontal acceleration (g) in the level frame, or nil when the sample has
    /// no attitude (older recordings). Apple's docs leave the direction of the
    /// attitude rotation unclear, so callers try both (`inverse`) and keep the
    /// one that matches GPS.
    static func level(_ m: MotionSample, inverse: Bool) -> SIMD2<Double>? {
        guard let x = m.qx, let y = m.qy, let z = m.qz, let w = m.qw else { return nil }
        let q = simd_quatd(ix: x, iy: y, iz: z, r: w)
        guard abs(q.length - 1) < 0.1 else { return nil }
        let a = (inverse ? q.inverse : q).act(SIMD3(m.ax, m.ay, m.az))
        return SIMD2(a.x, a.y)
    }

    /// Velocity (m/s) as east/north.
    static func velocity(_ s: GPSSample) -> SIMD2<Double> {
        let c = s.course * .pi / 180
        return SIMD2(sin(c), cos(c)) * max(s.speed, 0)
    }

    /// Acceleration (g) between two GPS fixes as east/north, only while moving
    /// fast enough for the course to be trustworthy.
    static func gpsAccel(_ a: GPSSample, _ b: GPSSample) -> SIMD2<Double>? {
        let dt = b.t - a.t
        guard dt > 0.2, dt <= 3, a.course >= 0, b.course >= 0,
              a.speed > 3, b.speed > 3 else { return nil }
        return (velocity(b) - velocity(a)) / dt / 9.81
    }

    /// Splits an east/north acceleration into kart axes for a kart heading `course` (°).
    static func kartG(_ w: SIMD2<Double>, course: Double) -> (lat: Double, lon: Double) {
        let c = course * .pi / 180
        let forward = SIMD2(sin(c), cos(c)), right = SIMD2(cos(c), -sin(c))
        return (simd_dot(w, right), simd_dot(w, forward))
    }

    /// Change of course from `a` to `b` in degrees, −180…180 (+ = turning right).
    static func turn(from a: Double, to b: Double) -> Double {
        var d = b - a
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return d
    }

    static func lowerBound(_ values: [Double], _ x: Double) -> Int {
        var lo = 0, hi = values.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if values[mid] < x { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

/// The rotation that best lines up level-frame accelerations with GPS ones
/// (a least-squares fit of a single angle).
struct YawFit {
    var dot = 0.0, cross = 0.0, phone = 0.0, gps = 0.0, count = 0.0

    mutating func add(phone h: SIMD2<Double>, gps g: SIMD2<Double>) {
        dot += simd_dot(h, g)
        cross += h.x * g.y - h.y * g.x
        phone += simd_length_squared(h)
        gps += simd_length_squared(g)
        count += 1
    }

    /// Fades older pairs out so the fit follows slow drift.
    mutating func fade(_ f: Double) {
        dot *= f; cross *= f; phone *= f; gps *= f; count *= f
    }

    static func - (a: YawFit, b: YawFit) -> YawFit {
        YawFit(dot: a.dot - b.dot, cross: a.cross - b.cross, phone: a.phone - b.phone,
               gps: a.gps - b.gps, count: a.count - b.count)
    }

    var angle: Double { atan2(cross, dot) }

    /// 1 when phone and GPS agree perfectly, around 0 when they're unrelated.
    var quality: Double {
        let d = (phone * gps).squareRoot()
        return d > 0 ? (dot * dot + cross * cross).squareRoot() / d : 0
    }

    var isReliable: Bool { count >= 8 && quality >= 0.6 }

    /// Level-frame acceleration → east/north.
    func toWorld(_ h: SIMD2<Double>) -> SIMD2<Double> {
        let c = cos(angle), s = sin(angle)
        return SIMD2(c * h.x - s * h.y, s * h.x + c * h.y)
    }
}

/// A whole recording's motion in kart axes, for analysis after the session.
struct KartMotion {
    /// Seconds either side of a moment used to line up phone and GPS
    static let window = 45.0

    private let times: [Double]
    private let sums: [SIMD2<Double>]   // running sum of level accelerations
    private let pairTimes: [Double]
    private let fitSums: [YawFit]       // running sum of phone/GPS pairs
    private let fixes: [GPSSample]      // GPS fixes with a valid course
    private let fixTimes: [Double]
    /// Average fit quality over the session (0…1)
    let score: Double

    /// nil when the recording has no attitude or the phone never matches GPS
    /// (then G-forces are estimated from GPS alone).
    init?(motion: [MotionSample], gps: [GPSSample]) {
        let candidates = [false, true].compactMap { KartMotion(motion: motion, gps: gps, inverse: $0) }
        guard let best = candidates.max(by: { $0.score < $1.score }), best.score >= 0.6 else { return nil }
        self = best
    }

    private init?(motion: [MotionSample], gps: [GPSSample], inverse: Bool) {
        var times: [Double] = [], sums: [SIMD2<Double>] = [.zero]
        for m in motion {
            guard let h = KartAxes.level(m, inverse: inverse) else { continue }
            times.append(m.t)
            sums.append(sums[sums.count - 1] + h)
        }
        guard times.count >= 100 else { return nil }

        var pairTimes: [Double] = [], fitSums = [YawFit()]
        for (a, b) in zip(gps, gps.dropFirst()) {
            guard let g = KartAxes.gpsAccel(a, b) else { continue }
            let lo = KartAxes.lowerBound(times, a.t), hi = KartAxes.lowerBound(times, b.t)
            guard hi - lo >= 5 else { continue }
            var fit = fitSums[fitSums.count - 1]
            fit.add(phone: (sums[hi] - sums[lo]) / Double(hi - lo), gps: g)
            pairTimes.append((a.t + b.t) / 2)
            fitSums.append(fit)
        }
        guard pairTimes.count >= 10 else { return nil }

        self.times = times
        self.sums = sums
        self.pairTimes = pairTimes
        self.fitSums = fitSums
        fixes = gps.filter { $0.course >= 0 }
        fixTimes = fixes.map(\.t)
        score = pairTimes.map { Self.fit(at: $0, pairTimes, fitSums).quality }
            .reduce(0, +) / Double(pairTimes.count)
    }

    private static func fit(at t: Double, _ pairTimes: [Double], _ fitSums: [YawFit]) -> YawFit {
        let lo = KartAxes.lowerBound(pairTimes, t - window)
        let hi = KartAxes.lowerBound(pairTimes, t + window)
        return fitSums[hi] - fitSums[lo]
    }

    /// Kart G-forces averaged over `t` ± `halfWidth`, or nil where they can't be trusted.
    func g(around t: Double, halfWidth: Double = 0.5) -> (lat: Double, lon: Double)? {
        let lo = KartAxes.lowerBound(times, t - halfWidth)
        let hi = KartAxes.lowerBound(times, t + halfWidth)
        let fit = Self.fit(at: t, pairTimes, fitSums)
        guard hi > lo, fit.isReliable, let course = course(at: t) else { return nil }
        let h = (sums[hi] - sums[lo]) / Double(hi - lo)
        return KartAxes.kartG(fit.toWorld(h), course: course)
    }

    /// Kart heading at `t`, interpolated between GPS fixes.
    private func course(at t: Double) -> Double? {
        let i = KartAxes.lowerBound(fixTimes, t)
        if i > 0, i < fixes.count, fixes[i].t > fixes[i - 1].t, fixes[i].t - fixes[i - 1].t <= 3 {
            let a = fixes[i - 1], b = fixes[i]
            let f = (t - a.t) / (b.t - a.t)
            return a.course + KartAxes.turn(from: a.course, to: b.course) * f
        }
        let near = [i - 1, i].filter { fixes.indices.contains($0) }
            .min { abs(fixes[$0].t - t) < abs(fixes[$1].t - t) }
        guard let near, abs(fixes[near].t - t) <= 1.5 else { return nil }
        return fixes[near].course
    }
}

/// The same idea, updated sample by sample while recording (for the live display).
struct LiveKartG {
    private var fits = [YawFit(), YawFit()]           // attitude used as-is / inverted
    private var sums = [SIMD2<Double>.zero, .zero]    // level acceleration since the last fix
    private var counts = [0, 0]
    private var smooth = [SIMD2<Double>.zero, .zero]  // low-pass filtered, for display
    private var lastFix: GPSSample?
    private var heading: Double?                      // last valid GPS course
    private var turnRate = 0.0                        // °/s, to follow the heading between fixes

    mutating func add(_ m: MotionSample) {
        for d in 0..<2 {
            guard let h = KartAxes.level(m, inverse: d == 1) else { continue }
            sums[d] += h
            counts[d] += 1
            smooth[d] += 0.15 * (h - smooth[d])
        }
    }

    mutating func add(_ fix: GPSSample) {
        if let prev = lastFix {
            if let g = KartAxes.gpsAccel(prev, fix) {
                for d in 0..<2 where counts[d] >= 5 {
                    fits[d].fade(0.98)   // older pairs count less (≈ last minute)
                    fits[d].add(phone: sums[d] / Double(counts[d]), gps: g)
                }
            }
            let dt = fix.t - prev.t
            turnRate = prev.course >= 0 && fix.course >= 0 && dt > 0 && dt <= 3
                ? KartAxes.turn(from: prev.course, to: fix.course) / dt : 0
        }
        if fix.course >= 0 { heading = fix.course }
        sums = [.zero, .zero]
        counts = [0, 0]
        lastFix = fix
    }

    /// Kart G-forces now, or nil until enough driving has lined phone and GPS up.
    func current(at t: Double) -> (lat: Double, lon: Double)? {
        let d = fits[1].quality > fits[0].quality ? 1 : 0
        guard fits[d].isReliable, let heading, let fix = lastFix else { return nil }
        let course = heading + turnRate * min(max(t - fix.t, 0), 1.5)
        return KartAxes.kartG(fits[d].toWorld(smooth[d]), course: course)
    }
}
