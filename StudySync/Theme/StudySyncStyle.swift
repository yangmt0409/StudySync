import SwiftUI

// MARK: - StudySync UI Style Guide
// All new views MUST use these constants for consistency.
// Do NOT hardcode font sizes, colors, spacing, or corner radii.

// ============================================================
// MARK: - Typography
// ============================================================

enum SSFont {

    // --- Display (hero numbers, clocks) ---
    /// 48pt — empty state icons only
    static let displayIcon: Font = .system(size: 48)
    /// 44pt bold rounded — clock digits (DualClockView)
    static let clockDigit: Font = .system(size: 44, weight: .bold, design: .rounded)
    /// 32pt bold rounded — countdown days
    static let countdownLarge: Font = .system(size: 32, weight: .bold, design: .rounded)
    /// 28pt — large emoji in pickers
    static let emojiLarge: Font = .system(size: 28)

    // --- Heading ---
    /// 24pt bold — section/page headlines, app name
    static let heading1: Font = .system(size: 24, weight: .bold)
    /// 20pt semibold — card headlines, dialog titles
    static let heading2: Font = .system(size: 20, weight: .semibold)
    /// 17pt semibold — card titles, primary row labels
    static let heading3: Font = .system(size: 17, weight: .semibold)

    // --- Body ---
    /// 16pt semibold — toolbar Save button, event titles
    static let bodySemibold: Font = .system(size: 16, weight: .semibold)
    /// 16pt medium — person names, row titles
    static let bodyMedium: Font = .system(size: 16, weight: .medium)
    /// 16pt regular — text input, primary body text
    static let body: Font = .system(size: 16)
    /// 15pt semibold — card sub-headers
    static let bodySmallSemibold: Font = .system(size: 15, weight: .semibold)
    /// 15pt medium — library names
    static let bodySmallMedium: Font = .system(size: 15, weight: .medium)

    // --- Secondary ---
    /// 14pt medium — filter chips, category badges, inline labels
    static let chipLabel: Font = .system(size: 14, weight: .medium)
    /// 14pt medium rounded — badge counts, metric values
    static let metric: Font = .system(size: 14, weight: .medium, design: .rounded)
    /// 14pt regular — secondary descriptions, subtitles
    static let secondary: Font = .system(size: 14)

    // --- Caption ---
    /// 13pt semibold — section header uppercase
    static let sectionHeader: Font = .system(size: 13, weight: .semibold)
    /// 13pt medium rounded — countdown unit label ("天"), stat values
    static let captionMedium: Font = .system(size: 13, weight: .medium, design: .rounded)
    /// 13pt regular — dates, secondary info, chevron icons
    static let caption: Font = .system(size: 13)
    /// 12pt medium monospaced — version numbers
    static let mono: Font = .system(size: 12, weight: .medium, design: .monospaced)
    /// 12pt regular — tertiary text, role descriptions
    static let footnote: Font = .system(size: 12)
    /// 11pt medium — small badges, frequency tags
    static let badge: Font = .system(size: 11, weight: .medium)
    /// 10pt regular — tiny indicators (pin icon)
    static let micro: Font = .system(size: 10)
}


// ============================================================
// MARK: - Color Palette
// ============================================================

enum SSColor {

    // --- Brand ---
    /// Primary blue — default accent, tint, links
    static let brand = Color(hex: "#5B7FFF")
    /// Secondary purple — gradients, highlights
    static let brandPurple = Color(hex: "#7C3AED")

    // --- Feature Accents ---
    /// Meetup & nudge pink — pins, actions, highlights
    static let meetup = Color(hex: "#FF6B9D")

    // --- Category Defaults ---
    static let academic = Color(hex: "#5B7FFF")
    static let visa = Color(hex: "#FF6B6B")
    static let travel = Color(hex: "#4ECDC4")
    static let life = Color(hex: "#FFB347")

