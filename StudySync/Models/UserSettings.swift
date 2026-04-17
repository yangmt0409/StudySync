import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID = UUID()
    var homeTimeZoneId: String = "Asia/Shanghai"
    var studyTimeZoneId: String = "America/Toronto"
    var homeCityName: String = "上海"
    var studyCityName: String = "多伦多"
    var showExpiredEvents: Bool = true
    var defaultCategoryRaw: String = "academic"

    var homeTimeZone: TimeZone {
        TimeZone(identifier: homeTimeZoneId) ?? .current
    }

    var studyTimeZone: TimeZone {
        TimeZone(identifier: studyTimeZoneId) ?? .current
    }

    var defaultCategory: EventCategory {
        get { EventCategory(rawValue: defaultCategoryRaw) ?? .life }
        set { defaultCategoryRaw = newValue.rawValue }
    }

    init(
        homeTimeZoneId: String = "Asia/Shanghai",
        studyTimeZoneId: String = "America/Toronto",
        homeCityName: String = "上海",
        studyCityName: String = "多伦多",
        showExpiredEvents: Bool = true,
        defaultCategory: EventCategory = .academic
    ) {
        self.id = UUID()
        self.homeTimeZoneId = homeTimeZoneId
        self.studyTimeZoneId = studyTimeZoneId
        self.homeCityName = homeCityName
        self.studyCityName = studyCityName
        self.showExpiredEvents = showExpiredEvents
        self.defaultCategoryRaw = defaultCategory.rawValue
    }
}
