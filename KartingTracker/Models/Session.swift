//
//  Session.swift
//  KartingTracker
//
//  One karting session saved in Records: where and when, plus its laps.
//

import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var trackName: String
    var kartClass: String
    var notes: String
    var bestLap: Double?
    @Relationship(deleteRule: .cascade) var laps: [Lap] = []

    /// Finish line used to time the laps, reused for later sessions at the same track
    var gateLat: Double?
    var gateLon: Double?
    var gateCourse: Double?
    /// File name of the raw sensor recording in Documents, if this came from the recorder
    var rawFile: String?

    var gate: Gate? {
        get {
            guard let gateLat, let gateLon, let gateCourse else { return nil }
            return Gate(lat: gateLat, lon: gateLon, course: gateCourse)
        }
        set {
            gateLat = newValue?.lat
            gateLon = newValue?.lon
            gateCourse = newValue?.course
        }
    }

    init(date: Date, trackName: String, kartClass: String = "", notes: String = "") {
        self.date = date
        self.trackName = trackName
        self.kartClass = kartClass
        self.notes = notes
    }
}

extension Session {
    /// True if this session holds the fastest lap ever recorded at its track.
    func isPersonalBest(among all: [Session]) -> Bool {
        guard let lap = bestLap else { return false }
        let best = all.filter { $0.trackName == trackName }.compactMap(\.bestLap).min()
        return lap == best
    }

    /// Replaces the laps, numbered 1…N in time order, and remembers the finish line.
    func applyLaps(_ windows: [LapWindow], gate: Gate) {
        laps = windows.sorted { $0.start < $1.start }.enumerated().map { i, w in
            Lap(number: i + 1, time: w.time, start: w.start, end: w.end, kind: w.kind)
        }
        bestLap = laps.filter(\.lapKind.countsForBest).map(\.time).min()
        self.gate = gate
    }

    /// Laps found by LapDetector, all counted as practice.
    func applyLaps(_ detection: LapDetection) {
        applyLaps(LapWindow.practice(detection), gate: detection.gate)
    }

    /// Times the laps of a recording: from the grid stop when a race start is
    /// found (and `useGridStart`), otherwise at `gate` or a line picked from the trace.
    func applyLaps(from gps: [GPSSample], gate: Gate? = nil, useGridStart: Bool = true) {
        if useGridStart, let phases = SessionPhases.detect(gps) {
            applyLaps(phases.laps, gate: phases.gate)
        } else if let detection = LapDetector.detect(gps, gate: gate) {
            applyLaps(detection)
        }
    }
}
