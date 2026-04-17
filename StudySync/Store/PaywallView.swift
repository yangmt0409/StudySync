import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var store = StoreManager.shared

    @State private var isPurchasing = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部标题
                    headerSection

                    // 功能对比
                    featureComparisonSection

                    // 购买按钮
                    purchaseSection

                    // 恢复购买
                    restoreSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
            .task {
                await store.loadProduct()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)

            Text(L10n.unlockPro)
                .font(.system(size: 26, weight: .bold))

            Text(L10n.oneTimePurchase)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(spacing: 0) {
            // 表头
            HStack {
                Text(L10n.feature)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Free")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 60)

                Text("Pro")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Pro 独享 / 配额升级
            featureRow(name: L10n.countdownEvents, free: L10n.fiveLimit, pro: L10n.unlimited)
            featureRow(name: L10n.teamProjects, free: L10n.oneLimit, pro: L10n.unlimited)
            featureRow(name: L10n.studyGoals, free: L10n.threeLimit, pro: L10n.unlimited)
            featureRow(name: L10n.countdownCustomization, free: false, pro: true)
            featureRow(name: L10n.shareCardNoWatermark, free: false, pro: true)

            // 始终免费 — 让用户看到 Pro 之外的东西也是完整的
            featureRow(name: L10n.aiMonitorFree, free: true, pro: true)
            featureRow(name: L10n.socialFeatures, free: true, pro: true)
            featureRow(name: L10n.cloudSyncAllFree, free: true, pro: true)
            featureRow(name: L10n.dualClockDisplay, free: true, pro: true, isLast: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    private func featureRow(name: String, free: Any, pro: Any, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(name)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)

                featureCell(value: free)
                    .frame(width: 60)

                featureCell(value: pro)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            if !isLast {
                Divider().padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func featureCell(value: Any) -> some View {
        if let bool = value as? Bool {
            Image(systemName: bool ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 16))
                .foregroundStyle(bool ? .green : .secondary.opacity(0.5))
        } else if let text = value as? String {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Sandbox Environment

    /// True when running under TestFlight or a Xcode-signed sandbox build.
    /// Used to reassure pre-launch beta testers that any purchase they make
    /// is free (sandbox environment).
    private static var isSandboxEnvironment: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.lastPathComponent == "sandboxReceipt"
    }

    @ViewBuilder
    private var sandboxBanner: some View {
        if Self.isSandboxEnvironment {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "testtube.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.sandboxBannerTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.sandboxBannerBody)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            sandboxBanner

            Button {
                Task {
                    isPurchasing = true
                    let success = await store.purchase()
                    isPurchasing = false
                    if success {
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                    }

                    if let product = store.product {
                        Text(L10n.upgradePriceButton(product.displayPrice))
                            .font(.system(size: 17, weight: .bold))
                    } else {
                        Text(L10n.upgradePro)
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(isPurchasing || store.isLoading)

            if let error = store.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button {
            Task { await store.restore() }
        } label: {
            Text(L10n.restorePurchase)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
        }
        .disabled(store.isLoading)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text(L10n.purchaseSuccess)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text(L10n.allProUnlocked)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .transition(.opacity)
    }
}

#Preview {
    PaywallView()
}
