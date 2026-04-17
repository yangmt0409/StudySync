import AppIntents
import SwiftData

struct CheckCountdownIntent: AppIntent {
    static var title: LocalizedStringResource = "查看倒计时"
    static var description = IntentDescription("查询某个倒计时事件的剩余天数")

    @Parameter(title: "事件名称")
    var eventName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CountdownEvent>()

        guard let events = try? context.fetch(descriptor) else {
            return .result(dialog: "无法读取事件数据")
        }

        // If user specified a name, search for it
        if let name = eventName, !name.isEmpty {
            let matched = events.first {
                $0.title.localizedCaseInsensitiveContains(name)
            }

            if let event = matched {
                if event.isExpired {
                    return .result(dialog: "\(event.emoji) \(event.title) 已经结束了")
                }
                return .result(dialog: "\(event.emoji) 距离 \(event.title) 还有 \(event.primaryCount) \(event.unitLabel)")
            } else {
                return .result(dialog: "没有找到包含「\(name)」的事件")
            }
        }

        // No name specified → return nearest event
        let upcoming = events
            .filter { !$0.isExpired }
            .sorted { $0.daysRemaining < $1.daysRemaining }

        if let nearest = upcoming.first {
            return .result(dialog: "\(nearest.emoji) 最近的事件是 \(nearest.title)，还有 \(nearest.primaryCount) \(nearest.unitLabel)")
        }

        return .result(dialog: "目前没有进行中的倒计时事件")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("查看 \(\.$eventName) 的倒计时")
    }
}
