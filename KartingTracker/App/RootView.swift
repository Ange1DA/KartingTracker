import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            RecordsView()
                .tabItem { Label("Records", systemImage: "list.bullet.rectangle") }
            ImproveView()
                .tabItem { Label("Improve", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
