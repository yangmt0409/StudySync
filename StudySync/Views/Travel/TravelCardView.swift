import SwiftUI
import Combine

/// Horizontal route-visualization card for a `TravelEvent`.
///
/// Visual anatomy:
/// ```
///  ┌──────────────────────────────────────────┐
///  │ ✈️ CA981 · Air China         [● 延误]    │
///  │                                            │
///  │  10:30         ✈️───────────✈️      13:45 │
///  │  PEK T3       12h 15m · direct     YYZ T1 │
///  │                                            │
///  │  还有 3 天 · 💺 14A                         │
///  └──────────────────────────────────────────┘
/// ```
///
/// Style is driven by `TravelKind.gradientHex` so each transport mode has a
/// recognizable palette at a glance — this is what differentiates it from
/// regular calendar items per the product requirements.
struct TravelCardView: View {
    let event: TravelEvent

    // For live countdown — ticks every minute.
    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            routeStrip
            footer
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: event.kind.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(event.kind.accentColor.opacity(0.3), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.fullNumber.isEmpty ? event.kind.label : event.fullNumber)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    if !event.serviceName.isEmpty {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.6))
                        Text(event.serviceName)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Image(systemName: event.status.symbolName)
                .font(.system(size: 9, weight: .semibold))
            Text(statusLabel)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(event.status.accentColor.opacity(0.9), in: Capsule())
    }

    private var statusLabel: String {
        if event.status == .delayed && event.delayMinutes > 0 {
            return "\(event.status.label) \(event.delayMinutes)m"
        }
        return event.status.label
    }

    // MARK: - Route strip

    /// Fixed width for the middle (line + duration) column. Keeping this
    /// constant — rather than letting it flex via Spacers — is what prevents
    /// long airport names from pushing the plane icon off-center.
    private let middleColumnWidth: CGFloat = 108

    private var routeStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            endpointColumn(
                time: event.departureTimeLocal,
                code: event.departureStationCode,
                name: event.departureStation,
                terminal: event.departureTerminal,
                gate: event.departureGate,
                zone: event.departureTimeZone,
                alignment: .leading
            )
            // Equal flex width on both sides + fixed middle = the plane icon
            // is mathematically centered regardless of text length.
            middleColumn
                .frame(width: middleColumnWidth)
            endpointColumn(
                time: event.arrivalTimeLocal,
                code: event.arrivalStationCode,
                name: event.arrivalStation,
                terminal: event.arrivalTerminal,
                gate: "",
                zone: event.arrivalTimeZone,
                alignment: .trailing
            )
        }
    }

    private var middleColumn: some View {
        VStack(spacing: 4) {
            routeLine
            Text(event.durationLabel)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
            Text(event.segments.isEmpty
                 ? String(localized: "直达")
                 : String(localized: "经停 \(event.segments.count) 段"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    /// `● ──── ✈ ──── ●` — endpoint dots make the strip read as a route
    /// visualization at a glance. The line uses a subtle 30% white so the
    /// plane icon stays the focal point.
    private var routeLine: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
            Image(systemName: event.kind.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 5, height: 5)
        }
        .frame(height: 14)
    }

    private func endpointColumn(
        time: Date,
        code: String,
        name: String,
        terminal: String,
        gate: String,
        zone: TimeZone,
        alignment: HorizontalAlignment
    ) -> some View {
        let frameAlignment: Alignment = (alignment == .leading) ? .leading : .trailing
        return VStack(alignment: alignment, spacing: 3) {
            Text(Self.timeFormatter(zone: zone).string(from: time))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if !code.isEmpty {
                Text(code)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .tracking(0.5)
            }
            if !name.isEmpty && name != code {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Fill the column so alignment + ellipsis work correctly
                    // when the name wants more space than is available.
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            if !terminal.isEmpty || !gate.isEmpty {
                HStack(spacing: 4) {
                    if !terminal.isEmpty {
                        Text(terminal)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    if !gate.isEmpty {
                        Text(gate)
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.18), in: Capsule())
            }
        }
        // Flex to equal width on both sides of the middle column — this is
        // the other half of keeping the plane icon centered.
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Label {
                Text(countdownText)
                    .font(.system(size: 12, weight: .semibold))
            } icon: {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.white)
            if !event.seat.isEmpty {
                Text("💺 \(event.seat)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
    }

    private var countdownText: String {
        let delta = event.departureInstant.timeIntervalSince(now)
        if delta <= 0 {
            // Departed or past — show a different message
            if event.status == .arrived || event.status == .completed {
                return event.status.label
            }
            let elapsed = abs(delta)
            let hours = Int(elapsed) / 3600
            if hours > 24 { return event.status.label }
            return String(localized: "已出发 \(hours)h")
        }
        let days = Int(delta / 86400)
        let hours = (Int(delta) % 86400) / 3600
        let minutes = (Int(delta) % 3600) / 60
        if days > 0 { return String(localized: "还有 \(days) 天 \(hours) 小时") }
        if hours > 0 { return String(localized: "还有 \(hours) 小时 \(minutes) 分钟") }
        return String(localized: "还有 \(minutes) 分钟") // imminent
    }

    // MARK: - Background

    private var cardBackground: some View {
        let (start, end) = event.kind.gradientHex
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: start), Color(hex: end)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
    }

    static func timeFormatter(zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        // We interpret stored *TimeLocal as UTC-packed wall-clock times,
        // so we render with UTC to get the raw hour:minute back out.
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }
}

#Preview {
    let e = TravelEvent(
        kind: .flight,
        carrierCode: "CA",
        number: "981",
        departureCity: "Beijing",
        departureStation: "Capital",
        arrivalCity: "Toronto",
        arrivalStation: "Pearson",
        departureTimeLocal: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
        arrivalTimeLocal: Calendar.current.date(byAdding: .hour, value: 15, to: Date())!
    )
    e.departureStationCode = "PEK"
    e.arrivalStationCode = "YYZ"
    e.departureTerminal = "T3"
    e.arrivalTerminal = "T1"
    e.serviceName = "Air China"
    e.seat = "14A"
    return TravelCardView(event: e)
        .padding()
        .background(Color(.systemGroupedBackground))
}
