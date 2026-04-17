import AppIntents
import SwiftData

struct TodayOverviewIntent: AppIntent {
    static var title: LocalizedStringResource = "今日概览"
    static var description = IntentDescription("查看最近的倒计时事件概览")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CountdownEvent>()

        guard let events = try? context.fetch(descriptor) else {
            return .result(dialog: "无法读取事件数据")
        }

        let upcoming = events
            .filter { !$0.isExpired }
            .sorted { $0.daysRemaining < $1.daysRemaining }
            .prefix(3)

        if upcoming.isEmpty {
            return .result(dialog: "目前没有进行中的倒计时事件")
        }

        let lines = upcoming.map { event in
            "\(event.emoji) \(event.title)：\(event.primaryCount) \(event.unitLabel)"
        }

        let summary = "你有 \(events.filter { !$0.isExpired }.count) 个进行中的倒计时：\n" + lines.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}
