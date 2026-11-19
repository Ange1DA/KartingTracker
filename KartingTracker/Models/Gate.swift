//
//  Gate.swift
//  KartingTracker
//

import Foundation

/// A virtual finish line: a line through (lat, lon), perpendicular to `course`.
/// Only passes in the direction of `course` count.
struct Gate: Equatable {
    var lat: Double
    var lon: Double
    var course: Double   // degrees clockwise from north
}
