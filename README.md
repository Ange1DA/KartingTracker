# Karting Tracker

An iOS app that records karting sessions with the phone's GPS and motion sensors,
times your laps automatically, and keeps a history of your sessions per track.

## Project structure

```
KartingTracker/
├── App/                    App entry point and the main tab bar
│   ├── KartingTrackerApp.swift
│   └── RootView.swift
├── Features/               One folder per screen/area of the app
│   ├── Home/               Latest sessions + "New session" button
│   ├── Recording/          Live recording screen and saving a session
│   ├── Records/            List of all sessions and session details
│   ├── Analysis/           Lap analysis: sectors, speed, gap, track map, G-G diagram
│   └── Improve/            Per-track stats and coaching suggestions
├── Components/             Small views shared by several screens
├── Models/                 Data saved by the app (Session, Lap, Gate, raw recording)
├── Services/               Non-UI logic: recording, storage, lap detection, analysis
├── Utilities/              Small helpers (e.g. lap time formatting)
├── Assets.xcassets/        App icon and colors
└── Info.plist              Background location permission
```

## How a session flows through the code

1. **Home** → "New session" opens `RecordView`.
2. `Recorder` collects GPS and motion data; `RecordingWriter` writes it to disk
   every 2 s while recording, so a crash loses at most a couple of seconds.
3. On Stop, `SaveSessionView` asks for the track name (or discards the recording) and uses `LapDetector`
   to find laps by timing each pass through a virtual finish line (`Gate`).
4. The result is stored as a `Session` with its `Lap`s and shows up in **Records**
   and **Improve**. Recordings without a saved session (e.g. after a crash) are
   recovered automatically on the next launch.
5. **Lap analysis** (`LapAnalysis`) reloads the raw data to show sectors, the ideal
   lap, speed and gap charts, a satellite track map and a G-G diagram.

## Recorded data

Each session is stored in `Documents/Recordings/session_<start>/`, visible in the
Files app under *On My iPhone → Karting Tracker*:

| File | Contents |
|---|---|
| `meta.json` | Start and end time (Unix seconds) |
| `gps.csv` | ~1 Hz: `t, lat, lon, alt, speed (m/s), course (°), hAcc, vAcc, speedAcc, courseAcc` |
| `motion.csv` | 50 Hz: `t`, user acceleration `ax ay az` (g), rotation `gx gy gz` (rad/s), gravity `grx gry grz`, attitude quaternion `qx qy qz qw` |

Each lap's `start`/`end` time is stored with the session, so any lap can be cut
out of these files, for example for analysis in Python or Excel.
