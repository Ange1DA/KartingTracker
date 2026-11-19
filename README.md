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
│   └── Improve/            Per-track stats and coaching suggestions
├── Components/             Small views shared by several screens
├── Models/                 Data saved by the app (Session, Lap, Gate, raw recording)
├── Services/               Non-UI logic: sensor recording and lap detection
├── Utilities/              Small helpers (e.g. lap time formatting)
├── Assets.xcassets/        App icon and colors
└── Info.plist              Background location permission
```

## How a session flows through the code

1. **Home** → "New session" opens `RecordView`.
2. `Recorder` collects GPS and motion data and saves it as a JSON file.
3. On Stop, `SaveSessionView` asks for the track name and uses `LapDetector`
   to find laps by timing each pass through a virtual finish line (`Gate`).
4. The result is stored as a `Session` with its `Lap`s and shows up in **Records**
   and **Improve**.
