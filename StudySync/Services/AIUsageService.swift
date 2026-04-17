import Foundation
import UserNotifications

@Observable
final class AIUsageService {
    static let shared = AIUsageService()

    var isFetching = false
    var fetchError: String?

    /// In-app debug log for the most recent Claude fetch (visible in UI).
    var claudeDebugLog: String = ""

    private init() {}

    /// Append a line to both console and in-app debug log.
    @MainActor
    private func debugLog(_ message: String) {
        debugPrint(message)
        let timestamp = DateFormatter.debugTime.string(from: Date())
        claudeDebugLog += "[\(timestamp)] \(message)\n\n"
        // Cap at ~20KB to avoid memory issues
        if claudeDebugLog.count > 20_000 {
            claudeDebugLog = String(claudeDebugLog.suffix(15_000))
        }
    }

    @MainActor
    func clearClaudeDebugLog() {
        claudeDebugLog = ""
    }

    // MARK: - Public

    @MainActor
    func fetchUsage(for account: AIAccount) async {
        isFetching = true
        fetchError = nil
        await performFetch(for: account)
        isFetching = false
    }

    @MainActor
    private func performFetch(for account: AIAccount) async {
        switch account.provider {
        case .claude:
            await fetchClaudeAccount(account)
        case .openai:
            await fetchOpenAIAccount(account)
        case .google:
            await fetchGeminiAccount(account)
        }

        // Check tiered thresholds (threshold / 95% / 100%) and notify at most
        // once per tier per usage cycle. Refresh itself no longer pushes a
        // "usage refreshed" notification — only real limit events alert.
        if account.isAuthenticated {
            await checkAndNotify(account: account)
        }

        // Persist refreshed usage snapshot to Firestore so the latest
        // numbers survive reinstall (session still won't — user re-logs once).
        AIAccountSyncService.shared.pushAccount(account)
    }

    // MARK: - Claude (WebView-based API fetch to bypass Cloudflare)

