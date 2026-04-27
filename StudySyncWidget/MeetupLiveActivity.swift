import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared Attributes (must match main app)

struct MeetupActivityAttributes: ActivityAttributes {
    let meetupTitle: String
    let placeName: String
    let meetupTime: Date
    let destLatitude: Double
    let destLongitude: Double

    struct ContentState: Codable, Hashable {
        let etaDrivingSeconds: Int?
        let etaTransitSeconds: Int?
        let etaWalkingSeconds: Int?
        let shouldLeaveNow: Bool
        let userLatitude: Double?
        let userLongitude: Double?
    }
}

// MARK: - Live Activity Widget

struct MeetupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetupActivityAttributes.self) { context in
            MeetupLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "#FF6B9D"))
                        Text(context.attributes.meetupTitle)
                            .font(.caption.bold())
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.attributes.meetupTime > Date.now {
                        Text(timerInterval: Date.now...context.attributes.meetupTime, countsDown: true)
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(context.state.shouldLeaveNow ? .orange : .primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("已到时间")
                            .font(.headline.bold())
                            .foregroundStyle(.green)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if context.state.shouldLeaveNow {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("该出发了!")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(.orange)
                        }

                        // 3 ETAs
                        HStack(spacing: 16) {
                            etaLabel(icon: "car.fill", seconds: context.state.etaDrivingSeconds, color: .blue)
                            etaLabel(icon: "bus.fill", seconds: context.state.etaTransitSeconds, color: .green)
                            etaLabel(icon: "figure.walk", seconds: context.state.etaWalkingSeconds, color: .orange)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#FF6B9D"))
            } compactTrailing: {
                if context.state.shouldLeaveNow {
                    Text("出发!")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                } else if context.attributes.meetupTime > Date.now {
                    Text(timerInterval: Date.now...context.attributes.meetupTime, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .frame(width: 52)
                } else {
                    Text("到了")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            } minimal: {
                minimalView(context: context)
            }
        }
    }

    // MARK: - Minimal View

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<MeetupActivityAttributes>) -> some View {
        if context.state.shouldLeaveNow {
            ZStack {
                Circle().fill(.orange.opacity(0.5))
                Image(systemName: "exclamationmark")
                    .font(.caption2.bold())
            }
        } else {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundStyle(Color(hex: "#FF6B9D"))
        }
    }

    // MARK: - Helpers

    private func etaLabel(icon: String, seconds: Int?, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            if let seconds {
                Text(formatETA(seconds))
                    .font(.caption2.monospacedDigit())
            } else {
                Text("--")
                    .font(.caption2.monospacedDigit())
            }
        }
        .foregroundStyle(seconds != nil ? color : .secondary)
    }

    private func formatETA(_ seconds: Int) -> String {
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMin = minutes % 60
        if remainingMin == 0 { return "\(hours)h" }
        return "\(hours)h\(remainingMin)m"
    }
}

// MARK: - Lock Screen View

/// Live Activity lock-screen view for an upcoming meetup.
///
/// History note: earlier versions tried a `Map` as the background, but
/// ActivityKit's lock-screen presentation only renders a small whitelist
/// of views — Map is silently skipped and the system falls back to a
/// muddy yellow-gold default (the "broken background" bug). The follow-up
/// gradient version was on-brand but legibility suffered against pink /
/// orange backgrounds on the lock screen. We now ship a flat dark surface
/// (matches the widget aesthetic of DueCountdownLiveActivity) with a
/// thin colour bar on the leading edge that carries the status signal.
struct MeetupLockScreenView: View {
    let context: ActivityViewContext<MeetupActivityAttributes>

    /// Status drives the leading status bar colour. Three buckets so the
    /// user can glance and immediately tell whether the meetup is
    /// upcoming, about to start, or already past the meetup time.
    private enum Phase {
        case upcoming      // plenty of time, on-brand pink
        case shouldLeave   // should-leave-now warning, amber
        case arrivedTime   // meetup time reached, green
    }

    private var phase: Phase {
        if context.attributes.meetupTime <= Date.now { return .arrivedTime }
        if context.state.shouldLeaveNow { return .shouldLeave }
        return .upcoming
    }

    /// Status indicator colour — used for the leading bar and the small
    /// title-row pin glyph. Saturated colours read fine on the dark
    /// surface; the rest of the content stays white for max legibility.
    private var statusColor: Color {
        switch phase {
        case .upcoming:    return Color(hex: "#FF6B9D")  // brand pink
        case .shouldLeave: return Color(hex: "#F97316")  // amber
        case .arrivedTime: return Color(hex: "#10B981")  // green
        }
    }

    var body: some View {
        ZStack {
            // Flat dark surface — easy to read on both light & dark lock
            // screens, no gradient noise. Matches Apple's own Maps and
            // Find My Live Activities.
            Color(hex: "#1C1C1E")

            // Leading 4pt colour bar carries the urgency signal.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(statusColor)
                    .frame(width: 4)
                Spacer(minLength: 0)
            }

            // Content
            VStack(spacing: 10) {
                // Title + place
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                    Text(context.attributes.meetupTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(context.attributes.placeName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                // Should leave now banner
                if context.state.shouldLeaveNow && phase != .arrivedTime {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("该出发了!")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color(hex: "#F97316"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#F97316").opacity(0.18))
                    )
                }

                // Countdown + 3 ETAs
                HStack(alignment: .center) {
                    // Left: countdown + meetup time
                    VStack(alignment: .leading, spacing: 2) {
                        if context.attributes.meetupTime > Date.now {
                            Text(timerInterval: Date.now...context.attributes.meetupTime, countsDown: true)
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(phase == .shouldLeave ? statusColor : .white)
                        } else {
                            Text("已到达集合时间")
                                .font(.headline.bold())
                                .foregroundStyle(statusColor)
                        }
                        Text("集合 \(context.attributes.meetupTime, format: .dateTime.hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    // Right: 3 compact ETAs
                    HStack(spacing: 14) {
                        etaCompact(icon: "car.fill", seconds: context.state.etaDrivingSeconds, color: Color(hex: "#5AC8FA"))
                        etaCompact(icon: "bus.fill", seconds: context.state.etaTransitSeconds, color: Color(hex: "#34C759"))
                        etaCompact(icon: "figure.walk", seconds: context.state.etaWalkingSeconds, color: Color(hex: "#FF9F0A"))
                    }
                }
            }
            .padding(.leading, 16)   // extra to clear the 4pt status bar
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
        }
        .widgetURL(URL(string: "studysync://project"))
    }

    // MARK: - Compact ETA

    /// Single ETA cell. Glyph carries the per-mode tint (cyan / green /
    /// orange) — these read fine on the flat dark surface, unlike the
    /// previous gradient design where coloured glyphs washed out.
    private func etaCompact(icon: String, seconds: Int?, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(seconds != nil ? color : .white.opacity(0.35))
            if let seconds {
                Text(formatETA(seconds))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func formatETA(_ seconds: Int) -> String {
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMin = minutes % 60
        if remainingMin == 0 { return "\(hours)h" }
        return "\(hours)h\(remainingMin)m"
    }
}
