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
/// Earlier versions used a `Map` view as the background, but ActivityKit's
/// lock-screen presentation only renders a small whitelist of views — Map
/// is silently skipped on real devices and the system falls back to a
/// muddy yellow-gold gradient (filed as the visible "broken background"
/// bug). We now ship a static gradient + decorative `mappin` glyph keyed
/// off the meetup state so the design stays on-brand without violating
/// the whitelist.
struct MeetupLockScreenView: View {
    let context: ActivityViewContext<MeetupActivityAttributes>

    /// Status drives the background tint. Three buckets so the user can
    /// glance and immediately tell whether the meetup is upcoming, about
    /// to start, or already past the meetup time.
    private enum Phase {
        case upcoming      // plenty of time, on-brand pink/magenta
        case shouldLeave   // should-leave-now warning, amber/red
        case arrivedTime   // meetup time reached, green
    }

    private var phase: Phase {
        if context.attributes.meetupTime <= Date.now { return .arrivedTime }
        if context.state.shouldLeaveNow { return .shouldLeave }
        return .upcoming
    }

    private var bgGradient: LinearGradient {
        let colors: [Color]
        switch phase {
        case .upcoming:
            // Brand pink → deep magenta. Echoes the #FF6B9D meetup pin
            // colour we use everywhere else (event card, map marker).
            colors = [Color(hex: "#FF6B9D"), Color(hex: "#7C2D5A")]
        case .shouldLeave:
            colors = [Color(hex: "#F97316"), Color(hex: "#7C2D12")]
        case .arrivedTime:
            colors = [Color(hex: "#10B981"), Color(hex: "#064E3B")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            bgGradient

            // Decorative oversized mappin in the bottom-trailing corner.
            // Negative offset pushes most of the glyph off-screen so it
            // reads as a watermark rather than a foreground element —
            // gives the card visual depth without competing with the
            // countdown text.
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 140, weight: .light))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 90, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Content
            VStack(spacing: 10) {
                // Title + place
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text(context.attributes.meetupTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(context.attributes.placeName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.2))
                    )
                }

                // Countdown + 3 ETAs
                HStack(alignment: .center) {
                    // Left: countdown + meetup time
                    VStack(alignment: .leading, spacing: 2) {
                        if context.attributes.meetupTime > Date.now {
                            Text(timerInterval: Date.now...context.attributes.meetupTime, countsDown: true)
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                        } else {
                            Text("已到达集合时间")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        }
                        Text("集合 \(context.attributes.meetupTime, format: .dateTime.hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    // Right: 3 compact ETAs
                    HStack(spacing: 14) {
                        etaCompact(icon: "car.fill", seconds: context.state.etaDrivingSeconds)
                        etaCompact(icon: "bus.fill", seconds: context.state.etaTransitSeconds)
                        etaCompact(icon: "figure.walk", seconds: context.state.etaWalkingSeconds)
                    }
                }
            }
            .padding(14)
            .foregroundStyle(.white)
        }
        .widgetURL(URL(string: "studysync://project"))
    }

    // MARK: - Compact ETA

    /// Single ETA cell. We render in white-on-gradient (instead of the
    /// per-mode tint we used to use) because the background colour is
    /// already carrying the urgency signal — coloured glyphs on a coloured
    /// background washed out badly under the lock-screen render path.
    private func etaCompact(icon: String, seconds: Int?) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(seconds != nil ? .white : .white.opacity(0.4))
            if let seconds {
                Text(formatETA(seconds))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
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
