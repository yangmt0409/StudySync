import SwiftUI

/// Shared empty-state placeholder used across tabs / sub-views.
///
/// Why this exists:
///   Before consolidation, every tab implemented its own empty state with
///   subtly different icon size (48–56pt), font (heading2 vs heading3 vs
///   custom), spacing (12 vs 16 vs 20pt), and CTA button geometry. The
///   inconsistency was visible to users switching between tabs and we
///   couldn't change all of them in one place when the design tweaked.
///
/// All empty states across the app should use this — Schedule / Todo /
/// Countdown / Study Goals / Team Projects / Friends / etc. iPad scaling
/// is built in via `ipScaled(...)` so callers don't think about it.
///
/// Use via the convenience init that takes localized strings + an optional
/// CTA button. The parent view should wrap in `frame(maxWidth: .infinity,
/// maxHeight: .infinity)` if vertical centering is desired.
struct SSEmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let cta: CTA?

    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Optional call-to-action below the subtitle. Render as a Capsule pill
    /// in `iconColor` (matches the icon for visual unity).
    struct CTA {
        let label: String
        let systemImage: String?
        let action: () -> Void

        init(label: String, systemImage: String? = "plus", action: @escaping () -> Void) {
            self.label = label
            self.systemImage = systemImage
            self.action = action
        }
    }

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color = .secondary,
        cta: CTA? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.cta = cta
    }

    var body: some View {
        VStack(spacing: ipScaled(SSSpacing.xl, sizeClass: hSizeClass)) {
            Spacer().frame(height: 60)

            Image(systemName: systemImage)
                .font(.system(size: ipScaled(48, scale: 1.6, sizeClass: hSizeClass)))
                .foregroundStyle(iconColor)

            VStack(spacing: ipScaled(SSSpacing.md, sizeClass: hSizeClass)) {
                Text(title)
                    .font(.system(size: ipScaled(17, scale: 1.5, sizeClass: hSizeClass), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: ipScaled(14, scale: 1.4, sizeClass: hSizeClass)))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SSSpacing.xxxl)
                }
            }

            if let cta {
                Button(action: cta.action) {
                    HStack(spacing: SSSpacing.md) {
                        if let icon = cta.systemImage {
                            Image(systemName: icon)
                                .font(.system(size: ipScaled(14, scale: 1.4, sizeClass: hSizeClass), weight: .bold))
                        }
                        Text(cta.label)
                            .font(.system(size: ipScaled(15, scale: 1.4, sizeClass: hSizeClass), weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, ipScaled(SSSpacing.xxxl, sizeClass: hSizeClass))
                    .padding(.vertical, ipScaled(SSSpacing.lg, sizeClass: hSizeClass))
                    .background(Capsule().fill(iconColor))
                }
                .padding(.top, SSSpacing.md)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("With CTA") {
    SSEmptyStateView(
        systemImage: "checklist",
        title: "No Todos Yet",
        subtitle: "Add your first todo and start managing tasks efficiently",
        iconColor: SSColor.brand,
        cta: .init(label: "Add Todo", action: {})
    )
}

#Preview("No CTA") {
    SSEmptyStateView(
        systemImage: "moon.zzz.fill",
        title: "No one is studying",
        subtitle: nil
    )
}
