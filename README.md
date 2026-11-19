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
   On race days `SessionPhases` spots the race start: a stop in the first 5 minutes
   after driving off, followed by a full lap back past that spot (the grid). Laps
   are then timed from there and split into qualifying, formation and race laps.
4. The result is stored as a `Session` with its `Lap`s and shows up in **Records**
   and **Improve**. Recordings without a saved session (e.g. after a crash) are
   recovered automatically on the next launch.
5. **Lap analysis** (`LapAnalysis`) reloads the raw data to show sectors, the ideal
   lap, speed and gap charts, a satellite track map and a G-G diagram.

## Carrying the phone

The phone can be mounted, in a chest harness or in a pocket. `KartAxes` turns the
phone's accelerations into kart G-forces whatever way it's held: the attitude
rotates them into a level frame, which is lined up with the acceleration measured
by GPS, and the GPS course splits them into accel/brake and lateral. The live
display needs a few corners to line up; until then it assumes the phone is
upright in portrait with the screen toward the driver. Recordings made without
attitude data get G-forces estimated from GPS alone.

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
