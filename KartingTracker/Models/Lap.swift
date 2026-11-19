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

    init(number: Int, time: Double) {
        self.number = number
        self.time = time
    }
}
