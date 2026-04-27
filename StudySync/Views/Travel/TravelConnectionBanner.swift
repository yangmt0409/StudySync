import SwiftUI

/// Pinned above the next leg's `TravelCardView` whenever
/// `TravelConnectionDetector` finds a layover ≤ 18h between this and the
/// previous trip in the same city. Visually a small dashed pill so it
/// doesn't compete with the colorful TravelCardView below.
///
/// Two states:
/// - Same airport (`HKG → HKG`): "中转 · 3h 25m · 同机场"
/// - Different airports in same city (`NRT → HND`): "中转 · 6h 10m · NRT → HND（换机场）" + warning tint
struct TravelConnectionBanner: View {
    let connection: TravelConnection

    private var layoverLabel: String {
        let h = connection.layoverMinutes / 60
        let m = connection.layoverMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private var locationLabel: String {
        if connection.isSameAirport {
            return String(localized: "同机场")
        }
        return "\(connection.prevArrivalCode) → \(connection.nextDepartureCode) " +
            String(localized: "(换机场)")
    }

    private var accentColor: Color {
        connection.isSameAirport ? SSColor.travel : .orange
    }

    var body: some View {
        HStack(spacing: SSSpacing.md) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(SSFont.caption)
                .foregroundStyle(accentColor)

            HStack(spacing: SSSpacing.xs) {
                Text(String(localized: "中转"))
                    .font(SSFont.captionMedium)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(layoverLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(locationLabel)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SSSpacing.lgXl)
        .padding(.vertical, SSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                .fill(accentColor.opacity(SSOpacity.tagBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                .strokeBorder(
                    accentColor.opacity(SSOpacity.elevatedShadow),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
        .padding(.bottom, SSSpacing.xs)
    }
}

#Preview("Same airport") {
    TravelConnectionBanner(connection: TravelConnection(
        previousId: UUID(),
        nextId: UUID(),
        layoverMinutes: 205,
        isSameAirport: true,
        prevArrivalCode: "HKG",
        nextDepartureCode: "HKG"
    ))
    .padding()
}

#Preview("Inter-airport") {
    TravelConnectionBanner(connection: TravelConnection(
        previousId: UUID(),
        nextId: UUID(),
        layoverMinutes: 370,
        isSameAirport: false,
        prevArrivalCode: "NRT",
        nextDepartureCode: "HND"
    ))
    .padding()
}
