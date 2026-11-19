//
//  Formatting.swift
//  KartingTracker
//

import Foundation

/// Formats a lap time in seconds as "m:ss.sss", e.g. 49.25 → "0:49.250".
func formatLap(_ t: Double) -> String {
    let m = Int(t) / 60
    return String(format: "%d:%06.3f", m, t - Double(m * 60))
}