    // --- Selectable Palette (12 colors for pickers) ---
    static let palette: [String] = [
        "#5B7FFF", "#FF6B6B", "#4ECDC4", "#FFD93D",
        "#6C5CE7", "#A8E6CF", "#FF8A5C", "#EA8685",
        "#778BEB", "#63CDDA", "#F19066", "#B8E994"
    ]

    // --- Gradient Presets ---
    static let gradientHome = [Color(hex: "#FF6B6B"), Color(hex: "#FFB347")]
    static let gradientStudy = [Color(hex: "#5B7FFF"), Color(hex: "#4ECDC4")]
    static let gradientBrand = [Color(hex: "#5B7FFF"), Color(hex: "#7C3AED")]

    // --- Semantic (use system tokens for dark mode) ---
    /// Primary background — `Color(.systemGroupedBackground)`
    static let backgroundPrimary = Color(.systemGroupedBackground)
    /// Card / section background — `Color(.secondarySystemGroupedBackground)`
    static let backgroundCard = Color(.secondarySystemGroupedBackground)
    /// Subtle fill for inactive chips / emoji rings
    static let fillTertiary = Color(.tertiarySystemFill)
    /// Progress ring background track
    static let ringTrack = Color(.systemGray5)
}


// ============================================================
// MARK: - Spacing
// ============================================================

enum SSSpacing {
    /// 2pt — micro gap (tag vertical padding, stacked labels)
    static let xxs: CGFloat = 2
    /// 4pt — tiny gap (section internal, chip vertical padding)
    static let xs: CGFloat = 4
    /// 6pt — small gap (icon-to-text)
    static let sm: CGFloat = 6
    /// 8pt — standard small gap (filter chips, emoji grid)
    static let md: CGFloat = 8
    /// 10pt — medium gap (row icon-to-text)
    static let mdLg: CGFloat = 10
    /// 12pt — standard gap (card content spacing, list item spacing)
    static let lg: CGFloat = 12
    /// 14pt — row internal padding
    static let lgXl: CGFloat = 14
    /// 16pt — standard screen padding, card internal padding
    static let xl: CGFloat = 16
    /// 20pt — large padding (section bottom, clock views)
    static let xxl: CGFloat = 20
    /// 24pt — extra large (card vertical padding, section spacing)
    static let xxxl: CGFloat = 24
}


// ============================================================
// MARK: - Corner Radius
// ============================================================

enum SSRadius {
    /// 10pt — small elements (app icon thumbnails)
    static let small: CGFloat = 10
    /// 14pt — list rows, info sections
    static let medium: CGFloat = 14
    /// 16pt — standard cards (EventCard, form sections)
    static let card: CGFloat = 16
    /// 20pt — large cards (clock cards, about header)
    static let large: CGFloat = 20
    /// 22pt — app icon shape
    static let appIcon: CGFloat = 22
}


// ============================================================
// MARK: - Shadow
// ============================================================

enum SSShadow {
    /// Standard card shadow — subtle colored glow below
    static func card(color: Color) -> some View {
        // Usage: .background { SSShadow.card(color: accentColor) }
        // Instead, apply via the modifier:
        EmptyView() // Placeholder — use the modifier below
    }
}

extension View {
    /// Apply the standard card shadow. `color` = the card's accent hex.
    func ssCardShadow(color: Color) -> some View {
        self.shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    /// Stronger shadow for floating elements (about header, modals)
    func ssElevatedShadow(color: Color) -> some View {
        self.shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
    }
}


// ============================================================
// MARK: - Border
// ============================================================

enum SSBorder {
    /// Subtle card border — accent color at 10% opacity in light, 18% in dark mode (#12)
    static let cardOpacityLight: Double = 0.10
    static let cardOpacityDark: Double = 0.18
    static let cardOpacity: Double = 0.1
    static let cardWidth: CGFloat = 1

