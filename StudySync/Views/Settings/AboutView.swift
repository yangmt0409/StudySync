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
                        personRow(name: "Yixuan Wei", emoji: "🌟")
                    }

                    // Open Source
                    infoSection(title: L10n.openSource) {
                        libraryRow(name: "Firebase", desc: "Google")
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
