import SwiftUI
import SwiftData
import Combine

struct DualClockView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var settingsArray: [UserSettings]
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var settings: UserSettings? { settingsArray.first }

    private var homeTimeZone: TimeZone {
        settings?.homeTimeZone ?? TimeZone(identifier: "Asia/Shanghai")!
    }

    private var studyTimeZone: TimeZone {
        settings?.studyTimeZone ?? TimeZone(identifier: "America/Toronto")!
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let cardHeight = (geo.size.height - 60) / 2 // 60 for badge + spacing

                VStack(spacing: 0) {
                    ClockCardNew(
                        icon: "house.fill",
                        label: L10n.homeLabel,
                        cityName: settings?.homeCityName ?? L10n.defaultHomeCity,
                        time: currentTime,
                        timeZone: homeTimeZone,
                        accentColorHex: "#FF6B6B"
                    )
                    .frame(height: cardHeight)

                    timeDifferenceBadge

                    ClockCardNew(
                        icon: "mappin.circle.fill",
                        label: L10n.studyLabel,
                        cityName: settings?.studyCityName ?? L10n.defaultStudyCity,
                        time: currentTime,
                        timeZone: studyTimeZone,
                        accentColorHex: "#5B7FFF"
                    )
                    .frame(height: cardHeight)
                }
                .padding(.horizontal, 16)
            }
            .background {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.tabDualClock)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }

    private var timeDifferenceBadge: some View {
        let homeOffset = homeTimeZone.secondsFromGMT(for: currentTime)
        let studyOffset = studyTimeZone.secondsFromGMT(for: currentTime)
        let diffHours = (homeOffset - studyOffset) / 3600

        return Text(L10n.timeDifference(abs(diffHours)))
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
            .padding(.vertical, 4)
    }
}

// MARK: - New Clock Card (matching EventCard style)

struct ClockCardNew: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let label: String
    let cityName: String
    let time: Date
    let timeZone: TimeZone
    let accentColorHex: String

    private var color: Color { Color(hex: accentColorHex) }

    private var timeComponents: (hour: Int, minute: Int, second: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute, .second], from: time)
        return (comps.hour ?? 0, comps.minute ?? 0, comps.second ?? 0)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部：标签行
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))

                    Text(cityName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(time.formattedDate(in: timeZone))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 中间：大时间
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%02d:%02d", timeComponents.hour, timeComponents.minute))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: timeComponents.minute)

                Text(String(format: ":%02d", timeComponents.second))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: timeComponents.second)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(colorScheme == .dark ? 0.05 : 0.03),
                            color.opacity(colorScheme == .dark ? 0.1 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(colorScheme == .dark ? 0.2 : 0.12), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    DualClockView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
