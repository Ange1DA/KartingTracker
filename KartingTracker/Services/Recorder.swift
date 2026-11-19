//
//  Recorder.swift
//  KartingTracker
//

import Combine
import CoreLocation
import CoreMotion
import UIKit

final class Recorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let lm = CLLocationManager()
    private let motion = CMMotionManager()
    private var gps: [GPSSample] = []
    private var imu: [MotionSample] = []
    private var startTime = 0.0
    private var writer: RecordingWriter?

    @Published var speedKmh = 0.0

    // G-forces
    @Published var lateralG = 0.0
    @Published var longitudinalG = 0.0
    @Published var totalG = 0.0
    @Published var peakG = 0.0

    private var fLat = 0.0, fLon = 0.0, fTot = 0.0
    private var tick = 0

    @Published var isRecording = false
    /// ID of the most recent finished recording on disk (see SessionStore)
    @Published var recordingID: String?
    /// The most recent finished recording, kept in memory so it can be turned into a Session
    @Published var lastRecording: SessionFile?

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        lm.activityType = .automotiveNavigation
        lm.allowsBackgroundLocationUpdates = true
        lm.pausesLocationUpdatesAutomatically = false
        lm.showsBackgroundLocationIndicator = true
        lm.requestWhenInUseAuthorization()
    }

    func start() {
        gps.removeAll(); imu.removeAll()
        recordingID = nil; lastRecording = nil
        peakG = 0
        fLat = 0; fLon = 0; fTot = 0; tick = 0
        startTime = Date().timeIntervalSince1970
        do {
            writer = try RecordingWriter(start: startTime)
        } catch {
            writer = nil   // still recorded in memory and saved as one file on Stop
            print("Could not create recording files:", error)
        }
        UIApplication.shared.isIdleTimerDisabled = true   // keep screen on
        lm.startUpdatingLocation()

        // Convert motion timestamps (time since boot) to Unix time so they sync with GPS
        let bootOffset = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        motion.deviceMotionUpdateInterval = 1.0 / 50
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            let a = m.userAcceleration, g = m.gravity, q = m.attitude.quaternion

            // Save raw data at the full 50 Hz
            let sample = MotionSample(
                t: m.timestamp + bootOffset,
                ax: a.x, ay: a.y, az: a.z,
                gx: m.rotationRate.x, gy: m.rotationRate.y, gz: m.rotationRate.z,
                grx: g.x, gry: g.y, grz: g.z,
                qx: q.x, qy: q.y, qz: q.z, qw: q.w)
            self.imu.append(sample)
            self.writer?.append(sample)

            // Smooth for display (low-pass filter)
            let k = 0.15
            self.fLat += k * (a.x - self.fLat)
            self.fLon += k * (-a.z - self.fLon)   // forward = -z (portrait, screen toward driver)
            self.fTot += k * ((a.x*a.x + a.y*a.y + a.z*a.z).squareRoot() - self.fTot)

            // Update the UI at ~10 Hz
            self.tick += 1
            if self.tick % 5 == 0 {
                self.lateralG = self.fLat
                self.longitudinalG = self.fLon
                self.totalG = self.fTot
                self.peakG = max(self.peakG, self.fTot)
            }
        }
        isRecording = true
    }

    func stop() {
        lm.stopUpdatingLocation()
        motion.stopDeviceMotionUpdates()
        UIApplication.shared.isIdleTimerDisabled = false
        isRecording = false

        let file = SessionFile(start: startTime, gps: gps, motion: imu)
        if let writer {
            writer.finish(end: Date().timeIntervalSince1970)
            recordingID = writer.id
        } else {
            recordingID = SessionStore.saveJSON(file)
        }
        writer = nil
        lastRecording = file
    }

    /// Deletes the last recording from disk (the user chose not to keep it).
    func discardLast() {
        if let recordingID { SessionStore.delete(recordingID) }
        recordingID = nil
        lastRecording = nil
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        for l in locs where l.horizontalAccuracy >= 0 {
            speedKmh = max(l.speed, 0) * 3.6
            let sample = GPSSample(
                t: l.timestamp.timeIntervalSince1970,
                lat: l.coordinate.latitude, lon: l.coordinate.longitude,
                speed: l.speed, course: l.course, hAcc: l.horizontalAccuracy,
                alt: l.altitude, vAcc: l.verticalAccuracy,
                speedAcc: l.speedAccuracy, courseAcc: l.courseAccuracy)
            gps.append(sample)
            writer?.append(sample)
        }
    }
}
