import AppIntents
import SwiftData

struct AddCountdownIntent: AppIntent {
    static var title: LocalizedStringResource = "添加倒计时"
    static var description = IntentDescription("快速创建一个新的倒计时事件")

    @Parameter(title: "标题")
    var title: String

    @Parameter(title: "天数", description: "从今天算起的天数")
    var daysFromNow: Int

    @Parameter(title: "分类", default: "生活")
    var categoryName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Prefer the main app's container when this intent runs in-process
        // (Spotlight / in-app shortcuts) — opening a second container on
        // the same store URL with a different schema corrupts metadata
        // (root cause of v1.0 data-loss bug). See AppContainer.swift.
        // Only fall back to a fresh container when we're genuinely in a
        // separate process (Shortcuts app, etc.) where the main container
        // isn't reachable.
        let container = AppContainer.shared.container ?? SharedModelContainer.create()
        let context = ModelContext(container)

        guard let endDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) else {
            return .result(dialog: "无法计算目标日期")
        }
        let category = EventCategory.allCases.first {
            $0.rawValue == (categoryName ?? "生活")
        } ?? .life

        let event = CountdownEvent(
            title: title,
            emoji: category.defaultEmoji,
            endDate: endDate,
            category: category,
            colorHex: category.defaultColorHex
        )
        context.insert(event)
        try? context.save()

        return .result(dialog: "已创建「\(title)」倒计时，\(daysFromNow) 天后到期")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("添加「\(\.$title)」倒计时，\(\.$daysFromNow) 天后")
    }
}
