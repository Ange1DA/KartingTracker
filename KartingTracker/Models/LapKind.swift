//
//  LapKind.swift
//  KartingTracker
//
//  What part of a session a lap belongs to, and a lap's time window.
//

import Foundation

enum LapKind: String, CaseIterable {
    case practice, qualifying, formation, race

    var title: String {
        switch self {
        case .practice: "Laps"
        case .qualifying: "Qualifying"
        case .formation: "Formation"
        case .race: "Race"
        }
    }

    /// Formation laps are driven slowly on purpose, so they never count as a best lap.
    var countsForBest: Bool { self != .formation }

    /// "Lap 3", "Q3", "Formation 1", "Race lap 3"
    func label(_ n: Int) -> String {
        switch self {
        case .practice: "Lap \(n)"
        case .qualifying: "Q\(n)"
        case .formation: "Formation \(n)"
        case .race: "Race lap \(n)"
        }
    }

    /// Short form for tables: "3", "Q3", "F1", "R3"
    func shortLabel(_ n: Int) -> String {
        switch self {
        case .practice: "\(n)"
        case .qualifying: "Q\(n)"
        case .formation: "F\(n)"
        case .race: "R\(n)"
        }
    }
}

/// One lap's time window in a recording.
struct LapWindow {
    let start: Double   // Unix time
    let end: Double
    let kind: LapKind

    var time: Double { end - start }

    /// Every lap of a plain detection, all counted as practice.
    static func practice(_ d: LapDetection) -> [LapWindow] {
        zip(d.crossings, d.crossings.dropFirst()).map { LapWindow(start: $0, end: $1, kind: .practice) }
    }
}

extension Array where Element == LapWindow {
    /// Number of each lap within its kind (Q1, Q2, … Race lap 1, …), in order.
    var numbersInKind: [Int] {
        var seen: [LapKind: Int] = [:]
        return map { w in
            seen[w.kind, default: 0] += 1
            return seen[w.kind]!
        }
    }
}
