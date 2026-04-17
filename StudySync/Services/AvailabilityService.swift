import Foundation
import FirebaseAuth

@Observable
final class AvailabilityService {
    static let shared = AvailabilityService()

    /// Raw slot strings keyed by date string (e.g., "2026-04-04" → "GGG...SSS")
    var weekData: [String: String] = [:]
    var isLoading = false

    private let firestore = FirestoreService.shared
    private var saveTask: DispatchWorkItem?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {}

    // MARK: - Date Helpers

    /// Date strings for the next 7 days starting today.
    var weekDateStrings: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            return Self.dateFormatter.string(from: date)
        }
    }

    /// Convert a date string to a Date.
    func date(from string: String) -> Date? {
        Self.dateFormatter.date(from: string)
    }

    // MARK: - Load

    /// Load the current user's week availability from Firestore.
    func loadMyWeek() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        isLoading = true
        let dates = weekDateStrings
        let remote = await firestore.getWeekAvailability(uid: uid, dates: dates)

        // Merge: use remote data if exists, else default all-sleeping (unset)
        var merged: [String: String] = [:]
        for d in dates {
            merged[d] = remote[d] ?? DaySlots.allSleeping
        }
        weekData = merged
        isLoading = false

        // Cleanup past days in background
        Task { await cleanupPastDays(uid: uid) }
    }

    /// Load a friend's week availability (read-only).
    func loadFriendWeek(uid: String) async -> [String: String] {
        let dates = weekDateStrings
        let remote = await firestore.getWeekAvailability(uid: uid, dates: dates)
        var merged: [String: String] = [:]
        for d in dates {
            merged[d] = remote[d] // nil = no data (we show default green in UI)
        }
        return merged
    }

    // MARK: - Update

    /// Update a single slot. Debounces Firestore writes by 0.5s.
    func updateSlot(dateString: String, slotIndex: Int, status: AvailabilityStatus) {
        guard slotIndex >= 0, slotIndex < DaySlots.count else { return }

        var current = weekData[dateString] ?? DaySlots.allSleeping
        var chars = Array(current)
        // Pad if needed
        while chars.count < DaySlots.count { chars.append(Character("S")) }
        chars[slotIndex] = Character(status.rawValue)
        current = String(chars)
        weekData[dateString] = current

        debouncedSave(dateString: dateString, slots: current)
    }

    /// Reset all days to all-available.
    func resetWeek() {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let dates = weekDateStrings
        for d in dates {
            weekData[d] = DaySlots.allAvailable
        }
        Task {
            for d in dates {
                await firestore.saveAvailability(uid: uid, dateString: d, slots: DaySlots.allAvailable)
            }
        }
    }

    // MARK: - Meeting Time

    /// A time slot range where all members are available.
    struct MeetingSlot: Identifiable {
        let dateString: String
        let startIndex: Int
        let endIndex: Int

        var id: String { "\(dateString)-\(startIndex)-\(endIndex)" }

        var startTime: String { DaySlots.timeLabel(for: startIndex) }
        var endTime: String {
            let end = endIndex + 1
            return end < DaySlots.count ? DaySlots.timeLabel(for: end) : "24:00"
        }
        var slotCount: Int { endIndex - startIndex + 1 }
        var durationMinutes: Int { slotCount * 30 }
    }

    /// Compute meeting times where ALL given members are available (green).
    /// Returns slots grouped by date, only including runs ≥ minSlots (default 2 = 1h).
    func computeMeetingTimes(
        memberUids: [String],
        minSlots: Int = 2
    ) async -> [MeetingSlot] {
        guard !memberUids.isEmpty else { return [] }

        let dates = weekDateStrings

        // Fetch availability for all members in parallel
        var allData: [String: [String: String]] = [:] // uid → {date → slots}
        await withTaskGroup(of: (String, [String: String]).self) { group in
            for uid in memberUids {
                group.addTask {
                    let data = await self.firestore.getWeekAvailability(uid: uid, dates: dates)
                    return (uid, data)
                }
            }
            for await (uid, data) in group {
                allData[uid] = data
            }
        }

        // For each date × slot, check if ALL members are available
        var results: [MeetingSlot] = []

        for dateStr in dates {
            // Parse each member's slots for this day
            let memberSlots: [[AvailabilityStatus]] = memberUids.map { uid in
                let raw = allData[uid]?[dateStr] ?? DaySlots.allSleeping
                return DaySlots.parse(raw)
            }

            // Find consecutive runs where ALL members are .available
            var runStart: Int? = nil
            for slot in 0..<DaySlots.count {
                let allAvailable = memberSlots.allSatisfy { $0[slot] == .available }
                if allAvailable {
                    if runStart == nil { runStart = slot }
                } else {
                    if let start = runStart {
                        let length = slot - start
                        if length >= minSlots {
                            results.append(MeetingSlot(
                                dateString: dateStr,
                                startIndex: start,
                                endIndex: slot - 1
                            ))
                        }
                        runStart = nil
                    }
                }
            }
            // Close trailing run
            if let start = runStart {
                let length = DaySlots.count - start
                if length >= minSlots {
                    results.append(MeetingSlot(
                        dateString: dateStr,
                        startIndex: start,
                        endIndex: DaySlots.count - 1
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Private

    private func debouncedSave(dateString: String, slots: String) {
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let uid = AuthService.shared.currentUser?.uid else { return }
            Task {
                await self?.firestore.saveAvailability(uid: uid, dateString: dateString, slots: slots)
            }
        }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func cleanupPastDays(uid: String) async {
        let todayString = weekDateStrings.first ?? ""
        // We can't easily list subcollection docs without querying, so we just
        // try to delete the last 7 past days (safe if they don't exist)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in 1...7 {
            let pastDate = cal.date(byAdding: .day, value: -offset, to: today)!
            let pastString = Self.dateFormatter.string(from: pastDate)
            await firestore.deleteAvailability(uid: uid, dateString: pastString)
        }
    }
}
