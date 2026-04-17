import SwiftUI

struct AIUsageCardView: View {
    let account: AIAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            // Peak hour indicator (Claude only)
            if account.provider == .claude && Self.isPeakHour {
                peakHourBadge
            }

            // Usage bars
            usageBarsView

            // Footer
            footerRow
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Color(hex: account.provider.colorHex).opacity(account.isOverThreshold ? 0.4 : 0),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            providerIcon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.nickname)
                        .font(.headline)
                    if let plan = account.planName {
                        planBadge(plan)
                    }
                }
                if let email = account.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !account.isAuthenticated {
            Label(L10n.aiExpired, systemImage: "exclamationmark.circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.orange)
        } else if account.isOverThreshold {
            Label(L10n.aiLow, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red, in: Capsule())
        }
    }

    private func planBadge(_ plan: String) -> some View {
        Text(plan)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: account.provider.colorHex).opacity(0.15))
            .foregroundStyle(Color(hex: account.provider.colorHex))
            .clipShape(Capsule())
    }

    // MARK: - Usage Bars

    @ViewBuilder
    private var usageBarsView: some View {
        if account.provider == .openai {
            openAIStatusView
        } else {
            standardUsageBars
        }
    }

    // Standard usage bars (Claude / Gemini)
    private var standardUsageBars: some View {
        VStack(spacing: 8) {
            usageBar(
                label: account.provider.windowLabel1,
                value: account.utilization5h,
                resetDate: account.resetTime5h
            )
            if account.utilization7d > 0 || account.provider == .claude {
                usageBar(
                    label: account.provider.windowLabel2,
                    value: account.utilization7d,
                    resetDate: account.resetTime7d
                )
            }
        }
    }

    // OpenAI: Codex usage + chat status
    private var openAIStatusView: some View {
        VStack(spacing: 8) {
            // Codex usage bar (if data available)
            if account.hasCodexData {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 4) {
                            Image("logo_codex")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.secondary)
                            Text(L10n.aiCodexTasks)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(account.codexTasksUsed)/\(account.codexTasksLimit)")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(barColor(account.codexUtilization))
                            .contentTransition(.numericText())
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(account.codexUtilization).gradient)
                                .frame(width: max(0, geo.size.width * min(account.codexUtilization / 100.0, 1.0)))
                                .animation(.easeInOut(duration: 0.6), value: account.codexUtilization)
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Chat status row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption2)
                    Text(L10n.aiChatStatus)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(account.isRateLimited ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                    Text(account.isRateLimited ? L10n.aiChatLimited : L10n.aiChatNormal)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(account.isRateLimited ? .red : .green)
                }
            }
        }
    }

    private func usageBar(label: String, value: Double, resetDate: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(barColor(value))
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(value).gradient)
                        .frame(width: max(0, geo.size.width * min(value / 100.0, 1.0)))
                        .animation(.easeInOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 6)

            if let reset = resetDate, reset > Date() {
                Text(L10n.aiResetsAt(time: reset.formatted(date: .omitted, time: .shortened)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            if let lastFetched = account.lastFetchedAt {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(L10n.aiLastUpdated)
                    .font(.caption2)
                Text(lastFetched, style: .relative)
                    .font(.caption2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Peak Hour (Toronto 8AM-2PM, America/Toronto)

    private static let torontoTZ = TimeZone(identifier: "America/Toronto")!

    static var isPeakHour: Bool {
        var cal = Calendar.current
        cal.timeZone = torontoTZ
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let isWeekday = weekday >= 2 && weekday <= 6
        return isWeekday && hour >= 8 && hour < 14
    }

    static var peakEndDate: Date? {
        guard isPeakHour else { return nil }
        var cal = Calendar.current
        cal.timeZone = torontoTZ
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = 14
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps)
    }

    private var peakHourBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption2)
            Text(L10n.aiPeakHour)
                .font(.caption2.bold())
            Text("2x")
                .font(.system(.caption2, design: .rounded).bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.white.opacity(0.3), in: Capsule())

            if let endDate = Self.peakEndDate {
                Text("\u{00B7}")
                    .font(.caption2)
                let remaining = endDate.timeIntervalSince(Date())
                let h = Int(remaining) / 3600
                let m = (Int(remaining) % 3600) / 60
                Text(h > 0 ? L10n.aiPeakEndsHM(hours: h, mins: m) : L10n.aiPeakEndsM(mins: m))
                    .font(.caption2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.orange.gradient, in: Capsule())
    }

    // MARK: - Helpers

    private var providerIcon: some View {
        ProviderLogoView(provider: account.provider, size: 40, iconSize: 18)
    }

    private func barColor(_ value: Double) -> Color {
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        if value >= 50 { return .yellow }
        return .green
    }
}
