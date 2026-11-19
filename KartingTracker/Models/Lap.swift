//
//  Lap.swift
//  KartingTracker
//
//  A single timed lap inside a Session.
//

import Foundation
import SwiftData

@Model
final class Lap {
    var number: Int
    var time: Double
    /// Unix times when the lap started and ended, to cut this lap out of the raw
    /// recording. Missing for sessions saved before these were stored.
    var start: Double?
    var end: Double?
    /// LapKind raw value; missing (practice) for sessions saved before lap types
    var kind: String?

    var lapKind: LapKind { kind.flatMap(LapKind.init) ?? .practice }

    init(number: Int, time: Double, start: Double? = nil, end: Double? = nil,
         kind: LapKind = .practice) {
        self.number = number
        self.time = time
        self.start = start
        self.end = end
        self.kind = kind.rawValue
    }
}
