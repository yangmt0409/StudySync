import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: StudySyncEntry

    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }

    var body: some View {
        if let event {
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                // 大号数值
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(event.primaryCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                    Text(event.unitLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // 迷你点阵
                WidgetDotGrid(
                    progress: event.progress,
                    totalDots: min(event.totalDays, 60),
                    columns: 10
                )

                HStack {
                    Text("\(Int(event.progress * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(event.categoryName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(hex: event.colorHex),
                        Color(hex: event.colorHex).opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .widgetURL(URL(string: "studysync://event/\(event.id.uuidString)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("添加事件")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .widgetURL(URL(string: "studysync://add"))
        }
    }
}

// MARK: - Widget Dot Grid (static, no animation)

struct WidgetDotGrid: View {
    let progress: Double
    let totalDots: Int
    var columns: Int = 10
    var dotColor: Color = .white

    private var filledDots: Int {
        Int(Double(totalDots) * progress)
    }

    var body: some View {
        let gridItems = Array(
            repeating: GridItem(.flexible(), spacing: 2),
            count: columns
        )

        LazyVGrid(columns: gridItems, spacing: 2) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .frame(width: 4, height: 4)
                    .foregroundStyle(
                        index < filledDots ? dotColor : dotColor.opacity(0.25)
                    )
            }
        }
    }
}

// MARK: - Static Progress Ring (for Widget)

struct WidgetProgressRing: View {
    let progress: Double
    var size: CGFloat = 44
    var lineWidth: CGFloat = 4
    var ringColor: Color = .white
    var trackColor: Color = .white.opacity(0.3)

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
