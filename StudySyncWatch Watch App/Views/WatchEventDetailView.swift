import SwiftUI

struct WatchEventDetailView: View {
    let event: WatchEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Emoji
                Text(event.emoji)
                    .font(.system(size: 36))

                // Days remaining - big number
                Text("\(event.primaryCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: event.colorHex))

                Text(event.isExpired ? "已结束" : event.unitLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                // Progress ring
                WatchProgressRing(
                    progress: event.progress,
                    colorHex: event.colorHex
                )
                .frame(width: 80, height: 80)

                // Title
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)

                // Category tag
                Text(event.categoryName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color(hex: event.colorHex))
                    )

                // Date range
                VStack(spacing: 2) {
                    Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                    Text("→")
                    Text(event.endDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                // Progress text
                Text("\(Int(event.progress * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Watch Progress Ring

struct WatchProgressRing: View {
    let progress: Double
    let colorHex: String
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: colorHex).opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color(hex: colorHex),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: colorHex))
        }
    }
}
