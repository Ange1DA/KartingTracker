import SwiftUI

func formatLap(_ t: Double) -> String {
    let m = Int(t) / 60
    return String(format: "%d:%06.3f", m, t - Double(m * 60))
}

func isPB(_ s: Session, in all: [Session]) -> Bool {
    guard let lap = s.bestLap else { return false }
    let best = all.filter { $0.trackName == s.trackName }.compactMap(\.bestLap).min()
    return lap == best
}

struct SessionRow: View {
    let session: Session
    let isPB: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.trackName).font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if isPB { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    Text(session.bestLap.map(formatLap) ?? "--")
                        .font(.headline).monospacedDigit()
                }
                Text("\(session.laps.count) laps")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
