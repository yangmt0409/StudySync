import Foundation
import SwiftData
import EventKit

@Model
final class DeadlineRecord {
    var eventIdentifier: String = ""
    /// Stable cross-device identifier from EventKit (`calendarItemExternalIdentifier`).
    /// Used for matching when the record syncs to another device via iCloud.
    var externalIdentifier: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()

    init(eventIdentifier: String, externalIdentifier: String = "") {
        self.eventIdentifier = eventIdentifier
        self.externalIdentifier = externalIdentifier
    }

    /// Check if this record matches a given EKEvent.
    /// Prefers externalIdentifier (stable across devices), falls back to eventIdentifier (device-local).
    func matches(_ event: EKEvent) -> Bool {
        if !externalIdentifier.isEmpty,
           !event.calendarItemExternalIdentifier.isEmpty {
            return externalIdentifier == event.calendarItemExternalIdentifier
        }
        return eventIdentifier == event.eventIdentifier
    }
}
