import SwiftUI
import SwiftData

struct AddAIAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingAccounts: [AIAccount]

    @State private var loginProvider: AIProvider?
    @State private var isLoggingIn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text(L10n.aiAddAccount)
                    .font(.title2.bold())

                Text(L10n.aiAddAccountDesc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        providerButton(provider)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()
                Spacer()
            }
            .navigationTitle(L10n.aiAddAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .fullScreenCover(item: $loginProvider) { provider in
                loginView(for: provider)
            }
        }
    }

    // MARK: - Provider Button

    private func hasExistingAccount(for provider: AIProvider) -> Bool {
        existingAccounts.contains { $0.providerRaw == provider.rawValue }
    }

    private func providerButton(_ provider: AIProvider) -> some View {
        let exists = hasExistingAccount(for: provider)

        return Button {
            loginProvider = provider
        } label: {
            HStack(spacing: 14) {
                ProviderLogoView(provider: provider, size: 44, iconSize: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundStyle(exists ? .secondary : .primary)
                    Text(exists ? L10n.aiAlreadyAdded : L10n.aiAutoTrack)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if exists {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(exists)
    }

    // MARK: - Login View

    private func loginView(for provider: AIProvider) -> some View {
        NavigationStack {
            Group {
                if provider == .claude {
                    claudeLoginView
                } else {
                    genericLoginView(for: provider)
                }
            }
            .navigationTitle(L10n.aiLoginTo(provider: provider.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        loginProvider = nil
                    }
                }
            }
        }
    }

    private var claudeLoginView: some View {
        VStack(spacing: 0) {
            if isLoggingIn {
                ProgressView(L10n.aiConnecting)
                    .padding()
            }

            // WebView login — cookies persist in WKWebsiteDataStore.default()
            // Auto-detects when user logs in (session cookie appears)
            ClaudeWebLoginView { _ in
                createClaudeAccount()
            }

            // Manual confirm button (fallback when auto-detection fails)
            Button {
                createClaudeAccount()
            } label: {
                Text(L10n.aiConfirmLoggedIn)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn)
            .padding()
        }
    }

    private func createClaudeAccount() {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        let account = AIAccount(provider: .claude)
        // No need to store cookies — WebView scraper uses WKWebsiteDataStore.default()
        // which already has the session from login
        account.isAuthenticated = true
        modelContext.insert(account)
        AIAccountSyncService.shared.pushAccount(account)
        HapticEngine.shared.success()

        Task {
            await AIUsageService.shared.fetchUsage(for: account)
            AIAccountSyncService.shared.pushAccount(account)
            isLoggingIn = false
            loginProvider = nil
            dismiss()
        }
    }

    private func genericLoginView(for provider: AIProvider) -> some View {
        VStack(spacing: 0) {
            if isLoggingIn {
                ProgressView(L10n.aiConnecting)
                    .padding()
            }

            if let url = URL(string: provider.loginURL) {
                AIWebView(url: url)
            }

            Button {
                isLoggingIn = true
                let account = AIAccount(provider: provider)
                account.isAuthenticated = true
                modelContext.insert(account)
                AIAccountSyncService.shared.pushAccount(account)
                HapticEngine.shared.success()

                Task {
                    await AIUsageService.shared.fetchUsage(for: account)
                    AIAccountSyncService.shared.pushAccount(account)
                    isLoggingIn = false
                    loginProvider = nil
                    dismiss()
                }
            } label: {
                Text(L10n.aiConfirmLoggedIn)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn)
            .padding()
        }
    }
}
