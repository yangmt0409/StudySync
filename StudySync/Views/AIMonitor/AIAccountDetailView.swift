import SwiftUI
import SwiftData
import UIKit

struct AIAccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var account: AIAccount

    @State private var isRefreshing = false
    @State private var showDeleteAlert = false
    @State private var showRelogin = false
    @State private var showDebugLog = true

    private var usageService: AIUsageService { AIUsageService.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if account.provider == .openai {
                    openAIDetailCard
                } else {
                    usageWindowsCard
                }
                if account.extraUsageEnabled {
                    extraUsageCard
                }
                // Re-login when session expired
                if !account.isAuthenticated {
                    reloginCard
                }
                // Claude-only: in-app debug log for API responses
                if account.provider == .claude {
                    debugLogCard
                }
                settingsCard
                deleteButton
            }
            .padding()
        }
        .navigationTitle(account.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .sheet(isPresented: $showRelogin) {
            NavigationStack {
                VStack(spacing: 0) {
                    if account.provider == .claude {
                        // Claude: WebView login — cookies stay in WKWebsiteDataStore.default()
                        // scraper will use them automatically on next fetch
                        ClaudeWebLoginView { _ in
                            account.isAuthenticated = true
                            showRelogin = false
                            Task { await refresh() }
                        }

                        // Manual confirm fallback
                        Button {
                            HapticEngine.shared.lightImpact()
                            account.isAuthenticated = true
                            showRelogin = false
                            Task { await refresh() }
                        } label: {
                            Text(L10n.aiConfirmLoggedIn)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    } else {
                        if let url = URL(string: account.provider.loginURL) {
                            AIWebView(url: url)
                        }
                        Button {
                            account.isAuthenticated = true
                            showRelogin = false
                            Task { await refresh() }
                        } label: {
                            Text(L10n.aiConfirmLoggedIn)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
                .navigationTitle(L10n.aiLoginTo(provider: account.provider.displayName))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancel) { showRelogin = false }
                    }
                }
            }
        }
        .alert(L10n.confirmDelete, isPresented: $showDeleteAlert) {
            Button(L10n.delete, role: .destructive) { deleteAccount() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.aiDeleteConfirm)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Provider icon
            ProviderLogoView(provider: account.provider, size: 64, iconSize: 30)

            // Plan badge
            if let plan = account.planName {
                Text(plan)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: account.provider.colorHex).opacity(0.15))
                    .foregroundStyle(Color(hex: account.provider.colorHex))
                    .clipShape(Capsule())
            }

            // Email
            if let email = account.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Peak hour warning (Claude only)
            if account.provider == .claude && AIUsageCardView.isPeakHour {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text(L10n.aiPeakHourDesc)
                    }
                    .font(.caption.bold())

                    if let endDate = AIUsageCardView.peakEndDate {
                        let remaining = endDate.timeIntervalSince(Date())
                        let h = Int(remaining) / 3600
                        let m = (Int(remaining) % 3600) / 60
                        Text(h > 0 ? L10n.aiPeakEndsInHM(hours: h, mins: m) : L10n.aiPeakEndsInM(mins: m))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 12))
            }

            // Header ring: OpenAI → Codex, Claude → 5h session, others → peak usage
            if account.provider == .openai {
                openAIHeaderRing
            } else if account.provider == .claude {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: account.utilization5h / 100.0)
                        .stroke(usageColor(account.utilization5h), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: account.utilization5h)

                    VStack(spacing: 2) {
                        Text("\(Int(account.utilization5h))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(L10n.ai5hSession)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: account.peakUtilization / 100.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: account.peakUtilization)

                    VStack(spacing: 2) {
                        Text("\(Int(account.peakUtilization))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(L10n.aiPeakUsage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
            }

            // Status warnings
            if !account.isAuthenticated {
                Label(L10n.aiSessionExpired, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange, in: Capsule())
            } else if account.isOverThreshold {
                Label(L10n.aiLowBalanceWarning, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.red, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - OpenAI Detail

    private var openAIDetailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.aiUsageDetail)
                .font(.headline)

            // Plan info
            if let plan = account.planName {
                HStack {
                    Image(systemName: "creditcard")
                        .foregroundStyle(.secondary)
                    Text(L10n.aiPlanInfo)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(plan)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Color(hex: account.provider.colorHex))
                }
            }

            Divider()

            // Codex section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image("logo_codex")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                    Text(L10n.aiCodexUsage)
                        .font(.subheadline.bold())
                    Spacer()
                    if account.hasCodexData {
                        Text("\(account.codexTasksUsed)/\(account.codexTasksLimit)")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(usageColor(account.codexUtilization))
                            .contentTransition(.numericText())
                    }
                }

                if account.hasCodexData {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usageColor(account.codexUtilization).gradient)
                                .frame(width: max(0, geo.size.width * min(account.codexUtilization / 100.0, 1.0)))
                                .animation(.easeInOut(duration: 0.6), value: account.codexUtilization)
                        }
                    }
                    .frame(height: 8)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text(L10n.aiCodexNoData)
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            Divider()

            // Chat status
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.secondary)
                Text(L10n.aiChatStatus)
                    .font(.subheadline.bold())
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(account.isRateLimited ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(account.isRateLimited ? L10n.aiChatLimited : L10n.aiChatNormal)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(account.isRateLimited ? .red : .green)
                }
            }

            if let lastFetched = account.lastFetchedAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(L10n.aiLastUpdated)
                    Text(lastFetched, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Usage Windows

    private var usageWindowsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.aiUsageDetail)
                .font(.headline)

            usageRow(
                title: account.provider.windowDetailLabel1,
                utilization: account.utilization5h,
                resetDate: account.resetTime5h,
                icon: "clock"
            )

            if account.utilization7d > 0 || account.provider == .claude {
                Divider()

                usageRow(
                    title: account.provider.windowDetailLabel2,
                    utilization: account.utilization7d,
                    resetDate: account.resetTime7d,
                    icon: "calendar"
                )
            }

            // Per-model breakdown (Claude only)
            if account.utilization7dOpus > 0 || account.utilization7dSonnet > 0 {
                Divider()

                Text(L10n.aiPerModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if account.utilization7dOpus > 0 {
                    miniUsageRow(title: "Opus", utilization: account.utilization7dOpus)
                }
                if account.utilization7dSonnet > 0 {
                    miniUsageRow(title: "Sonnet", utilization: account.utilization7dSonnet)
                }
            }

            if let lastFetched = account.lastFetchedAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(L10n.aiLastUpdated)
                    Text(lastFetched, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func usageRow(title: String, utilization: Double, resetDate: Date?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(usageColor(utilization))
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(utilization).gradient)
                        .frame(width: max(0, geo.size.width * min(utilization / 100.0, 1.0)))
                        .animation(.easeInOut(duration: 0.6), value: utilization)
                }
            }
            .frame(height: 8)

            if let reset = resetDate, reset > Date() {
                let remaining = reset.timeIntervalSince(Date())
                let hours = Int(remaining) / 3600
                let mins = (Int(remaining) % 3600) / 60
                Text(L10n.aiResetsInTime(hours: hours, mins: mins))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func miniUsageRow(title: String, utilization: Double) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageColor(utilization))
                        .frame(width: max(0, geo.size.width * min(utilization / 100.0, 1.0)))
                        .animation(.easeInOut(duration: 0.6), value: utilization)
                }
            }
            .frame(height: 4)
            Text("\(Int(utilization))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }

    // MARK: - Extra Usage

    private var extraUsageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.aiExtraUsage)
                    .font(.headline)
                Spacer()
                Text(L10n.aiEnabled)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("$\(account.extraUsageUsedDollars, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("/ $\(account.extraUsageLimitDollars, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            let percent = account.extraUsageLimitCents > 0
                ? Double(account.extraUsageUsedCents) / Double(account.extraUsageLimitCents)
                : 0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(percent * 100))
                        .frame(width: max(0, geo.size.width * min(percent, 1.0)))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Re-login

    private var reloginCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text(L10n.aiSessionExpired)
                .font(.subheadline.bold())

            Text(L10n.aiReloginDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showRelogin = true
            } label: {
                Label(L10n.aiRelogin, systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Debug Log (Claude only)

    private var debugLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDebugLog.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Debug Log")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if !usageService.claudeDebugLog.isEmpty {
                        Button {
                            UIPasteboard.general.string = usageService.claudeDebugLog
                            HapticEngine.shared.success()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: account.provider.colorHex))
                        }
                        .buttonStyle(.plain)

                        Button {
                            usageService.clearClaudeDebugLog()
                            HapticEngine.shared.lightImpact()
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                    }
                    Image(systemName: showDebugLog ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                }
            }
            .buttonStyle(.plain)

            if showDebugLog {
                if usageService.claudeDebugLog.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Tap refresh (top-right) to capture API response")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        Text(usageService.claudeDebugLog)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 320)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.aiSettings)
                .font(.headline)

            HStack {
                Text(L10n.aiNotifyAt)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $account.notifyThreshold) {
                    Text("60%").tag(60)
                    Text("70%").tag(70)
                    Text("80%").tag(80)
                    Text("90%").tag(90)
                }
                .pickerStyle(.menu)
                .onChange(of: account.notifyThreshold) { _, _ in
                    AIAccountSyncService.shared.pushAccount(account)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Label(L10n.aiDeleteAccount, systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - OpenAI Header Ring

    private var openAIHeaderRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)

            if account.hasCodexData {
                Circle()
                    .trim(from: 0, to: account.codexUtilization / 100.0)
                    .stroke(usageColor(account.codexUtilization), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: account.codexUtilization)

                VStack(spacing: 2) {
                    Text("\(account.codexTasksUsed)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(verbatim: "/ \(account.codexTasksLimit) Codex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // No Codex data — show status indicator
                VStack(spacing: 6) {
                    Image(systemName: account.isRateLimited ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(account.isRateLimited ? .red : .green)
                    Text(account.isRateLimited ? L10n.aiChatLimited : L10n.aiChatNormal)
                        .font(.caption.bold())
                        .foregroundStyle(account.isRateLimited ? .red : .green)
                }
            }
        }
        .frame(width: 150, height: 150)
    }

    // MARK: - Helpers

    private var ringColor: Color {
        usageColor(account.peakUtilization)
    }

    private func usageColor(_ value: Double) -> Color {
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        if value >= 50 { return .yellow }
        return .green
    }

    private func refresh() async {
        isRefreshing = true
        await usageService.fetchUsage(for: account)
        isRefreshing = false
    }

    private func deleteAccount() {
        KeychainHelper.shared.deleteAPIKey(for: account.id)
        if account.provider == .claude {
            AIUsageService.shared.cancelClaudeResetNotification(accountId: account.id)
        }
        let accountId = account.id
        modelContext.delete(account)
        AIAccountSyncService.shared.deleteAccount(id: accountId)
        dismiss()
    }
}
