import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            SSColor.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // App Logo & Info
                    appHeader

                    // Developer
                    infoSection(title: L10n.developer) {
                        personRow(name: "Maitong Yang", role: L10n.aboutDevRole, emoji: "👨‍💻")
                    }

                    // Acknowledgements
                    infoSection(title: L10n.acknowledgements) {
                        personRow(name: "Yixuan Wei", emoji: "🧑🏻‍💼")
                        personRow(name: "Chuxiang Jin", emoji: "🎻")
                    }

                    // Open Source
                    infoSection(title: L10n.openSource) {
                        libraryRow(name: "Firebase", desc: "Google")
                    }

                    // Legal — Privacy Policy + Terms of Use links live here
                    // so the App Store reviewer can find them outside the
                    // paywall (Guideline 5.1.1 wants them reachable from
                    // anywhere in the app, not only the purchase flow).
                    infoSection(title: L10n.legalSection) {
                        legalLinkRow(
                            title: L10n.privacyPolicy,
                            symbol: "hand.raised.fill",
                            url: AppLegalURL.privacyPolicy
                        )
                        legalLinkRow(
                            title: L10n.termsOfUse,
                            symbol: "doc.text.fill",
                            url: AppLegalURL.termsOfUse
                        )
                    }

                    // Footer
                    Text(L10n.aboutFooter)
                        .font(SSFont.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, SSSpacing.md)

                    Text(L10n.aboutMadeWith)
                        .font(SSFont.footnote)
                        .foregroundStyle(.quaternary)
                        .padding(.bottom, SSSpacing.xxl)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xl)
                .readableContentWidth()
            }
        }
        .navigationTitle(L10n.about)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: SSRadius.appIcon, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SSColor.brand, SSColor.brandPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                )
                .shadow(color: SSColor.brand.opacity(0.3), radius: 12, y: 6)

            Text(L10n.appName)
                .font(SSFont.heading1)

            Text(L10n.appSubtitle)
                .font(SSFont.secondary)
                .foregroundStyle(.secondary)

            Text("v\(appVersion) (\(buildNumber))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SSSpacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.large, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Info Section

    private func infoSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, SSSpacing.xxl)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(SSColor.backgroundCard)
            )
        }
    }

    // MARK: - Person Row

    private func personRow(name: String, role: String? = nil, emoji: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(SSFont.heading1)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(SSColor.fillTertiary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(SSFont.bodyMedium)

                if let role {
                    Text(role)
                        .font(SSFont.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, SSSpacing.xl)
        .padding(.vertical, SSSpacing.lg)
    }

    // MARK: - Legal Link Row

    /// Row that opens an external URL in the system browser. Used for
    /// Privacy Policy / Terms of Use links — Apple requires these be
    /// reachable from a non-paywall context too.
    private func legalLinkRow(title: String, symbol: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SSColor.brand)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(SSColor.brand.opacity(0.12)))

                Text(title)
                    .font(SSFont.bodyMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.vertical, SSSpacing.lg)
        }
    }

    // MARK: - Library Row

    private func libraryRow(name: String, desc: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(SSFont.bodySmallMedium)
                Text(desc)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, SSSpacing.xl)
        .padding(.vertical, SSSpacing.lg)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
