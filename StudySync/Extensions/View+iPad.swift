import SwiftUI

// MARK: - iPad Adaptation Helpers
//
// Utilities for adapting iPhone-designed layouts to iPad's larger canvas.
// Added in v1.0.2 when the app went universal (TARGETED_DEVICE_FAMILY 1 → 1,2).
//
// Two main concerns these helpers address:
//
//   1. Long-form content (Settings, Paywall, About) stretches across iPad's
//      1024-1366pt width and becomes unreadable. `readableContentWidth()`
//      caps the inner column to a comfortable text measure (~700pt) while
//      leaving the rest of the view (background, etc.) full-bleed.
//
//   2. iPhone grids (emoji pickers, color swatches) hardcoded N columns
//      end up with huge cells on iPad. `iPadGridColumns(_:scale:)` derives
//      a higher column count when the horizontal size class is regular.
//
// Both intentionally use the SwiftUI `\.horizontalSizeClass` environment
// rather than `UIDevice.current.userInterfaceIdiom` — the former correctly
// handles iPad multitasking (Slide Over / Split View) where the app may be
// running in a compact-width slot on an iPad.

extension View {
    /// Constrain the inner content column to a readable width on iPad while
    /// remaining full-width on iPhone. Use on the root of long-form scrollable
    /// content (Paywall, About, Privacy, etc.).
    @ViewBuilder
    func readableContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Returns an array of `GridItem`s sized for the current horizontal size class.
/// On compact (iPhone), uses `iPhoneCount`. On regular (iPad), uses
/// `Int(iPhoneCount * scale)`. Defaults `scale` to 1.6 — empirically a good
/// balance for emoji/color pickers (e.g. 8 → 12, 5 → 8).
@MainActor
func iPadGridColumns(
    iPhone iPhoneCount: Int,
    scale: Double = 1.6,
    spacing: CGFloat = 8,
    sizeClass: UserInterfaceSizeClass?
) -> [GridItem] {
    let count: Int = {
        guard sizeClass == .regular else { return iPhoneCount }
        return max(iPhoneCount, Int((Double(iPhoneCount) * scale).rounded()))
    }()
    return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
}

/// Scales a base CGFloat (font size, icon size, frame side, padding) for iPad.
/// On compact (iPhone), returns `base` unchanged. On regular (iPad), returns
/// `base * scale`. Default scale `1.25` is calibrated for first-launch popups
/// where readability matters most — fonts, icons, and circle backgrounds all
/// look proportionally bigger on iPad without breaking layout density.
///
/// Usage: `.font(.system(size: ipScaled(26, sizeClass: hSizeClass), weight: .bold))`
@MainActor
func ipScaled(
    _ base: CGFloat,
    scale: CGFloat = 1.25,
    sizeClass: UserInterfaceSizeClass?
) -> CGFloat {
    sizeClass == .regular ? base * scale : base
}
