//
//  RecordingFile.swift
//  KartingTracker
//
//  Raw sensor data written to Documents/session_<start>.json by the Recorder.
//

import Foundation

struct GPSSample: Codable {
    let t, lat, lon, speed, course, hAcc: Double
}

struct MotionSample: Codable {
    let t, ax, ay, az, gx, gy, gz: Double
}

struct SessionFile: Codable {
    let start: Double
    let gps: [GPSSample]
    let motion: [MotionSample]
}
