import AppIntents

struct StudySyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckCountdownIntent(),
            phrases: [
                "查看 \(.applicationName) 倒计时",
                "Ask \(.applicationName) about my countdown",
                "\(.applicationName) 还有多少天",
                "Check \(.applicationName) countdown"
            ],
            shortTitle: "查看倒计时",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: TodayOverviewIntent(),
            phrases: [
                "\(.applicationName) 今天有什么",
                "\(.applicationName) today overview",
                "What's on \(.applicationName) today"
            ],
            shortTitle: "今日概览",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: AddCountdownIntent(),
            phrases: [
                "用 \(.applicationName) 添加倒计时",
                "Add countdown with \(.applicationName)"
            ],
            shortTitle: "添加倒计时",
            systemImageName: "plus"
        )
    }
}
