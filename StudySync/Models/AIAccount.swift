import Foundation
import SwiftData

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case claude
    case openai
    case google

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        case .google: return "Gemini"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "sparkle"
        case .openai: return "bubble.left.fill"
        case .google: return "star.fill"
        }
    }

    /// Asset catalog logo name (official brand logos)
    var logoAsset: String {
        switch self {
        case .claude: return "logo_claude"
        case .openai: return "logo_openai"
        case .google: return "logo_gemini"
        }
    }

    var colorHex: String {
        switch self {
        case .claude: return "#D97757"
        case .openai: return "#10A37F"
        case .google: return "#4285F4"
        }
    }

    var loginURL: String {
        switch self {
        case .claude: return "https://claude.ai/login"
        case .openai: return "https://chatgpt.com/auth/login"
        case .google: return "https://aistudio.google.com"
        }
    }

    var usagePageURL: String {
        switch self {
        case .claude: return "https://claude.ai/settings/usage"
        case .openai: return "https://chatgpt.com"
        case .google: return "https://aistudio.google.com/rate-limit?timeRange=last-28-days"
        }
    }

    /// All providers support auto-fetch (Claude via API, others via WebView scraping)
    var hasUsageAPI: Bool { true }

    // MARK: - Per-provider Window Labels

    /// Card view short label for primary window
    var windowLabel1: String {
        switch self {
        case .claude: return L10n.ai5hWindow
        case .openai: return L10n.aiCodexTasks
        case .google: return L10n.aiDailyWindow
        }
    }

    /// Card view short label for secondary window
    var windowLabel2: String {
        switch self {
        case .claude: return L10n.ai7dWindow
        case .openai: return L10n.aiChatStatus
        case .google: return L10n.aiDailyWindow
        }
    }

    /// Detail view label for primary window
    var windowDetailLabel1: String {
        switch self {
        case .claude: return L10n.ai5hSession
        case .openai: return L10n.aiCodexUsage
        case .google: return L10n.aiDailyUsage
        }
    }

    /// Detail view label for secondary window
    var windowDetailLabel2: String {
        switch self {
        case .claude: return L10n.ai7dWeekly
        case .openai: return L10n.aiChatStatus
        case .google: return L10n.aiDailyUsage
        }
    }
}

@Model
final class AIAccount {
    var id: UUID = UUID()
    var providerRaw: String = "claude"
    var nickname: String = ""
    var email: String?
    var organizationId: String?
    var planName: String?

    // Claude usage data (0-100 scale)
    var utilization5h: Double = 0
    var resetTime5h: Date?
    var utilization7d: Double = 0
    var resetTime7d: Date?
    var utilization7dOpus: Double = 0
    var resetTime7dOpus: Date?
    var utilization7dSonnet: Double = 0
    var resetTime7dSonnet: Date?

    // Extra usage (Claude)
    var extraUsageEnabled: Bool = false
    var extraUsageLimitCents: Int = 0
    var extraUsageUsedCents: Int = 0

    // OpenAI Codex
    var codexTasksUsed: Int = 0
    var codexTasksLimit: Int = 0
    var isRateLimited: Bool = false

    // State
    var lastFetchedAt: Date?
    var isAuthenticated: Bool = false
    var isEnabled: Bool = true
    var notifyThreshold: Int = 80  // percent (e.g. 80 means alert when usage >= 80%)
    // Per-tier notification flags (threshold / 95% / 100%) × (5h / 7d window).
    // Each flag latches true after firing and clears when usage drops below its tier,
    // so each tier alerts at most once per usage cycle.
    var notified5h: Bool = false          // custom threshold, 5h window
    var notified7d: Bool = false          // custom threshold, 7d window
    var notified95_5h: Bool = false
    var notified95_7d: Bool = false
    var notifiedLimit5h: Bool = false
    var notifiedLimit7d: Bool = false
    var createdAt: Date = Date()

    var provider: AIProvider {
        get { AIProvider(rawValue: providerRaw) ?? .claude }
        set { providerRaw = newValue.rawValue }
    }

    // MARK: - Computed

    /// Highest current utilization across all windows
    var peakUtilization: Double {
        max(utilization5h, utilization7d)
    }

    /// Whether any window exceeds the notify threshold
    var isOverThreshold: Bool {
        utilization5h >= Double(notifyThreshold) || utilization7d >= Double(notifyThreshold)
    }

    /// Earliest reset time
    var nextResetDate: Date? {
        [resetTime5h, resetTime7d].compactMap { $0 }.filter { $0 > Date() }.min()
    }

    /// Codex usage percentage (0-100)
    var codexUtilization: Double {
        guard codexTasksLimit > 0 else { return 0 }
        return Double(codexTasksUsed) / Double(codexTasksLimit) * 100.0
    }

    /// Whether Codex data is available
    var hasCodexData: Bool {
        codexTasksLimit > 0
    }

    var extraUsageLimitDollars: Double {
        Double(extraUsageLimitCents) / 100.0
    }

    var extraUsageUsedDollars: Double {
        Double(extraUsageUsedCents) / 100.0
    }

    init(provider: AIProvider, nickname: String = "") {
        self.id = UUID()
        self.providerRaw = provider.rawValue
        self.nickname = nickname.isEmpty ? provider.displayName : nickname
        self.utilization5h = 0
        self.utilization7d = 0
        self.utilization7dOpus = 0
        self.utilization7dSonnet = 0
        self.extraUsageEnabled = false
        self.extraUsageLimitCents = 0
        self.extraUsageUsedCents = 0
        self.codexTasksUsed = 0
        self.codexTasksLimit = 0
        self.isRateLimited = false
        self.isAuthenticated = false
        self.isEnabled = true
        self.notifyThreshold = 80
        self.notified5h = false
        self.notified7d = false
        self.notified95_5h = false
        self.notified95_7d = false
        self.notifiedLimit5h = false
        self.notifiedLimit7d = false
        self.createdAt = Date()
    }
}
