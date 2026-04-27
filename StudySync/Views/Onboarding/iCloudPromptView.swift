import SwiftUI

/// One-shot prompt that asks the user whether to enable iCloud sync. Shown
/// the first time `MainTabView` appears after install (or after hotfix
/// update for existing v1.0 users).
///
/// Why a separate sheet from `OnboardingView`:
///   • `OnboardingView` only shows for users with `hasCompletedOnboarding =
///     false`. Users who already completed v1.0 onboarding wouldn't see a
///     new step added there — but those are exactly the users who lost
///     data in the v1.0 dual-container bug and most need to know iCloud
///     sync exists.
///   • Gating on a fresh `UserDefaults` key (`hasShownICloudPrompt`) means
///     every user sees it once, regardless of when they installed.
///
/// Why we don't auto-enable iCloud:
///   • Some users in mainland China have iCloud disabled at the system
///     level (it works in CN but with caveats); auto-enabling would cause
///     CloudKit container init to fail and the local-fallback path runs.
///   • Privacy: enabling cloud sync without consent isn't great even if
///     the data isn't sensitive.
///   • Apple guidelines: "user must opt in to cloud features".
///
/// Why we don't restart the app:
///   • iOS doesn't allow programmatic relaunch (Apple guideline rejection).
///   • The existing `iCloudSyncManager` comment says "changes take effect
///     after app restart" — we just save the preference and let the user
///     reopen the app in their own time. We tell them this in the UI.
struct iCloudPromptView: View {
    @AppStorage("hasShownICloudPrompt") private var hasShownPrompt = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var didEnable = false

    var body: some View {
        ZStack {
            // Soft gradient bg, matching the existing OnboardingView aesthetic
            LinearGradient(
                colors: [
                    SSColor.brand.opacity(SSOpacity.tagBackground),
                    Color(hex: "#A78BFA").opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    SSColor.brand.opacity(0.18),
                                    Color(hex: "#A78BFA").opacity(0.10),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(
                            width: ipScaled(140, sizeClass: hSizeClass),
                            height: ipScaled(140, sizeClass: hSizeClass)
                        )
                    Image(systemName: didEnable ? "checkmark.icloud.fill" : "icloud.fill")
                        .font(.system(size: ipScaled(64, sizeClass: hSizeClass), weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SSColor.brand, Color(hex: "#A78BFA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce, value: didEnable)
                }
                .padding(.bottom, 32)

                // Title + body
                Text(L10n.iCloudPromptTitle)
                    .font(.system(size: ipScaled(26, sizeClass: hSizeClass), weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(L10n.iCloudPromptSubtitle)
                    .font(.system(size: ipScaled(15, sizeClass: hSizeClass)))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 12)

                // Bullet rows — visual hierarchy + scannability
                VStack(alignment: .leading, spacing: SSSpacing.lgXl) {
                    benefitRow(
                        icon: "iphone.and.arrow.forward",
                        title: L10n.iCloudPromptBenefit1Title,
                        desc: L10n.iCloudPromptBenefit1Desc
                    )
                    benefitRow(
                        icon: "shield.lefthalf.filled",
                        title: L10n.iCloudPromptBenefit2Title,
                        desc: L10n.iCloudPromptBenefit2Desc
                    )
                    benefitRow(
                        icon: "lock.fill",
                        title: L10n.iCloudPromptBenefit3Title,
                        desc: L10n.iCloudPromptBenefit3Desc
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)

                Spacer()

                if didEnable {
                    // Post-enable confirmation — explain the restart requirement
                    // without making it feel like a disruption.
                    Text(L10n.iCloudPromptRestartNote)
                        .font(.system(size: ipScaled(13, sizeClass: hSizeClass)))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }

                // CTAs
                VStack(spacing: SSSpacing.mdLg) {
                    Button {
                        enable()
                    } label: {
                        Text(didEnable ? L10n.iCloudPromptDone : L10n.iCloudPromptEnable)
                            .font(.system(size: ipScaled(17, sizeClass: hSizeClass), weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ipScaled(16, sizeClass: hSizeClass))
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [SSColor.brand, Color(hex: "#A78BFA")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .disabled(didEnable && hasShownPrompt)

                    if !didEnable {
                        Button {
                            skip()
                        } label: {
                            Text(L10n.iCloudPromptSkip)
                                .font(.system(size: ipScaled(15, sizeClass: hSizeClass), weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, SSSpacing.md)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .readableContentWidth(560)
        }
    }

    // MARK: - Components

    private func benefitRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: SSSpacing.lgXl) {
            Image(systemName: icon)
                .font(.system(size: ipScaled(18, sizeClass: hSizeClass), weight: .semibold))
                .foregroundStyle(SSColor.brand)
                .frame(
                    width: ipScaled(32, sizeClass: hSizeClass),
                    height: ipScaled(32, sizeClass: hSizeClass)
                )
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(SSColor.brand.opacity(SSOpacity.tagBackground))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: ipScaled(14, sizeClass: hSizeClass), weight: .semibold))
                Text(desc)
                    .font(.system(size: ipScaled(12, sizeClass: hSizeClass)))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func enable() {
        if didEnable {
            // Second tap is "done" — close.
            hasShownPrompt = true
            dismiss()
            return
        }
        HapticEngine.shared.success()
        iCloudSyncManager.shared.isEnabled = true
        withAnimation(.spring(response: 0.35)) {
            didEnable = true
        }
    }

    private func skip() {
        HapticEngine.shared.lightImpact()
        // Don't toggle anything — leave iCloudSyncManager.isEnabled at its
        // current value (default false). Just record that we asked.
        hasShownPrompt = true
        dismiss()
    }
}

#Preview {
    iCloudPromptView()
}
