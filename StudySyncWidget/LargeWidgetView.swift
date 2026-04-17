import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: StudySyncEntry

    private var settings: WidgetSettingsData { entry.settings }
    private var events: [WidgetEventData] { Array(entry.events.prefix(4)) }

    // 找第一个学业类事件作为学期进度
    private var semesterEvent: WidgetEventData? {
        entry.events.first { $0.categoryName == "学业" } ?? entry.nearestEvent
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：学期进度条
            if let semester = semesterEvent {
                progressBarSection(event: semester)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
            }

            Divider()
                .padding(.horizontal, 16)

            // 中间：事件列表
            if events.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("添加倒计时事件")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(events) { event in
                        Link(destination: URL(string: "studysync://event/\(event.id.uuidString)")!) {
                            eventRow(event: event)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Spacer(minLength: 0)

            Divider()
                .padding(.horizontal, 16)

            // 底部：双时区
            dualTimeZoneBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    // MARK: - Progress Bar Section

    private func progressBarSection(event: WidgetEventData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(event.emoji) \(event.title)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(Int(event.progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: event.colorHex))
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: event.colorHex).opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: event.colorHex).opacity(0.7),
                                    Color(hex: event.colorHex)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * event.progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(event.primaryCount) \(event.unitLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.endDate.formattedChinese)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(event: WidgetEventData) -> some View {
        HStack(spacing: 10) {
            // Emoji
            Text(event.emoji)
                .font(.system(size: 22))
                .frame(width: 32, height: 32)

            // 标题
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(event.categoryName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: event.colorHex))
            }

            Spacer()

            // 天数
            Text("\(event.primaryCount) \(event.unitLabel)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: event.colorHex))

            // 迷你进度环
            WidgetProgressRing(
                progress: event.progress,
                size: 24,
                lineWidth: 3,
                ringColor: Color(hex: event.colorHex),
                trackColor: Color(hex: event.colorHex).opacity(0.15)
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Dual Timezone Bar

    private var dualTimeZoneBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "house.fill")
                    .font(.system(size: 10))
                Text(settings.homeCityName)
                    .font(.system(size: 11))
                Text(entry.date.formattedTime(in: settings.homeTimeZone, style: .short))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)

            Spacer()

            let diffHours = abs(
                settings.homeTimeZone.secondsFromGMT(for: entry.date)
                - settings.studyTimeZone.secondsFromGMT(for: entry.date)
            ) / 3600
            Text("时差\(diffHours)h")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 10))
                Text(settings.studyCityName)
                    .font(.system(size: 11))
                Text(entry.date.formattedTime(in: settings.studyTimeZone, style: .short))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
        }
    }
}
