//
//  RecordingFile.swift
//  KartingTracker
//
//  Raw sensor data recorded during a session.
//  On disk (see SessionStore): Documents/Recordings/<id>/{meta.json, gps.csv, motion.csv}
//  Older recordings are a single Documents/<id>.json holding a SessionFile.
//

import Foundation

struct GPSSample: Codable {
    /// Unix time (s), position (degrees), speed (m/s), course (degrees from north), accuracy (m)
    let t, lat, lon, speed, course, hAcc: Double
    // Added later, so older recordings don't have them
    var alt: Double? = nil         // m above sea level
    var vAcc: Double? = nil        // m
    var speedAcc: Double? = nil    // m/s
    var courseAcc: Double? = nil   // degrees
}

struct MotionSample: Codable {
    /// Unix time (s), user acceleration without gravity (g), rotation rate (rad/s)
    let t, ax, ay, az, gx, gy, gz: Double
    // Added later: gravity direction (g) and phone attitude as a quaternion.
    // Needed to turn phone axes into kart axes when the phone isn't mounted upright.
    var grx: Double? = nil
    var gry: Double? = nil
    var grz: Double? = nil
    var qx: Double? = nil
    var qy: Double? = nil
    var qz: Double? = nil
    var qw: Double? = nil
}

struct SessionFile: Codable {
    let start: Double
    let gps: [GPSSample]
    let motion: [MotionSample]
}

// MARK: - CSV format

/// A sample that can be stored as one line of a CSV file.
protocol CSVRow {
    static var csvColumns: [String] { get }
    var csvValues: [Double?] { get }
    /// Builds a sample from a row; `value` returns the number in the named column.
    init?(csv value: (String) -> Double?)
}

extension CSVRow {
    static var csvHeader: String { csvColumns.joined(separator: ",") }
    var csvLine: String { csvValues.map { $0.map { "\($0)" } ?? "" }.joined(separator: ",") }
}

extension GPSSample: CSVRow {
    static let csvColumns = ["t", "lat", "lon", "alt", "speed", "course",
                             "hAcc", "vAcc", "speedAcc", "courseAcc"]
    var csvValues: [Double?] { [t, lat, lon, alt, speed, course, hAcc, vAcc, speedAcc, courseAcc] }

    init?(csv v: (String) -> Double?) {
        guard let t = v("t"), let lat = v("lat"), let lon = v("lon"), let speed = v("speed"),
              let course = v("course"), let hAcc = v("hAcc") else { return nil }
        self.init(t: t, lat: lat, lon: lon, speed: speed, course: course, hAcc: hAcc,
                  alt: v("alt"), vAcc: v("vAcc"), speedAcc: v("speedAcc"), courseAcc: v("courseAcc"))
    }
}

extension MotionSample: CSVRow {
    static let csvColumns = ["t", "ax", "ay", "az", "gx", "gy", "gz",
                             "grx", "gry", "grz", "qx", "qy", "qz", "qw"]
    var csvValues: [Double?] { [t, ax, ay, az, gx, gy, gz, grx, gry, grz, qx, qy, qz, qw] }

    init?(csv v: (String) -> Double?) {
        guard let t = v("t"), let ax = v("ax"), let ay = v("ay"), let az = v("az"),
              let gx = v("gx"), let gy = v("gy"), let gz = v("gz") else { return nil }
        self.init(t: t, ax: ax, ay: ay, az: az, gx: gx, gy: gy, gz: gz,
                  grx: v("grx"), gry: v("gry"), grz: v("grz"),
                  qx: v("qx"), qy: v("qy"), qz: v("qz"), qw: v("qw"))
    }
}
