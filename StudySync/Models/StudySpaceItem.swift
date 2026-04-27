import Foundation
import SwiftData

@Model
final class StudySpaceItem {
    var id: UUID = UUID()
    var itemId: String = ""         // e.g. "desk_lamp", "plant_small"
    var unlockedAt: Date = Date()

    init(itemId: String) {
        self.id = UUID()
        self.itemId = itemId
        self.unlockedAt = Date()
    }

    /// All available decoration items with unlock conditions
    static let catalog: [DeskItem] = [
        // Tier 1: Easy (unlock early)
        DeskItem(id: "notebook", emoji: "📓", name: "笔记本", unlockHours: 1),
        DeskItem(id: "pencil_cup", emoji: "✏️", name: "文具盒", unlockHours: 3),
        DeskItem(id: "coffee", emoji: "☕️", name: "咖啡", unlockHours: 5),
        DeskItem(id: "desk_lamp", emoji: "💡", name: "台灯", unlockHours: 10),
        // Tier 2: Medium
        DeskItem(id: "plant_small", emoji: "🌱", name: "小植物", unlockHours: 20),
        DeskItem(id: "headphones", emoji: "🎧", name: "耳机", unlockHours: 30),
        DeskItem(id: "globe", emoji: "🌍", name: "地球仪", unlockHours: 50),
        DeskItem(id: "bookshelf", emoji: "📚", name: "书架", unlockHours: 75),
        // Tier 3: Hard
        DeskItem(id: "trophy_bronze", emoji: "🥉", name: "铜奖杯", unlockHours: 100),
        DeskItem(id: "telescope", emoji: "🔭", name: "望远镜", unlockHours: 150),
        DeskItem(id: "trophy_silver", emoji: "🥈", name: "银奖杯", unlockHours: 200),
        DeskItem(id: "trophy_gold", emoji: "🏆", name: "金奖杯", unlockHours: 300),
        // Tier 4: Epic
        DeskItem(id: "crystal_ball", emoji: "🔮", name: "水晶球", unlockHours: 500),
        DeskItem(id: "crown", emoji: "👑", name: "皇冠", unlockHours: 1000),
    ]
}

struct DeskItem: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let unlockHours: Int    // total focus hours needed to unlock

    var unlockMinutes: Int { unlockHours * 60 }
}
