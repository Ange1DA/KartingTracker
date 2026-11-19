import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var showRecorder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest records").font(.title2.bold())

                    if sessions.isEmpty {
                        ContentUnavailableView("No sessions yet",
                            systemImage: "flag.checkered",
                            description: Text("Record your first session below."))
                    } else {
                        ForEach(sessions.prefix(3)) { s in
                            NavigationLink {
                                SessionDetailView(session: s)
                            } label: {
                                SessionRow(session: s, isPB: isPB(s, in: sessions))
                                    .padding()
                                    .background(.thinMaterial,
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Karting")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showRecorder = true
                } label: {
                    Label("New session", systemImage: "record.circle")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding()
                .background(.bar)
            }
            .fullScreenCover(isPresented: $showRecorder) {
                RecordView()
            }
        }
    }
}
