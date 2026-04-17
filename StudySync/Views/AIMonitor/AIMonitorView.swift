import SwiftUI
import SwiftData

struct AIMonitorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIAccount.createdAt) private var accounts: [AIAccount]

    @State private var showAddAccount = false
    @State private var selectedAccount: AIAccount?
    @State private var hasAppeared = false

    private let usageService = AIUsageService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                if accounts.isEmpty {
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
        VStack(spacing: 24) {
            Spacer()

            // Provider icons row (including Codex)
            HStack(spacing: 16) {
                ProviderLogoView(provider: .claude, size: 52, iconSize: 24)
                ProviderLogoView(provider: .openai, size: 52, iconSize: 26)
                CodexLogoView(size: 52, iconSize: 24)
                ProviderLogoView(provider: .google, size: 52, iconSize: 24)
            }

            VStack(spacing: 8) {
                Text(L10n.aiNoAccounts)
                    .font(.title3.bold())
                Text(L10n.aiNoAccountsDesc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Button {
                showAddAccount = true
            } label: {
                Text(L10n.aiAddAccount)
                    .font(.headline)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
            Spacer()
        }
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

                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
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
