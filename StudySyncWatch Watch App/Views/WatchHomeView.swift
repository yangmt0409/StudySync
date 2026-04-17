import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchSyncManager.self) private var syncManager

    var body: some View {
        NavigationStack {
            List {
                if sortedEvents.isEmpty {
                    emptyState
                } else {
                    ForEach(sortedEvents.prefix(5)) { event in
                        NavigationLink(value: event.id) {
                            WatchEventRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("留时")
            .navigationDestination(for: UUID.self) { eventId in
                if let event = syncManager.events.first(where: { $0.id == eventId }) {
                    WatchEventDetailView(event: event)
                }
            }
        }
    }

    private var sortedEvents: [WatchEvent] {
        syncManager.events
            .filter { !$0.isExpired }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.primaryCount < rhs.primaryCount
            }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("暂无倒计时")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("在 iPhone 上添加事件")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Event Row

struct WatchEventRow: View {
    let event: WatchEvent

    var body: some View {
        HStack(spacing: 10) {
            // Emoji
            Text(event.emoji)
                .font(.system(size: 20))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(event.categoryName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: event.colorHex))
            }

            Spacer()

            // Days
            VStack(spacing: 0) {
                Text("\(event.primaryCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: event.colorHex))
                Text(event.unitLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Color Hex (Watch)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (91, 127, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
