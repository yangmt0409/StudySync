import SwiftUI

struct CountdownDisplayView: View {
    let daysRemaining: Int
    let isExpired: Bool
    var colorHex: String = "#5B7FFF"

    private var color: Color {
        Color(hex: colorHex)
    }

    var body: some View {
        VStack(spacing: 2) {
            if isExpired {
                Text(L10n.expired)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(daysRemaining)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())

                Text(L10n.daysUnit)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        // #13 Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isExpired ? L10n.expired : L10n.daysRemaining(daysRemaining))
    }
}

#Preview {
    HStack(spacing: 40) {
        CountdownDisplayView(daysRemaining: 42, isExpired: false, colorHex: "#5B7FFF")
        CountdownDisplayView(daysRemaining: 0, isExpired: true, colorHex: "#FF6B6B")
    }
}