    /// Selected item ring — 2pt stroke
    static let selectionWidth: CGFloat = 2
    /// Color picker ring — 3pt stroke
    static let colorPickerWidth: CGFloat = 3
}


// ============================================================
// MARK: - Opacity
// ============================================================

enum SSOpacity {
    /// 0.08 — card shadow color
    static let shadow: Double = 0.08
    /// 0.10 — card border
    static let border: Double = 0.10
    /// 0.12 — category tag / badge background
    static let tagBackground: Double = 0.12
    /// 0.15 — selected emoji ring fill, light accent tint
    static let lightTint: Double = 0.15
    /// 0.20 — unfilled dots in dot grid
    static let dotUnfilled: Double = 0.20
    /// 0.30 — elevated shadow
    static let elevatedShadow: Double = 0.30
    /// 0.40 — disabled button tint
    static let disabled: Double = 0.40
    /// 0.60 — secondary text / muted elements
    static let muted: Double = 0.60
}


// ============================================================
// MARK: - Animation
// ============================================================

enum SSAnimation {
    /// Spring for interactive feedback (pin, toggle, selection)
    static let spring: Animation = .spring(duration: 0.3)
    /// Progress ring fill
    static let progressAppear: Animation = .easeInOut(duration: 1.0)
    /// Progress ring value change
    static let progressChange: Animation = .easeInOut(duration: 0.6)
    /// Dot grid staggered appear (per dot, max 0.6s total)
    static let dotAppear: Animation = .easeOut(duration: 0.3)
    static let dotMaxDelay: Double = 0.6
}


// ============================================================
// MARK: - Component Sizes
// ============================================================

enum SSSize {
    /// Progress ring in event card
    static let ringCard: CGFloat = 52
    static let ringCardLine: CGFloat = 5

    /// Progress ring default
    static let ringDefault: CGFloat = 56
    static let ringDefaultLine: CGFloat = 8

    /// Emoji picker circle
    static let emojiCircle: CGFloat = 44

    /// Color picker circle
    static let colorCircle: CGFloat = 36

    /// Person row avatar
    static let avatarSmall: CGFloat = 36

    /// App icon preview
    static let appIconPreview: CGFloat = 40
    static let appIconLarge: CGFloat = 80

    /// Chevron icon in rows
    static let chevron: CGFloat = 12
    /// Chevron icon (slightly larger)
    static let chevronMedium: CGFloat = 13

    /// Toolbar save / nav button icon
    static let navIcon: CGFloat = 24

    /// Preview card emoji
    static let previewEmoji: CGFloat = 32
}


// ============================================================
// MARK: - Reusable View Modifiers
// ============================================================

extension View {
    /// Standard card background + border + shadow (#12 dark mode improved border contrast)
    func ssCard(color: Color = SSColor.brand) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                    .stroke(color.opacity(SSOpacity.border), lineWidth: SSBorder.cardWidth)
            )
            .ssCardShadow(color: color)
    }

    /// Adaptive card border with better dark mode visibility (#12)
    func ssAdaptiveBorder(color: Color, colorScheme: ColorScheme) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .stroke(
                    color.opacity(colorScheme == .dark ? SSBorder.cardOpacityDark : SSBorder.cardOpacityLight),
                    lineWidth: SSBorder.cardWidth
                )
        )
    }

    /// Info section container (About page, settings groups)
    func ssSection() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
    }

    /// Category / frequency badge capsule
    func ssBadge(color: Color) -> some View {
        self
            .font(SSFont.badge)
            .foregroundStyle(color)
            .padding(.horizontal, SSSpacing.md)
            .padding(.vertical, SSSpacing.xxs)
            .background(color.opacity(SSOpacity.tagBackground).clipShape(Capsule()))
    }

    /// Filter chip (selected / unselected)
    func ssChip(isSelected: Bool) -> some View {
        self
            .font(SSFont.chipLabel)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, SSSpacing.lg)
            .padding(.vertical, SSSpacing.xs)
            .background(
                Capsule().fill(isSelected ? Color.blue : SSColor.fillTertiary)
            )
    }
}


// ============================================================
// MARK: - Gradient Helpers
// ============================================================

extension LinearGradient {
    /// Standard diagonal gradient (top-leading → bottom-trailing)
    static func ssDiagonal(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
