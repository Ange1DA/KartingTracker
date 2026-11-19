//
//  SessionStore.swift
//  KartingTracker
//
//  Owns the raw sensor recordings on disk. A recording is identified by the
//  name stored in `Session.rawFile`:
//    "session_<start>"       → folder Documents/Recordings/session_<start>/
//                              with meta.json, gps.csv and motion.csv
//    "session_<start>.json"  → older single-file recording in Documents/
//
//  The Recordings folder is visible in the Files app (On My iPhone → Karting Tracker).
//

import Foundation
import SwiftData

enum SessionStore {
    struct Meta: Codable {
        var id: String
        var start: Double
        var end: Double?
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var recordingsDir: URL {
        documents.appendingPathComponent("Recordings", isDirectory: true)
    }
    static func folder(_ id: String) -> URL {
        recordingsDir.appendingPathComponent(id, isDirectory: true)
    }
    private static func isLegacy(_ id: String) -> Bool { id.hasSuffix(".json") }

    // MARK: Reading

    static func load(_ id: String) -> SessionFile? {
        if isLegacy(id) {
            guard let data = try? Data(contentsOf: documents.appendingPathComponent(id)) else { return nil }
            return try? JSONDecoder().decode(SessionFile.self, from: data)
        }
        let dir = folder(id)
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("meta.json")),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
        return SessionFile(start: meta.start,
                           gps: readCSV(dir.appendingPathComponent("gps.csv")),
                           motion: readCSV(dir.appendingPathComponent("motion.csv")))
    }

    /// Reads a CSV file written by RecordingWriter. Skips rows that don't parse,
    /// e.g. a last line cut short because the app was killed while writing.
    static func readCSV<Row: CSVRow>(_ url: URL) -> [Row] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var lines = text.split(whereSeparator: \.isNewline)
        if !text.hasSuffix("\n"), !lines.isEmpty { lines.removeLast() }   // incomplete last line
        guard !lines.isEmpty else { return [] }

        let header = lines.removeFirst().split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let column = Dictionary(header.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return lines.compactMap { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == header.count else { return nil }
            return Row(csv: { name in column[name].flatMap { Double(fields[$0]) } })
        }
    }

    /// Files to share/export for a recording
    static func files(_ id: String) -> [URL] {
        if isLegacy(id) { return [documents.appendingPathComponent(id)] }
        return ["meta.json", "gps.csv", "motion.csv"].map { folder(id).appendingPathComponent($0) }
    }

    /// IDs of every recording on disk
    static func allIDs() -> [String] {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(atPath: recordingsDir.path)) ?? []
        let legacy = (try? fm.contentsOfDirectory(atPath: documents.path)) ?? []
        return folders.filter { $0.hasPrefix("session_") }
            + legacy.filter { $0.hasPrefix("session_") && $0.hasSuffix(".json") }
    }

    // MARK: Writing

    static func writeMeta(_ meta: Meta) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(meta).write(to: folder(meta.id).appendingPathComponent("meta.json"),
                                       options: .atomic)
    }

    /// Fallback when the recording folder couldn't be created: save everything at once.
    static func saveJSON(_ file: SessionFile) -> String? {
        let id = "session_\(Int(file.start)).json"
        do {
            try JSONEncoder().encode(file).write(to: documents.appendingPathComponent(id))
            return id
        } catch {
            print("Save failed:", error)
            return nil
        }
    }

    static func delete(_ id: String) {
        let url = isLegacy(id) ? documents.appendingPathComponent(id) : folder(id)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Recovery

    /// Creates a Session for every recording on disk that has none, e.g. because the
    /// app was closed or crashed before the session was saved. Nothing is lost silently.
    @MainActor
    static func recoverOrphans(into context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let known = Set(sessions.compactMap(\.rawFile))

        for id in allIDs() where !known.contains(id) {
            guard let recording = load(id), !recording.gps.isEmpty else { continue }
            let s = Session(date: Date(timeIntervalSince1970: recording.start),
                            trackName: "Recovered session",
                            notes: "Recovered automatically: this recording was never saved.")
            s.rawFile = id
            if let detection = LapDetector.detect(recording.gps) { s.applyLaps(detection) }
            context.insert(s)
        }
    }
}