    @MainActor
    private func fetchClaudeAccount(_ account: AIAccount) async {
        // Clear previous log and start fresh
        claudeDebugLog = ""
        debugLog("=== Claude fetch started ===")

        // Check captured session — if lost (e.g. app restart), try auto-restore
        // from cookies persisted in WKWebsiteDataStore.default() before asking
        // the user to re-login.
        let fetcher = ClaudeAPIFetcher.shared
        if !fetcher.hasSession {
            debugLog("⚡ No active WebView session — attempting auto-restore from cookies…")
            let restored = await fetcher.restoreSession()
            debugLog(restored ? "✅ Session auto-restored!" : "⚠️ Auto-restore failed")
        }
        guard fetcher.hasSession else {
            debugLog("❌ No session and restore failed — please re-login")
            fetchError = L10n.aiSessionExpired
            account.isAuthenticated = false
            return
        }

        // Step 1: Fetch organizations using the captured login webView
        let orgsURL = URL(string: "https://claude.ai/api/organizations")!
        let orgsJSONOpt = await fetcher.fetchJSON(from: orgsURL)
        debugLog("🔍 orgs fetcher trace:\n\(fetcher.log)")
        guard let orgsJSON = orgsJSONOpt else {
            fetchError = L10n.aiSessionExpired
            account.isAuthenticated = false
            debugLog("❌ Failed to fetch /api/organizations (see trace above)")
            return
        }
        debugLog("📦 orgs response (\(orgsJSON.count) chars):\n\(orgsJSON.prefix(1500))")

        // Detect Claude API error envelope {"type":"error", ...}
        if orgsJSON.contains("\"type\":\"error\"") || orgsJSON.contains("account_session_invalid") {
            fetchError = L10n.aiSessionExpired
            account.isAuthenticated = false
            debugLog("❌ Claude returned auth error — session is invalid, please re-login")
            return
        }

        guard let orgsData = orgsJSON.data(using: .utf8),
              let orgsAny = try? JSONSerialization.jsonObject(with: orgsData),
              let org = findChatOrg(in: orgsAny),
              let orgId = org["uuid"] as? String else {
            fetchError = L10n.aiScrapeParseError
            debugLog("❌ Failed to parse organizations JSON")
            return
        }

        account.organizationId = orgId
        if let plan = derivePlan(from: org) {
            account.planName = plan
        }
        debugLog("✅ org: \(orgId), plan: \(account.planName ?? "nil")")
        debugLog("🔑 org keys: \(Array(org.keys).sorted().joined(separator: ", "))")

        // Step 2: Fetch usage (reuses the same captured webView)
        let usageURL = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        let usageJSONOpt = await fetcher.fetchJSON(from: usageURL)
        debugLog("🔍 usage fetcher trace:\n\(fetcher.log)")
        guard let usageJSON = usageJSONOpt else {
            fetchError = L10n.aiScrapeFailedRetry
            debugLog("❌ Failed to fetch /usage (see trace above)")
            return
        }
        debugLog("📦 usage response (\(usageJSON.count) chars):\n\(usageJSON.prefix(2000))")

        guard let usageData = usageJSON.data(using: .utf8),
              let usageObj = try? JSONSerialization.jsonObject(with: usageData) as? [String: Any] else {
            fetchError = L10n.aiScrapeParseError
            debugLog("❌ Failed to parse usage JSON as dictionary")
            return
        }
        debugLog("🔑 usage top-level keys: \(Array(usageObj.keys).sorted().joined(separator: ", "))")

        // Flexible extraction — try multiple known field name variants
        let (u5h, r5h) = extractUsageWindow(from: usageObj, keys: [
            "five_hour", "five_hour_limit", "fiveHour", "5h", "hour_5", "session"
        ])
        let (u7d, r7d) = extractUsageWindow(from: usageObj, keys: [
            "seven_day", "seven_day_limit", "sevenDay", "7d", "day_7", "weekly"
        ])
        let (uOpus, rOpus) = extractUsageWindow(from: usageObj, keys: [
            "seven_day_opus", "sevenDayOpus", "opus", "7d_opus"
        ])
        let (uSonnet, rSonnet) = extractUsageWindow(from: usageObj, keys: [
            "seven_day_sonnet", "sevenDaySonnet", "sonnet", "7d_sonnet"
        ])

        account.utilization5h = u5h
        account.resetTime5h = parseISO8601(r5h)
        account.utilization7d = u7d
        account.resetTime7d = parseISO8601(r7d)
        account.utilization7dOpus = uOpus
        account.resetTime7dOpus = parseISO8601(rOpus)
        account.utilization7dSonnet = uSonnet
        account.resetTime7dSonnet = parseISO8601(rSonnet)
        account.lastFetchedAt = Date()
        account.isAuthenticated = true
        debugLog("✅ extracted — 5h: \(u5h)%, 7d: \(u7d)%, opus: \(uOpus)%, sonnet: \(uSonnet)%")

        // Step 3: Fetch overage (optional, reuses same webView)
        let overageURL = URL(string: "https://claude.ai/api/organizations/\(orgId)/overage_spend_limit")!
        if let overageJSON = await fetcher.fetchJSON(from: overageURL),
           let overageData = overageJSON.data(using: .utf8),
           let overageObj = try? JSONSerialization.jsonObject(with: overageData) as? [String: Any] {
            account.extraUsageEnabled = (overageObj["is_enabled"] as? Bool) ?? false
            account.extraUsageLimitCents = (overageObj["monthly_credit_limit"] as? Int) ?? 0
            account.extraUsageUsedCents = (overageObj["used_credits"] as? Int) ?? 0
            debugLog("💰 overage: enabled=\(account.extraUsageEnabled), limit=\(account.extraUsageLimitCents), used=\(account.extraUsageUsedCents)")
        }

        // Step 4: Schedule a local push notification at the 5-hour reset time
        await scheduleClaudeResetNotification(account: account)

        debugLog("=== Claude fetch done ===")
    }

    // MARK: - Claude 5h Reset Notification

