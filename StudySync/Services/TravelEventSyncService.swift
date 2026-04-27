import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Firestore sync for `TravelEvent`.
///
/// Layout: `users/{uid}/travelEvents/{travelId}`
///
/// Why a Firestore mirror in addition to SwiftData/CloudKit:
/// Per v1.0.2(1) changelog the Travel system shipped without cloud sync
/// ("Firestore: 暂未接入云端同步"). That meant trips added on iPhone
/// vanished on iPad / new device. Now mirrored alongside the other
/// primary entities (TodoItem, CountdownEvent, StudyGoal, ...).
///
/// Field-encoding notes:
/// - `segmentsData` is `Data` (JSON-encoded multi-leg array). Firestore
///   stores it as a base64 String to avoid the Data → blob round-trip
///   landmines. Decoded back to `Data` in `pullAll`.
/// - Date-with-timezone fields: we sync both the wall-clock packed Date
///   (`departureTimeLocal`) AND the IANA zone identifier
///   (`departureTimeZoneID`). The model's `departureInstant` computed
///   property re-derives the absolute moment locally.
final class TravelEventSyncService {
    static let shared = TravelEventSyncService()

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthService.shared.currentUser?.uid }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("travelEvents")
    }

    // MARK: - Push

    func pushEvent(_ event: TravelEvent) {
        guard let uid else { return }
        let eventId = event.id.uuidString
        var data: [String: Any] = [
            "id": eventId,
            "kindRaw": event.kindRaw,
            "carrierCode": event.carrierCode,
            "number": event.number,
            "serviceName": event.serviceName,

            "departureCity": event.departureCity,
            "departureStation": event.departureStation,
            "departureStationCode": event.departureStationCode,
            "departureTimeLocal": Timestamp(date: event.departureTimeLocal),
            "departureTimeZoneID": event.departureTimeZoneID,
            "departureTerminal": event.departureTerminal,
            "departureGate": event.departureGate,

            "arrivalCity": event.arrivalCity,
            "arrivalStation": event.arrivalStation,
            "arrivalStationCode": event.arrivalStationCode,
            "arrivalTimeLocal": Timestamp(date: event.arrivalTimeLocal),
            "arrivalTimeZoneID": event.arrivalTimeZoneID,
            "arrivalTerminal": event.arrivalTerminal,

            "segmentsBase64": event.segmentsData.base64EncodedString(),

            "pnr": event.pnr,
            "seat": event.seat,
            "passengerName": event.passengerName,

            "statusRaw": event.statusRaw,
            "delayMinutes": event.delayMinutes,
            "markedComplete": event.markedComplete,

            "colorHex": event.colorHex,
            "emoji": event.emoji,
            "note": event.note,

            "reminderPresetRaw": event.reminderPresetRaw,
            "reminderEnabled": event.reminderEnabled,

            "createdAt": Timestamp(date: event.createdAt),
            "importSourceRaw": event.importSourceRaw,
            "walletPassIdentifier": event.walletPassIdentifier,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let refreshedAt = event.lastStatusRefreshedAt {
            data["lastStatusRefreshedAt"] = Timestamp(date: refreshedAt)
        } else {
            data["lastStatusRefreshedAt"] = NSNull()
        }
        Task {
            do {
                try await collection(uid).document(eventId).setData(data, merge: true)
            } catch {
                debugPrint("[TravelEventSync] pushEvent error: \(error)")
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
                debugPrint("[TravelEventSync] deleteEvent error: \(error)")
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

            let locals = (try? context.fetch(FetchDescriptor<TravelEvent>())) ?? []
            var localById: [UUID: TravelEvent] = [:]
            for t in locals { localById[t.id] = t }

            for doc in snapshot.documents {
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let uuid = UUID(uuidString: idString) else { continue }

                let kindRaw = data["kindRaw"] as? String ?? TravelKind.flight.rawValue
                let carrierCode = data["carrierCode"] as? String ?? ""
                let number = data["number"] as? String ?? ""
                let serviceName = data["serviceName"] as? String ?? ""

                let departureCity = data["departureCity"] as? String ?? ""
                let departureStation = data["departureStation"] as? String ?? ""
                let departureStationCode = data["departureStationCode"] as? String ?? ""
                let departureTimeLocal = (data["departureTimeLocal"] as? Timestamp)?.dateValue() ?? Date()
                let departureTimeZoneID = data["departureTimeZoneID"] as? String ?? TimeZone.current.identifier
                let departureTerminal = data["departureTerminal"] as? String ?? ""
                let departureGate = data["departureGate"] as? String ?? ""

                let arrivalCity = data["arrivalCity"] as? String ?? ""
                let arrivalStation = data["arrivalStation"] as? String ?? ""
                let arrivalStationCode = data["arrivalStationCode"] as? String ?? ""
                let arrivalTimeLocal = (data["arrivalTimeLocal"] as? Timestamp)?.dateValue() ?? Date()
                let arrivalTimeZoneID = data["arrivalTimeZoneID"] as? String ?? TimeZone.current.identifier
                let arrivalTerminal = data["arrivalTerminal"] as? String ?? ""

                let segmentsBase64 = data["segmentsBase64"] as? String ?? ""
                let segmentsData = Data(base64Encoded: segmentsBase64) ?? Data()

                let pnr = data["pnr"] as? String ?? ""
                let seat = data["seat"] as? String ?? ""
                let passengerName = data["passengerName"] as? String ?? ""

                let statusRaw = data["statusRaw"] as? String ?? TravelStatus.scheduled.rawValue
                let delayMinutes = data["delayMinutes"] as? Int ?? 0
                let markedComplete = data["markedComplete"] as? Bool ?? false
                let lastStatusRefreshedAt = (data["lastStatusRefreshedAt"] as? Timestamp)?.dateValue()

                let colorHex = data["colorHex"] as? String ?? "#5B8BFF"
                let emoji = data["emoji"] as? String ?? "✈️"
                let note = data["note"] as? String ?? ""

                let reminderPresetRaw = data["reminderPresetRaw"] as? String ?? TravelReminderPreset.domesticFlight.rawValue
                let reminderEnabled = data["reminderEnabled"] as? Bool ?? true

                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let importSourceRaw = data["importSourceRaw"] as? String ?? TravelImportSource.manual.rawValue
                let walletPassIdentifier = data["walletPassIdentifier"] as? String ?? ""

                let target = localById[uuid] ?? TravelEvent()
                target.id = uuid
                target.kindRaw = kindRaw
                target.carrierCode = carrierCode
                target.number = number
                target.serviceName = serviceName

                target.departureCity = departureCity
                target.departureStation = departureStation
                target.departureStationCode = departureStationCode
                target.departureTimeLocal = departureTimeLocal
                target.departureTimeZoneID = departureTimeZoneID
                target.departureTerminal = departureTerminal
                target.departureGate = departureGate

                target.arrivalCity = arrivalCity
                target.arrivalStation = arrivalStation
                target.arrivalStationCode = arrivalStationCode
                target.arrivalTimeLocal = arrivalTimeLocal
                target.arrivalTimeZoneID = arrivalTimeZoneID
                target.arrivalTerminal = arrivalTerminal

                target.segmentsData = segmentsData

                target.pnr = pnr
                target.seat = seat
                target.passengerName = passengerName

                target.statusRaw = statusRaw
                target.delayMinutes = delayMinutes
                target.markedComplete = markedComplete
                target.lastStatusRefreshedAt = lastStatusRefreshedAt

                target.colorHex = colorHex
                target.emoji = emoji
                target.note = note

                target.reminderPresetRaw = reminderPresetRaw
                target.reminderEnabled = reminderEnabled

                target.createdAt = createdAt
                target.importSourceRaw = importSourceRaw
                target.walletPassIdentifier = walletPassIdentifier

                if localById[uuid] == nil {
                    context.insert(target)
                }
            }

            try? context.save()
            debugPrint("[TravelEventSync] ✅ pulled \(snapshot.documents.count) travel events from Firestore")
        } catch {
            debugPrint("[TravelEventSync] pullAll error: \(error)")
        }
    }
}
