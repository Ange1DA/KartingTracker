//
//  SessionPhases.swift
//  KartingTracker
//
//  Splits a race-day session into qualifying, formation and race laps.
//
//  Rule: if the kart stops within the first few minutes after driving off and
//  then completes a full lap back past that spot, the stop was the race start
//  (the grid). Laps are then timed from that spot: race lap 1 starts when the
//  kart pulls away. Laps before the kart first stopped on the grid are
//  qualifying; laps between two grid stops are formation laps. A stop that
//  isn't followed by a full lap (e.g. in the pits) doesn't start the race.
//

import Foundation

struct SessionPhases {
    /// The grid stop must begin within this many seconds after the kart first drives off
    static let window = 5 * 60.0
    static let stopSpeed = 1.5      // m/s; slower than this counts as standing still
    static let minStop = 5.0        // s standing still to count as a stop
    static let driveOff = 3.0       // s above LapDetector.minSpeed to count as driving off
    static let gridSpread = 30.0    // m; stops this close to the race start are on the grid

    struct Stop {
        let start, end: Double      // first and last standing-still fix
        let lat, lon: Double
        let departCourse: Double    // heading when pulling away

        var gate: Gate { Gate(lat: lat, lon: lon, course: departCourse) }
    }

    /// Finish line at the race-start spot
    let gate: Gate
    /// When the kart pulled away from the grid (Unix time)
    let raceStart: Double
    let laps: [LapWindow]

    /// nil when no race start is found (a practice session).
    static func detect(_ gps: [GPSSample]) -> SessionPhases? {
        let pts = gps.filter { $0.hAcc >= 0 && $0.hAcc <= LapDetector.maxAccuracy }
            .sorted { $0.t < $1.t }
        guard let off = driveOffTime(pts) else { return nil }
        let stops = findStops(pts, after: off).filter { $0.start <= off + window }

        // Stops followed by a full lap back past the same spot, before stopping again
        let starts = stops.indices.filter { i in
            let stop = stops[i]
            let next = i + 1 < stops.count ? stops[i + 1].start : .infinity
            let after = pts.filter { $0.t >= stop.end && $0.t <= next }
            guard let d = LapDetector.detect(after, gate: stop.gate) else { return false }
            return d.crossings.contains { $0 >= stop.end + LapDetector.minLapTime }
        }
        guard let raceIndex = starts.last else { return nil }
        let race = stops[raceIndex]
        let gate = race.gate

        // First time the kart stopped on the grid (earlier than the race start if
        // there was a formation lap)
        let gridStop = stops[...raceIndex].first { distance(race, $0) <= gridSpread } ?? race

        let all = stops.map { ($0.start, $0.end) }
        let crossings = LapDetector.detect(pts, gate: gate)?.crossings ?? []

        // Qualifying: full laps before the first grid stop
        let quali = timedLaps(crossings.filter { $0 < gridStop.start }, kind: .qualifying, stops: all)

        // Formation: from leaving the grid the first time until stopping there again
        var formation: [LapWindow] = []
        if gridStop.start < race.start {
            let inner = crossings.filter {
                $0 > gridStop.end + LapDetector.minLapTime && $0 < race.start - LapDetector.minLapTime
            }
            formation = timedLaps([gridStop.end] + inner + [race.start], kind: .formation, stops: [])
        }

        // Race: from pulling away, then every crossing
        let raceCrossings = [race.end] + crossings.filter { $0 > race.end + LapDetector.minLapTime }
        let raceLaps = timedLaps(raceCrossings, kind: .race, stops: all)

        return SessionPhases(gate: gate, raceStart: race.end, laps: quali + formation + raceLaps)
    }

    /// Laps between consecutive boundaries, leaving out any lap with a stop in it
    /// (a pit stop isn't a lap time).
    private static func timedLaps(_ bounds: [Double], kind: LapKind,
                                  stops: [(Double, Double)]) -> [LapWindow] {
        zip(bounds, bounds.dropFirst()).compactMap { a, b in
            let hasStop = stops.contains { $0.0 > a && $0.1 < b }
            return hasStop ? nil : LapWindow(start: a, end: b, kind: kind)
        }
    }

    /// Start of the first stretch driven above `LapDetector.minSpeed` for `driveOff` seconds.
    static func driveOffTime(_ pts: [GPSSample]) -> Double? {
        var runStart: Double?
        for p in pts {
            if p.speed > LapDetector.minSpeed {
                let s = runStart ?? p.t
                runStart = s
                if p.t - s >= driveOff { return s }
            } else {
                runStart = nil
            }
        }
        return nil
    }

    /// Stretches standing still for at least `minStop` seconds after `t`,
    /// with the heading the kart had when it pulled away.
    static func findStops(_ pts: [GPSSample], after t: Double) -> [Stop] {
        var stops: [Stop] = []
        var run: [GPSSample] = []

        func close(at i: Int) {
            defer { run.removeAll() }
            guard let first = run.first, let last = run.last, last.t - first.t >= minStop else { return }
            // Heading once moving again, within 30 s
            guard let depart = pts[i...].first(where: {
                $0.speed > LapDetector.minSpeed && $0.course >= 0
            }), depart.t - last.t <= 30 else { return }
            let n = Double(run.count)
            stops.append(Stop(start: first.t, end: last.t,
                              lat: run.map(\.lat).reduce(0, +) / n,
                              lon: run.map(\.lon).reduce(0, +) / n,
                              departCourse: depart.course))
        }

        for (i, p) in pts.enumerated() where p.t >= t {
            if p.speed < stopSpeed {   // negative = unknown, which iOS reports when standing still
                run.append(p)
            } else if !run.isEmpty {
                close(at: i)
            }
        }
        return stops   // a stop at the very end (back in the pits) has no departure, so it's dropped
    }

    private static func distance(_ a: Stop, _ b: Stop) -> Double {
        let mPerDegLat = 111_320.0
        let dx = (a.lon - b.lon) * mPerDegLat * cos(a.lat * .pi / 180)
        let dy = (a.lat - b.lat) * mPerDegLat
        return (dx * dx + dy * dy).squareRoot()
    }
}
