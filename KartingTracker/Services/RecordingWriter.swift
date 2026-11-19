//
//  RecordingWriter.swift
//  KartingTracker
//
//  Appends samples to the recording's CSV files while recording, so if the app
//  crashes or is closed, at most the last couple of seconds are lost.
//

import Foundation

final class RecordingWriter {
    static let flushInterval = 2.0   // s between writes to disk

    let id: String
    private let start: Double
    private let gpsFile: FileHandle
    private let motionFile: FileHandle
    private var gpsBuffer = ""
    private var motionBuffer = ""
    private var lastFlush = Date()

    init(start: Double) throws {
        self.start = start
        id = "session_\(Int(start))"
        let dir = SessionStore.folder(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try SessionStore.writeMeta(.init(id: id, start: start, end: nil))
        gpsFile = try Self.create(dir.appendingPathComponent("gps.csv"), header: GPSSample.csvHeader)
        motionFile = try Self.create(dir.appendingPathComponent("motion.csv"), header: MotionSample.csvHeader)
    }

    private static func create(_ url: URL, header: String) throws -> FileHandle {
        try Data((header + "\n").utf8).write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        return handle
    }

    func append(_ sample: GPSSample) {
        gpsBuffer += sample.csvLine + "\n"
        flushIfDue()
    }

    func append(_ sample: MotionSample) {
        motionBuffer += sample.csvLine + "\n"
        flushIfDue()
    }

    private func flushIfDue() {
        if Date().timeIntervalSince(lastFlush) >= Self.flushInterval { flush() }
    }

    func flush() {
        write(&gpsBuffer, to: gpsFile)
        write(&motionBuffer, to: motionFile)
        lastFlush = Date()
    }

    private func write(_ buffer: inout String, to file: FileHandle) {
        guard !buffer.isEmpty else { return }
        do {
            try file.write(contentsOf: Data(buffer.utf8))
            buffer = ""
        } catch {
            print("Write failed:", error)
        }
    }

    /// Writes what's left and records the end time.
    func finish(end: Double) {
        flush()
        try? gpsFile.close()
        try? motionFile.close()
        try? SessionStore.writeMeta(.init(id: id, start: start, end: end))
    }
}
