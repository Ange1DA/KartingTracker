//
//  Model.swift
//  KartingTracker
//
//  Created by Angel De Anda on 10/10/26.
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

@Model
final class Lap {
    var number: Int
    var time: Double

    init(number: Int, time: Double) {
        self.number = number
        self.time = time
    }
}
