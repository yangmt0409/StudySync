import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for CountdownEvent.
///
/// Layout: users/{uid}/countdownEvents/{eventId}
///
/// NOTE: `backgroundImageData` is intentionally NOT synced — Firestore has a
/// 1 MiB document limit and user-picked images can easily exceed that. Images
/// remain device-local; the event fields are synced so the countdown is
/// restored on reinstall/new device, and the user re-picks a background if
/// they want one.
final class CountdownEventSyncService {
    static let shared = CountdownEventSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("countdownEvents")
    }

    // MARK: - Push

    func pushEvent(_ event: CountdownEvent) {
        guard let uid else { return }
        let eventId = event.id.uuidString
        let data: [String: Any] = [
            "id": eventId,
            "title": event.title,
            "emoji": event.emoji,
            "startDate": Timestamp(date: event.startDate),
            "endDate": Timestamp(date: event.endDate),
            "categoryRaw": event.categoryRaw,
            "colorHex": event.colorHex,
            "isPinned": event.isPinned,
            "notifyEnabled": event.notifyEnabled,
            "createdAt": Timestamp(date: event.createdAt),
            "dotShapeRaw": event.dotShapeRaw,
            "timeUnitRaw": event.timeUnitRaw,
            "themeStyleRaw": event.themeStyleRaw,
            "showAsCountUp": event.showAsCountUp,
            "showPercentage": event.showPercentage,
            "note": event.note,
            "dotColorHex": event.dotColorHex,
            "textColorHex": event.textColorHex,
            "fontName": event.fontName,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        Task {
            do {
                try await collection(uid).document(eventId).setData(data, merge: true)
            } catch {
                debugPrint("[CountdownEventSync] pushEvent error: \(error)")
            }
        }
    }

    func deleteEvent(id: UUID) {
        guard let uid else { return }
        let eventId = id.uuidString
        Task {
            do {
                try await collection(uid).document(eventId).delete()
            } catch {
                debugPrint("[CountdownEventSync] deleteEvent error: \(error)")
            }
        }
    }

    // MARK: - Pull

    @MainActor
    func pullAll(context: ModelContext) async {
        guard let uid else { return }

        do {
            let snapshot = try await collection(uid).getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            let locals = (try? context.fetch(FetchDescriptor<CountdownEvent>())) ?? []
            var localById: [UUID: CountdownEvent] = [:]
            for e in locals { localById[e.id] = e }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let title = data["title"] as? String ?? ""
                let emoji = data["emoji"] as? String ?? "📌"
                let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
                let categoryRaw = data["categoryRaw"] as? String ?? "life"
                let colorHex = data["colorHex"] as? String ?? "#5B7FFF"
                let isPinned = data["isPinned"] as? Bool ?? false
                let notifyEnabled = data["notifyEnabled"] as? Bool ?? false
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let dotShapeRaw = data["dotShapeRaw"] as? String ?? "circle"
                let timeUnitRaw = data["timeUnitRaw"] as? String ?? "day"
                let themeStyleRaw = data["themeStyleRaw"] as? String ?? "grid"
                let showAsCountUp = data["showAsCountUp"] as? Bool ?? false
                let showPercentage = data["showPercentage"] as? Bool ?? false
                let note = data["note"] as? String ?? ""
                let dotColorHex = data["dotColorHex"] as? String ?? "#FFFFFF"
                let textColorHex = data["textColorHex"] as? String ?? "#FFFFFF"
                let fontName = data["fontName"] as? String ?? "default"

                if let existing = localById[uuid] {
                    existing.title = title
                    existing.emoji = emoji
                    existing.startDate = startDate
                    existing.endDate = endDate
                    existing.categoryRaw = categoryRaw
                    existing.colorHex = colorHex
                    existing.isPinned = isPinned
                    existing.notifyEnabled = notifyEnabled
                    existing.createdAt = createdAt
                    existing.dotShapeRaw = dotShapeRaw
                    existing.timeUnitRaw = timeUnitRaw
                    existing.themeStyleRaw = themeStyleRaw
                    existing.showAsCountUp = showAsCountUp
                    existing.showPercentage = showPercentage
                    existing.note = note
                    existing.dotColorHex = dotColorHex
                    existing.textColorHex = textColorHex
                    existing.fontName = fontName
                } else {
                    let newEvent = CountdownEvent(
                        title: title,
                        emoji: emoji,
                        startDate: startDate,
                        endDate: endDate,
                        category: EventCategory(rawValue: categoryRaw) ?? .life,
                        colorHex: colorHex,
                        isPinned: isPinned,
                        notifyEnabled: notifyEnabled,
                        dotShape: DotShape(rawValue: dotShapeRaw) ?? .circle,
                        timeUnit: TimeUnit(rawValue: timeUnitRaw) ?? .day,
                        themeStyle: ThemeStyle(rawValue: themeStyleRaw) ?? .grid,
                        showAsCountUp: showAsCountUp,
                        showPercentage: showPercentage,
                        note: note,
                        dotColorHex: dotColorHex,
                        textColorHex: textColorHex,
                        fontName: fontName
                    )
                    newEvent.id = uuid
                    newEvent.createdAt = createdAt
                    context.insert(newEvent)
                }
            }

            try? context.save()
            debugPrint("[CountdownEventSync] ✅ pulled \(snapshot.documents.count) events from Firestore")
        } catch {
            debugPrint("[CountdownEventSync] pullAll error: \(error)")
        }
    }
}
