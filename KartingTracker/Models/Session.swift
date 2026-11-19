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
}
