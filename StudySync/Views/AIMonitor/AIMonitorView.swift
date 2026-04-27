import SwiftUI
import SwiftData

struct AIMonitorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query(sort: \AIAccount.createdAt) private var accounts: [AIAccount]

    /// Accounts visible in the current storefront (hides ChatGPT in CN per Apple review).
    private var visibleAccounts: [AIAccount] {
        accounts.filter { AIProvider.availableCases.contains($0.provider) }
    }

    /// Accounts sorted by urgency: unauthenticated first, then by peak utilization (highest first)
    private var sortedAccounts: [AIAccount] {
        visibleAccounts.sorted { a, b in
            // Unauthenticated accounts bubble to top
            if !a.isAuthenticated && b.isAuthenticated { return true }
            if a.isAuthenticated && !b.isAuthenticated { return false }
            // Then sort by peak utilization descending
            return a.peakUtilization > b.peakUtilization
        }
    }

    @State private var showAddAccount = false
    @State private var selectedAccount: AIAccount?
    @State private var hasAppeared = false

    private let usageService = AIUsageService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                if visibleAccounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle(L10n.aiMonitor)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddAccount = true
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAIAccountView()
            }
            .navigationDestination(item: $selectedAccount) { account in
                AIAccountDetailView(account: account)
            }
            .task {
                // Provide modelContext to AIUsageService for snapshot recording
                AIUsageService.shared.modelContext = modelContext

                // Hydrate AI account list from Firestore on first appearance —
                // restores nicknames / thresholds / last usage snapshot after
                // reinstall.
                await AIAccountSyncService.shared.pullAll(context: modelContext)

                // If a Claude session WebView was lost (e.g. app restart),
                // attempt silent restore from persisted WKWebsiteDataStore
                // cookies so the user doesn't have to re-login manually.
                if !ClaudeAPIFetcher.shared.hasSession {
                    _ = await ClaudeAPIFetcher.shared.restoreSession()
                }
            }
            .task(id: accounts.count) {
                guard !accounts.isEmpty else { return }
                // Skip immediate fetch if all accounts were just updated (< 30s ago)
                let recentlyUpdated = accounts.allSatisfy {
                    guard let last = $0.lastFetchedAt else { return false }
                    return Date().timeIntervalSince(last) < 30
                }
                if !recentlyUpdated {
                    await usageService.fetchAllUsage(accounts: accounts)
                }
                // Auto-refresh every 5 minutes
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(300))
                    guard !Task.isCancelled else { break }
                    await usageService.fetchAllUsage(accounts: accounts)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let logoSize = ipScaled(52, scale: 1.4, sizeClass: hSizeClass)
        let iconSize = ipScaled(24, scale: 1.4, sizeClass: hSizeClass)
        let openAIIconSize = ipScaled(26, scale: 1.4, sizeClass: hSizeClass)
        return VStack(spacing: ipScaled(24, sizeClass: hSizeClass)) {
            Spacer()

            // Provider icons row (including Codex)
            HStack(spacing: 16) {
                ProviderLogoView(provider: .claude, size: logoSize, iconSize: iconSize)
                ProviderLogoView(provider: .openai, size: logoSize, iconSize: openAIIconSize)
                CodexLogoView(size: logoSize, iconSize: iconSize)
                ProviderLogoView(provider: .google, size: logoSize, iconSize: iconSize)
            }

            VStack(spacing: 8) {
                Text(L10n.aiNoAccounts)
                    .font(.system(size: ipScaled(20, scale: 1.4, sizeClass: hSizeClass), weight: .bold))
                Text(L10n.aiNoAccountsDesc)
                    .font(.system(size: ipScaled(15, scale: 1.4, sizeClass: hSizeClass)))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Button {
                showAddAccount = true
            } label: {
                Text(L10n.aiAddAccount)
                    .font(.system(size: ipScaled(17, scale: 1.4, sizeClass: hSizeClass), weight: .semibold))
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Account List

    private var accountList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Error banner
                if let error = usageService.fetchError {
                    errorBanner(error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ForEach(Array(sortedAccounts.enumerated()), id: \.element.id) { index, account in
                    AIUsageCardView(account: account)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticEngine.shared.selection()
                            selectedAccount = account
                        }
                        // #14 Entry animation
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            .spring(duration: 0.5).delay(Double(index) * 0.1),
                            value: hasAppeared
                        )
                        // #13 Accessibility
                        .accessibilityLabel("\(account.provider.displayName)")
                        .accessibilityHint(L10n.aiTapToViewUsage)
                }
            }
            .padding(.horizontal)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxl)
            .animation(.easeInOut(duration: 0.3), value: usageService.fetchError == nil)
        }
        .refreshable {
            await usageService.fetchAllUsage(accounts: accounts)
        }
        .onAppear {
            if !hasAppeared {
                withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                withAnimation { usageService.fetchError = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(SSSpacing.lg)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