    /// Schedules a local notification to fire when the Claude 5-hour session window resets.
    /// Uses a stable identifier per account so repeated fetches replace (not duplicate) the pending notification.
    /// No-ops if: not a Claude account, no reset time, interval invalid (past or > 24 h), or permission denied.
    @MainActor
    func scheduleClaudeResetNotification(account: AIAccount) async {
        guard account.provider == .claude,
              let resetTime = account.resetTime5h else {
            debugLog("⏰ skip reset notification: no resetTime5h")
            return
        }

        let interval = resetTime.timeIntervalSinceNow
        // Sanity: must be in the future and within 24 h (5h windows never exceed that)
        guard interval > 0, interval < 24 * 3600 else {
            debugLog("⏰ skip reset notification: interval \(Int(interval))s out of range")
            return
        }

        // Ensure notification permission is granted (request if undetermined)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            debugLog("⏰ skip reset notification: permission denied")
            return
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if !granted {
                debugLog("⏰ skip reset notification: permission not granted")
                return
            }
        default:
            break
        }

        let identifier = "claude-5h-reset-\(account.id.uuidString)"
        // Remove any pending notification with this id so we always replace with the latest reset time
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.aiResetNotificationTitle(provider: account.nickname)
        content.body = L10n.aiResetNotificationBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            let mins = Int(interval / 60)
            debugLog("⏰ scheduled 5h reset notification in \(mins / 60)h \(mins % 60)m (id=\(identifier))")
        } catch {
            debugLog("⏰ failed to schedule reset notification: \(error.localizedDescription)")
        }
    }

    /// Cancels any pending 5-hour reset notification for a Claude account.
    /// Call this when deleting an account or signing out.
    @MainActor
    func cancelClaudeResetNotification(accountId: UUID) {
        let identifier = "claude-5h-reset-\(accountId.uuidString)"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        debugPrint("[AIUsageService] cancelled pending reset notification: \(identifier)")
    }

    /// Finds the organization with "chat" capability, or returns the first org.
    /// Response can be an array [Org, ...] or an object {"organizations": [...]}.
    private func findChatOrg(in any: Any) -> [String: Any]? {
        var orgs: [[String: Any]] = []
        if let arr = any as? [[String: Any]] {
            orgs = arr
        } else if let dict = any as? [String: Any] {
            if let arr = dict["organizations"] as? [[String: Any]] {
                orgs = arr
            } else if let arr = dict["data"] as? [[String: Any]] {
                orgs = arr
            } else {
                // Single org object
                orgs = [dict]
            }
        }
        if orgs.isEmpty { return nil }
        // Prefer org with "chat" capability
        if let chatOrg = orgs.first(where: {
            ($0["capabilities"] as? [String])?.contains("chat") == true
        }) {
            return chatOrg
        }
        return orgs.first
    }

    /// Extracts utilization (0-100) and resets_at string from a usage object, trying multiple key variants.
    private func extractUsageWindow(from obj: [String: Any], keys: [String]) -> (Double, String?) {
        for key in keys {
            if let window = obj[key] as? [String: Any] {
                let util = extractUtilization(from: window)
                let resetStr = (window["resets_at"] as? String)
                    ?? (window["reset_at"] as? String)
                    ?? (window["resetsAt"] as? String)
                    ?? (window["reset_time"] as? String)
                return (util, resetStr)
            }
        }
        // Also try looking inside a nested "limits" or "usage" object
        if let limits = obj["limits"] as? [String: Any] {
            return extractUsageWindow(from: limits, keys: keys)
        }
        if let usage = obj["usage"] as? [String: Any] {
            return extractUsageWindow(from: usage, keys: keys)
        }
        return (0, nil)
    }

    /// Extracts a utilization percentage (0-100 scale) from a window dict, handling different value formats.
    private func extractUtilization(from window: [String: Any]) -> Double {
        // Try common field names
        let candidates = ["utilization", "utilization_percentage", "percent", "percentage", "used_percent"]
        for key in candidates {
            if let v = window[key] as? Double { return normalizeUtilization(v) }
            if let v = window[key] as? Int { return Double(v) }
            if let v = window[key] as? NSNumber { return normalizeUtilization(v.doubleValue) }
        }
        // Try computing from used/limit
        if let used = window["used"] as? Double, let limit = window["limit"] as? Double, limit > 0 {
            return (used / limit) * 100.0
        }
        if let used = window["used"] as? Int, let limit = window["limit"] as? Int, limit > 0 {
            return Double(used) / Double(limit) * 100.0
        }
        return 0
    }

    /// If value looks like a 0-1 fraction, convert to 0-100 percentage.
    private func normalizeUtilization(_ value: Double) -> Double {
        // Heuristic: if value is between 0 and 1 (exclusive of 1.5 to be safe), treat as fraction
        if value > 0 && value <= 1.0 {
            return value * 100.0
        }
        return value
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f1.date(from: string) { return date }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: string)
    }

    private func derivePlan(from org: [String: Any]) -> String? {
        // 1. rate_limit_tier (most accurate)
        if let tier = org["rate_limit_tier"] as? String {
            let t = tier.lowercased()
            if t.contains("max_20x") { return "Max 20x" }
            if t.contains("max_5x") { return "Max 5x" }
            if t.contains("max") { return "Max" }
            if t.contains("pro") { return "Pro" }
            if t.contains("team") { return "Team" }
            if t.contains("enterprise") { return "Enterprise" }
            if t.contains("free") { return "Free" }
        }
        // 2. active_flags
        if let flags = org["active_flags"] as? [String], !flags.isEmpty {
            let joined = flags.joined(separator: " ").lowercased()
            if joined.contains("max_20x") { return "Max 20x" }
            if joined.contains("max_5x") { return "Max 5x" }
            if joined.contains("max") { return "Max" }
            if joined.contains("pro") { return "Pro" }
            if joined.contains("team") { return "Team" }
            if joined.contains("raven") { return "Max" }  // internal name
        }
        // 3. billing_type
        if let billing = org["billing_type"] as? String {
            let b = billing.lowercased()
            if b.contains("enterprise") { return "Enterprise" }
            if b.contains("team") { return "Team" }
            if b.contains("max_20x") { return "Max 20x" }
            if b.contains("max_5x") { return "Max 5x" }
            if b.contains("max") { return "Max" }
            if b.contains("pro") { return "Pro" }
            if b.contains("free") || b.contains("individual") { return "Free" }
            if b.contains("subscription") { return "Pro" }
        }
        // 4. Scan ALL string values for plan keywords (last resort)
        for (_, value) in org {
            if let str = value as? String {
                let s = str.lowercased()
                if s.contains("max_20x") { return "Max 20x" }
                if s.contains("max_5x") { return "Max 5x" }
            }
        }
        return nil
    }

    // MARK: - ChatGPT (WebView Scraping)

    @MainActor
    private func fetchOpenAIAccount(_ account: AIAccount) async {
        guard let url = URL(string: AIProvider.openai.usagePageURL) else {
            fetchError = "Invalid ChatGPT URL"
            return
        }

        let scraper = AIWebScraper()
        guard let json = await scraper.scrape(url: url, javascript: AIScrapeScript.chatGPT, waitSeconds: 4) else {
            fetchError = L10n.aiScrapeFailedRetry
            debugPrint("[AIMonitor] ChatGPT scrape returned nil — page may not have loaded or cookies missing")
            return
        }

        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(ChatGPTScrapeResult.self, from: data) else {
            fetchError = L10n.aiScrapeParseError
            debugPrint("[AIMonitor] ChatGPT scrape JSON parse failed: \(json.prefix(200))")
            return
        }

        if result.loggedIn == false {
            account.isAuthenticated = false
            fetchError = L10n.aiSessionExpired
            debugPrint("[AIMonitor] ChatGPT not logged in. Snippet: \(result.snippet?.prefix(200) ?? "nil")")
            return
        }

        if let plan = result.plan, !plan.isEmpty {
            account.planName = plan
        }
        if let email = result.email {
            account.email = email
        }

        // Rate-limit status
        account.isRateLimited = result.rateLimited ?? false

        // Codex task usage
        if let used = result.codexTasksUsed, let limit = result.codexTasksLimit, limit > 0 {
            account.codexTasksUsed = used
            account.codexTasksLimit = limit
            account.utilization5h = account.codexUtilization
        }

        account.lastFetchedAt = Date()
        account.isAuthenticated = true
        debugPrint("[AIMonitor] ChatGPT fetch OK — plan: \(result.plan ?? "nil"), email: \(result.email ?? "nil"), rateLimited: \(result.rateLimited ?? false), codex: \(result.codexTasksUsed ?? 0)/\(result.codexTasksLimit ?? 0)")
    }

    // MARK: - Gemini (WebView Scraping)

    @MainActor
    private func fetchGeminiAccount(_ account: AIAccount) async {
        guard let url = URL(string: AIProvider.google.usagePageURL) else {
            fetchError = "Invalid Gemini URL"
            return
        }

        let scraper = AIWebScraper()
        // Gemini AI Studio is a heavy SPA — give it 6 seconds to render
        guard let json = await scraper.scrape(url: url, javascript: AIScrapeScript.gemini, waitSeconds: 6) else {
            fetchError = L10n.aiScrapeFailedRetry
            debugPrint("[AIMonitor] Gemini scrape returned nil — page may not have loaded or cookies missing")
            return
        }

        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(GeminiScrapeResult.self, from: data) else {
            fetchError = L10n.aiScrapeParseError
            debugPrint("[AIMonitor] Gemini scrape JSON parse failed: \(json.prefix(200))")
            return
        }

        if result.loggedIn == false {
            account.isAuthenticated = false
            fetchError = L10n.aiSessionExpired
            debugPrint("[AIMonitor] Gemini not logged in. Snippet: \(result.snippet?.prefix(200) ?? "nil")")
            return
        }

        if let plan = result.plan, !plan.isEmpty {
            account.planName = plan
        }

        // Use highest model usage as primary indicator
        if let models = result.models, !models.isEmpty {
            let sorted = models.sorted { $0.usagePercent > $1.usagePercent }
            account.utilization5h = sorted[0].usagePercent
            if sorted.count > 1 {
                account.utilization7d = sorted[1].usagePercent
            }
            if account.planName == nil {
                account.planName = sorted[0].model
            }
        } else if let pcts = result.allPercentages, !pcts.isEmpty {
            // Fallback to raw percentages
            let sorted = pcts.sorted(by: >)
            account.utilization5h = sorted[0]
            if sorted.count > 1 { account.utilization7d = sorted[1] }
        }

        account.lastFetchedAt = Date()
        account.isAuthenticated = true
        debugPrint("[AIMonitor] Gemini fetch OK — models: \(result.models?.count ?? 0), pcts: \(result.allPercentages?.count ?? 0), plan: \(result.plan ?? "nil")")
    }

    @MainActor
    func fetchAllUsage(accounts: [AIAccount]) async {
        isFetching = true
        fetchError = nil
        for account in accounts where account.isEnabled && account.isAuthenticated {
            await performFetch(for: account)
        }
        isFetching = false
    }

    // MARK: - (Claude API calls now go through ClaudeAPIFetcher which uses WebView)

    // MARK: - Notifications

    /// Tier-based usage alert: fires at most once per tier per usage cycle for
    /// the user's custom threshold, 95%, and 100% (limit reached). Each flag
    /// latches on fire and clears when utilization drops back below its tier,
    /// so a new cycle can alert again.
    private func checkAndNotify(account: AIAccount) async {
        let threshold = Double(account.notifyThreshold)

        // --- 5h window ---
        await evaluateTier(
            utilization: account.utilization5h,
            tier: threshold,
            flag: { account.notified5h },
            setFlag: { account.notified5h = $0 },
            account: account,
            windowLabel: account.provider.windowLabel1,
            kind: .threshold(percent: Int(threshold))
        )
        await evaluateTier(
            utilization: account.utilization5h,
            tier: 95,
            flag: { account.notified95_5h },
            setFlag: { account.notified95_5h = $0 },
            account: account,
            windowLabel: account.provider.windowLabel1,
            kind: .ninetyFive
        )
        await evaluateTier(
            utilization: account.utilization5h,
            tier: 100,
            flag: { account.notifiedLimit5h },
            setFlag: { account.notifiedLimit5h = $0 },
            account: account,
            windowLabel: account.provider.windowLabel1,
            kind: .limit
        )

        // --- 7d window ---
        await evaluateTier(
            utilization: account.utilization7d,
            tier: threshold,
            flag: { account.notified7d },
            setFlag: { account.notified7d = $0 },
            account: account,
            windowLabel: account.provider.windowLabel2,
            kind: .threshold(percent: Int(threshold))
        )
        await evaluateTier(
            utilization: account.utilization7d,
            tier: 95,
            flag: { account.notified95_7d },
            setFlag: { account.notified95_7d = $0 },
            account: account,
            windowLabel: account.provider.windowLabel2,
            kind: .ninetyFive
        )
        await evaluateTier(
            utilization: account.utilization7d,
            tier: 100,
            flag: { account.notifiedLimit7d },
            setFlag: { account.notifiedLimit7d = $0 },
            account: account,
            windowLabel: account.provider.windowLabel2,
            kind: .limit
        )
    }

    private enum TierKind {
        case threshold(percent: Int)
        case ninetyFive
        case limit
    }

    private func evaluateTier(
        utilization: Double,
        tier: Double,
        flag: () -> Bool,
        setFlag: (Bool) -> Void,
        account: AIAccount,
        windowLabel: String,
        kind: TierKind
    ) async {
        if utilization >= tier {
            if !flag() {
                setFlag(true)
                await sendTierNotification(
                    account: account,
                    windowLabel: windowLabel,
                    utilization: utilization,
                    kind: kind
                )
            }
        } else if flag() {
            // Usage fell below this tier — reset so next cycle can alert again.
            setFlag(false)
        }
    }

    private func sendTierNotification(
        account: AIAccount,
        windowLabel: String,
        utilization: Double,
        kind: TierKind
    ) async {
        let content = UNMutableNotificationContent()
        content.title = L10n.aiLowBalanceTitle
        switch kind {
        case .limit:
            content.body = L10n.aiUsageAlert(
                provider: account.nickname,
                percent: 100,
                window: windowLabel
            )
        case .ninetyFive:
            content.body = L10n.aiUsageAlert(
                provider: account.nickname,
                percent: 95,
                window: windowLabel
            )
        case .threshold:
            content.body = L10n.aiUsageAlert(
                provider: account.nickname,
                percent: Int(utilization),
                window: windowLabel
            )
        }
        content.sound = .default

        let tierKey: String
        switch kind {
        case .threshold: tierKey = "threshold"
        case .ninetyFive: tierKey = "95"
        case .limit: tierKey = "limit"
        }
        let request = UNNotificationRequest(
            identifier: "ai-usage-\(account.id.uuidString)-\(windowLabel)-\(tierKey)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Scrape Result Models

struct ChatGPTScrapeResult: Codable {
    let plan: String?
    let email: String?
    let loggedIn: Bool?
    let rateLimited: Bool?
    let codexTasksUsed: Int?
    let codexTasksLimit: Int?
    let snippet: String?
}

struct GeminiScrapeResult: Codable {
    let models: [GeminiModelUsage]?
    let allPercentages: [Double]?
    let plan: String?
    let loggedIn: Bool?
    let snippet: String?
}

struct GeminiModelUsage: Codable {
    let model: String
    let usagePercent: Double
    let used: Int?
    let total: Int?
}

private extension DateFormatter {
    static let debugTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
