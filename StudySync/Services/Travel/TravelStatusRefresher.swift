import Foundation
import SwiftData

/// Periodically refresh real-time status for upcoming flights imported via
/// sources that support status refresh (`flightAPI`, `wallet`).
///
/// Policy:
///   - Only refresh events within 24 hours of departure — free-tier quota is
///     limited (100-500 req/mo depending on provider), so be thrifty.
///   - Don't refresh more than once per 20 minutes for a given event.
///   - Skip events that are already `arrived` / `completed` / `cancelled`.
///
/// Uses `FlightProviderRegistry.active` so a provider switch picks up
/// automatically on the next tick.
///
/// Entry points:
///   - App foreground → `refreshUpcoming()` in `AppDelegate`.
///   - Background refresh task in `DeadlineBackgroundChecker` every ~1h.
@MainActor
final class TravelStatusRefresher {
    static let shared = TravelStatusRefresher()

    /// Minimum interval between refreshes for the same event, in seconds.
    private let minRefreshInterval: TimeInterval = 20 * 60

    /// Only refresh events departing within this many hours.
    private let refreshWindowHours: Double = 24

    /// True while `refreshUpcoming` is in-flight. Prevents concurrent callers
    /// (e.g. view onAppear + foreground notification firing back-to-back) from
    /// duplicating API calls and wasting the monthly quota.
    private var isRefreshing = false

    func refreshUpcoming(using context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Self-heal pre-existing rows hit by the stale-status import bug.
        // Any future-departing event currently stuck on a terminal status
        // (arrived / enRoute / completed) must be the result of the API
        // returning previous-day state for a daily flight number. Reset
        // those to .scheduled now so the API refresh below has a clean
        // slate and a downstream `apply(update:)` won't be vetoed by the
        // refresh() early-return ladder.
        // Each healed row is pushed to Firestore so a different device
        // doesn't pull the stale `.arrived` back down on next sync.
        let now = Date()
        let healDescriptor = FetchDescriptor<TravelEvent>(predicate: #Predicate<TravelEvent> { event in
            !event.markedComplete
        })
        if let allEvents = try? context.fetch(healDescriptor) {
            for event in allEvents where event.departureInstant > now {
                if event.status == .arrived
                    || event.status == .enRoute
                    || event.status == .completed {
                    event.status = .scheduled
                    TravelEventSyncService.shared.pushEvent(event)
                }
            }
        }

        let cutoff = now.addingTimeInterval(refreshWindowHours * 3600)
        let predicate = #Predicate<TravelEvent> { event in
            !event.markedComplete
                && event.departureTimeLocal <= cutoff
        }
        let descriptor = FetchDescriptor<TravelEvent>(predicate: predicate)
        guard let events = try? context.fetch(descriptor) else { return }

        for event in events {
            await refresh(event: event)
        }

        try? context.save()
    }

    func refresh(event: TravelEvent) async {
        // Only API-refreshable sources
        guard event.importSource.supportsStatusRefresh else { return }
        guard event.kind == .flight else { return }  // providers are flights-only

        // Skip terminal statuses ONLY when the flight has plausibly reached
        // them in real life. Without the time guard, an event that got
        // mistakenly stamped `.arrived` by the import-time stale-status bug
        // (daily flight number returning previous day's state) would never
        // be corrected — refresh would early-return and leave the bad
        // status frozen on screen even after the import-side fix lands.
        // For .completed we still trust the user's manual override.
        let now = Date()
        switch event.status {
        case .completed:
            return
        case .cancelled where event.departureInstant < now:
            return
        case .arrived where event.arrivalInstant < now:
            return
        default:
            break
        }
        // Already departed too long ago — don't waste API calls
        if event.arrivalInstant < now.addingTimeInterval(-3600) { return }

        // Rate-limit
        if let last = event.lastStatusRefreshedAt,
           Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }

        do {
            let iata = event.fullNumber
            guard !iata.isEmpty else { return }
            let latest = try await FlightProviderRegistry.active.realTimeStatus(iataNumber: iata)
            if let latest {
                apply(update: latest, to: event)
            }
        } catch {
            // Quiet failure — status stays stale
            debugPrint("[TravelStatus] refresh \(event.fullNumber) failed: \(error)")
        }
    }

    /// Merge API response into the local event, then propagate to Firestore.
    /// Without the push, a status / gate / terminal / delay update obtained
    /// on iPhone would never reach iPad, and a different device's pullAll
    /// would clobber it with the stale snapshot from when the trip was first
    /// imported.
    private func apply(update flight: FlightLookupResult, to event: TravelEvent) {
        let delay = flight.departure?.delayMinutes ?? 0
        if let status = flight.status {
            // Same stale-status guard as the initial import path. Daily
            // recurring flight numbers occasionally make the API return
            // the previous day's instance — without this, a periodic
            // refresh on a future-dated upcoming flight could overwrite
            // a healthy `.scheduled` with a stale `.arrived`.
            let apiStatus = TravelImporterMapping.mapStatus(status, delay: delay)
            event.status = TravelImporterMapping.guardAgainstStaleTerminalStatus(
                apiStatus,
                departure: event.departureInstant
            )
        }
        event.delayMinutes = max(0, delay)
        if let gate = flight.departure?.gate, !gate.isEmpty {
            event.departureGate = gate
        }
        if let terminal = flight.departure?.terminal, !terminal.isEmpty {
            event.departureTerminal = terminal
        }
        event.lastStatusRefreshedAt = Date()

        // Mirror the refreshed snapshot to Firestore so peer devices see it.
        TravelEventSyncService.shared.pushEvent(event)
    }
}
