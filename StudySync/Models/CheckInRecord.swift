import Foundation
import SwiftData

@Model
final class CheckInRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var note: String = ""
    var goal: StudyGoal?

    init(date: Date = Date(), note: String = "") {
        self.id = UUID()
        self.date = date
        self.note = note
    }
}
