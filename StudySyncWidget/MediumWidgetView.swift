import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: StudySyncEntry

    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }
    private var settings: WidgetSettingsData { entry.settings }

    var body: some View {
        HStack(spacing: 0) {
            dualClockSection
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color(.separator).opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 12)

            eventSection
                .frame(maxWidth: .infinity)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var dualClockSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Label(settings.homeCityName, systemImage: "house.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(entry.date.formattedTime(in: settings.homeTimeZone, style: .short))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }

            let diffHours = abs(
                settings.homeTimeZone.secondsFromGMT(for: entry.date)
                - settings.studyTimeZone.secondsFromGMT(for: entry.date)
            ) / 3600
            Text("时差 \(diffHours)h")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(.tertiarySystemFill)))

            VStack(spacing: 2) {
                Label(settings.studyCityName, systemImage: "mappin.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(entry.date.formattedTime(in: settings.studyTimeZone, style: .short))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
        }
        .padding(12)
    }

    private var eventSection: some View {
        Group {
            if let event {
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    ZStack {
                        WidgetProgressRing(
                            progress: event.progress, size: 72, lineWidth: 6,
                            ringColor: Color(hex: event.colorHex),
                            trackColor: Color(hex: event.colorHex).opacity(0.15)
                        )
                        VStack(spacing: 0) {
                            Text("\(event.primaryCount)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: event.colorHex))
                            Text(event.unitLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(event.categoryName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: event.colorHex))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("暂无事件")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Medium Dot Grid Widget (Pretty Progress style)

struct MediumDotGridWidgetView: View {
    let entry: StudySyncEntry

    private var event: WidgetEventData? { entry.selectedEvent ?? entry.nearestEvent }

    var body: some View {
        if let event {
            VStack(alignment: .leading, spacing: 0) {
                // 固定标题区域
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.title)
                        .font(widgetFont(event.fontName, size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: event.textColorHex))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)

                    Text("\(event.primaryCount) \(event.unitLabel)")
                        .font(widgetFont(event.fontName, size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: event.textColorHex).opacity(0.55))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .padding(.bottom, 8)

                Spacer(minLength: 0)

                // 点阵底部对齐
                WidgetDotGridFull(
                    progress: event.progress,
                    totalDots: min(event.totalDays, 200),
                    dotColor: Color(hex: event.dotColorHex)
                )
            }
            .padding(10)
            .containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: event.colorHex),
                            Color(hex: event.colorHex).opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // 背景图片
                    if let data = event.backgroundImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.35)
                    }
                }
            }
            .widgetURL(URL(string: "studysync://event/\(event.id.uuidString)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("添加事件")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        }
    }
}

// MARK: - Full-size dot grid for widget

struct WidgetDotGridFull: View {
    let progress: Double
    let totalDots: Int
    var dotColor: Color = .white

    private var filledDots: Int {
        Int(Double(totalDots) * progress)
    }

    private var columns: Int { 20 }

    var body: some View {
        let gridItems = Array(
            repeating: GridItem(.flexible(), spacing: 4),
            count: columns
        )

        LazyVGrid(columns: gridItems, spacing: 4) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .aspectRatio(1, contentMode: .fit)
                    .foregroundStyle(
                        index < filledDots ? dotColor : dotColor.opacity(0.25)
                    )
            }
        }
    }
}

// MARK: - Font Helper

func widgetFont(_ name: String, size: CGFloat, weight: Font.Weight) -> Font {
    switch name {
    case "rounded": return .system(size: size, weight: weight, design: .rounded)
    case "serif": return .system(size: size, weight: weight, design: .serif)
    case "mono": return .system(size: size, weight: weight, design: .monospaced)
    default: return .system(size: size, weight: weight)
    }
}
