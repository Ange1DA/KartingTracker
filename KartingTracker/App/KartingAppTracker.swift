import SwiftUI
import SwiftData

@main
struct KartingTrackerApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Session.self, Lap.self])
    }
}
