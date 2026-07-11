import Foundation
import StoreKit

/// Detects the user's App Store storefront country.
/// Used to gate region-specific features per Apple review requirements — for example,
/// Generative AI services (ChatGPT, etc.) require permits in China, so AI Monitor
/// must be hidden on the China (CN) storefront.
enum StorefrontService {

    private static var cachedIsChina: Bool?

    /// True when the current App Store storefront is China mainland (CHN).
    /// Reads the cached value set by `refresh()` — falls back to the device region
    /// locale so the check works before the first `refresh()` call finishes.
    static var isChina: Bool {
        if let cached = cachedIsChina { return cached }
        // Prefer the structured region code ("CN"). When that's unavailable the
        // old fallback compared the FULL locale identifier (e.g. "zh_CN") against
        // "CN" and never matched — so parse the region out of the identifier.
        if let region = Locale.current.region?.identifier {
            return region == "CN"
        }
        let identifier = Locale.current.identifier
        return identifier == "CN" || identifier.hasSuffix("_CN") || identifier.hasSuffix("-CN")
    }

    /// Call once at app launch (and on storefront change if you subscribe to updates)
    /// to cache the authoritative StoreKit storefront country code. More reliable than
    /// `Locale.current.region` which reflects device language/region settings, not the
    /// actual App Store storefront.
    @MainActor
    static func refresh() async {
        if let storefront = await Storefront.current {
            cachedIsChina = storefront.countryCode == "CHN"
        }
    }
}
