import SwiftUI

/// First-run welcome / orientation flow. Presented as a fullScreenCover from
/// `SplashScreenView` when `hasCompletedOnboarding` is false. Four pages:
/// welcome → core features → notification permission → ready.
///
/// Setting `hasCompletedOnboarding = true` dismisses the cover permanently.
/// We do NOT seed sample events here — `HomeView.onAppear` already handles
/// that for empty databases.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var notificationGranted: Bool?

    private let totalPages = 4

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#5B7FFF").opacity(0.12),
                    Color(hex: "#A78BFA").opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (not on last page)
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button(L10n.onboardingSkip) {
                            complete()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(height: 44)

                // Pages
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    notificationsPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Dots + primary button
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? Color(hex: "#5B7FFF") : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == currentPage ? 1.2 : 1.0)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    primaryButton
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#5B7FFF"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text(L10n.onboardingWelcomeTitle)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingWelcomeSubtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    private var featuresPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 20)

            Text(L10n.onboardingFeaturesTitle)
                .font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 24)

            VStack(spacing: 18) {
                featureRow(
                    icon: "calendar.badge.clock",
                    color: "#5B7FFF",
                    title: L10n.onboardingFeatureCountdown,
                    desc: L10n.onboardingFeatureCountdownDesc
                )
                featureRow(
                    icon: "globe.americas.fill",
                    color: "#4ECDC4",
                    title: L10n.onboardingFeatureDualClock,
                    desc: L10n.onboardingFeatureDualClockDesc
                )
                featureRow(
                    icon: "target",
                    color: "#A78BFA",
                    title: L10n.onboardingFeatureGoals,
                    desc: L10n.onboardingFeatureGoalsDesc
                )
                featureRow(
                    icon: "person.3.fill",
                    color: "#FFB347",
                    title: L10n.onboardingFeatureTeam,
                    desc: L10n.onboardingFeatureTeamDesc
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var notificationsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color(hex: "#FF6B6B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text(L10n.onboardingNotifTitle)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingNotifSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let granted = notificationGranted {
                HStack(spacing: 6) {
                    Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(granted ? .green : .secondary)
                    Text(granted ? L10n.onboardingNotifGranted : L10n.onboardingNotifDenied)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            Spacer()
        }
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, Color(hex: "#4ECDC4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: currentPage)

            VStack(spacing: 12) {
                Text(L10n.onboardingReadyTitle)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingReadySubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, color: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: color))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: color).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryTap()
        } label: {
            Text(primaryButtonTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#5B7FFF"), Color(hex: "#A78BFA")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case 0, 1: return L10n.onboardingNext
        case 2: return notificationGranted == nil ? L10n.onboardingAllowNotif : L10n.onboardingNext
        case 3: return L10n.onboardingGetStarted
        default: return L10n.onboardingNext
        }
    }

    // MARK: - Actions

    private func handlePrimaryTap() {
        HapticEngine.shared.lightImpact()

        switch currentPage {
        case 0, 1:
            withAnimation { currentPage += 1 }
        case 2:
            if notificationGranted == nil {
                Task {
                    let granted = await NotificationManager.shared.requestPermission()
                    await MainActor.run {
                        withAnimation { notificationGranted = granted }
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        withAnimation { currentPage += 1 }
                    }
                }
            } else {
                withAnimation { currentPage += 1 }
            }
        case 3:
            complete()
        default:
            break
        }
    }

    private func complete() {
        HapticEngine.shared.success()
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
