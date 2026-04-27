import Foundation

/// Public URLs hosting StudySync's Privacy Policy + Terms of Use, required
/// by Apple Guideline 3.1.2 (Paywalls must include functional links to both)
/// and 5.1.1 (Privacy Policy must be reachable from inside the app).
///
/// Hosted on the project's GitHub Pages site. If you change paths on the
/// site, update them here in one place.
enum AppLegalURL {
    /// Site root — used as the App Store "Marketing URL" / about-screen
    /// "Project Website" link.
    static let homepage = URL(string: "https://yangmt0409.github.io/StudySync/")!

    /// Privacy Policy. Apple reviewer must be able to reach this from the
    /// paywall and from Settings.
    static let privacyPolicy = URL(string: "https://yangmt0409.github.io/StudySync/privacy")!

    /// Terms of Use (EULA). Required next to the paywall purchase button.
    static let termsOfUse = URL(string: "https://yangmt0409.github.io/StudySync/terms")!
}
