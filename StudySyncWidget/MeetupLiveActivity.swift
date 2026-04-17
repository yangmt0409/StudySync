import ActivityKit
import WidgetKit
import SwiftUI
import MapKit

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

struct MeetupLockScreenView: View {
    let context: ActivityViewContext<MeetupActivityAttributes>

    private var destCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: context.attributes.destLatitude,
            longitude: context.attributes.destLongitude
        )
    }

    private var userCoord: CLLocationCoordinate2D? {
        guard let lat = context.state.userLatitude,
              let lng = context.state.userLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var mapPosition: MapCameraPosition {
        if let userCoord {
            let midLat = (userCoord.latitude + destCoord.latitude) / 2
            let midLng = (userCoord.longitude + destCoord.longitude) / 2
            let latDelta = max(abs(userCoord.latitude - destCoord.latitude) * 1.6, 0.012)
            let lngDelta = max(abs(userCoord.longitude - destCoord.longitude) * 1.6, 0.012)
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
            ))
        } else {
            return .region(MKCoordinateRegion(
                center: destCoord,
                latitudinalMeters: 3000,
                longitudinalMeters: 3000
            ))
        }
    }

    var body: some View {
        ZStack {
            // Map background — full bleed
            Map(initialPosition: mapPosition, interactionModes: []) {
                Marker(context.attributes.placeName, systemImage: "mappin.circle.fill", coordinate: destCoord)
                    .tint(Color(hex: "#FF6B9D"))

                if let userCoord {
                    Annotation("", coordinate: userCoord) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.25))
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(.blue)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))

            // Dark gradient overlay — clear at top, dark at bottom
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.15),
                    .init(color: .black.opacity(0.45), location: 0.45),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content pinned to bottom
            VStack {
                Spacer()

                VStack(spacing: 8) {
                    // Title + place
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#FF6B9D"))
                        Text(context.attributes.meetupTitle)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Spacer()
                        Text(context.attributes.placeName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // Should leave now banner
                    if context.state.shouldLeaveNow {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("该出发了!")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.orange.opacity(0.2))
                        )
                    }

                    // Countdown + 3 ETAs
                    HStack(alignment: .center) {
                        // Left: countdown + meetup time
                        VStack(alignment: .leading, spacing: 2) {
                            if context.attributes.meetupTime > Date.now {
                                Text(timerInterval: Date.now...context.attributes.meetupTime, countsDown: true)
                                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(context.state.shouldLeaveNow ? .orange : .white)
                            } else {
                                Text("已到达集合时间")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                            }
                            Text("集合 \(context.attributes.meetupTime, format: .dateTime.hour().minute())")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        // Right: 3 compact ETAs
                        HStack(spacing: 14) {
                            etaCompact(icon: "car.fill", seconds: context.state.etaDrivingSeconds, color: .cyan)
                            etaCompact(icon: "bus.fill", seconds: context.state.etaTransitSeconds, color: .green)
                            etaCompact(icon: "figure.walk", seconds: context.state.etaWalkingSeconds, color: .orange)
                        }
                    }
                }
                .padding(14)
            }
            .foregroundStyle(.white)
        }
        .widgetURL(URL(string: "studysync://project"))
    }

    // MARK: - Compact ETA

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
