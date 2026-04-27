import Foundation

/// One detected layover between two `TravelEvent`s — either a same-airport
/// transit (CX829 → CX880 both at HKG) or an inter-airport transfer in the
/// same city (LH NRT-arrival → JL HND-departure).
///
/// Surfaced in Schedule via a small banner pinned above the next leg's card.
struct TravelConnection: Equatable {
    let previousId: UUID
    let nextId: UUID
    /// Layover length in minutes (always > 0; capped to detection window).
    let layoverMinutes: Int
    /// True when prev arrival airport == next departure airport (same IATA).
    /// False when the two are distinct airports in the same city — user must
    /// transfer between airports (NRT ↔ HND etc.).
    let isSameAirport: Bool
    /// IATA codes for the two endpoints; used to render "NRT → HND" labels.
    let prevArrivalCode: String
    let nextDepartureCode: String
}

/// Detects layovers between consecutive travel events.
///
/// Detection rules:
///   - Two events count as a connection iff prev's arrival airport and next's
///     departure airport resolve to the same city (same IATA, or both belong
///     to the same multi-airport city in the static table below).
///   - Layover must be `> 0` and `≤ 18h`. The 18h cap is generous on purpose
///     — overnight transits (12-18h) are common for long-haul itineraries
///     where travelers book a hotel; we still want to surface the link so
///     the user sees the trip is a connection rather than two unrelated
///     flights.
///   - We only chain ADJACENT events when sorted by `departureInstant`.
///     If the user has Flight A (arrives YYZ), then a 5-day gap, then Flight
///     B (departs YYZ), B isn't a connection — it's a separate trip.
///   - `markedComplete` events are skipped (the user manually closed them).
///
/// Why a static table for multi-airport cities instead of an API:
///   - Adding ~25 hubs covers the >95% case for our user base.
///   - An online lookup would add a dependency on a third-party API for what
///     is essentially constant data (airports rarely move between cities).
///   - List is easy to extend in code review when missing hubs surface.
enum TravelConnectionDetector {

    /// Multi-airport cities. Codes within the same value-set are treated as
    /// "same city" for connection detection. UPPERCASE IATA throughout.
    private static let multiAirportCities: [Set<String>] = [
        ["NRT", "HND"],                    // Tokyo
        ["KIX", "ITM"],                    // Osaka
        ["PVG", "SHA"],                    // Shanghai
        ["PEK", "PKX"],                    // Beijing (Capital + Daxing)
        ["ICN", "GMP"],                    // Seoul
        ["TPE", "TSA"],                    // Taipei (Taoyuan + Songshan)
        ["BKK", "DMK"],                    // Bangkok (Suvarnabhumi + Don Mueang)
        ["HKG"],                           // Hong Kong (single)
        ["JFK", "LGA", "EWR"],             // New York
        ["IAD", "DCA", "BWI"],             // Washington DC
        ["ORD", "MDW"],                    // Chicago
        ["LAX", "BUR", "LGB", "SNA", "ONT"], // Los Angeles
        ["SFO", "OAK", "SJC"],             // San Francisco Bay Area
        ["IAH", "HOU"],                    // Houston
        ["MIA", "FLL"],                    // Miami / Fort Lauderdale
        ["DAL", "DFW"],                    // Dallas
        ["YYZ", "YTZ"],                    // Toronto (Pearson + Billy Bishop)
        ["LHR", "LGW", "STN", "LTN", "LCY"], // London
        ["CDG", "ORY", "BVA"],             // Paris
        ["FCO", "CIA"],                    // Rome
        ["MXP", "LIN", "BGY"],             // Milan
        ["ARN", "BMA"],                    // Stockholm
        ["SVO", "DME", "VKO"],             // Moscow
        ["EZE", "AEP"],                    // Buenos Aires
        ["GRU", "CGH", "VCP"],             // São Paulo
        ["GIG", "SDU"],                    // Rio de Janeiro
        ["MEL", "AVV"],                    // Melbourne
    ]

    /// Maximum layover we'll still surface as a connection. Long enough to
    /// capture overnight transits (e.g. 14h sleep-in-airport-hotel scenarios)
    /// but short enough to exclude two unrelated trips that happen to have
    /// adjacent dates at the same hub.
    private static let maxLayover: TimeInterval = 18 * 3600

    /// True when two airport codes belong to the same city. Either:
    ///   - identical (same airport, e.g. transit at HKG)
    ///   - both members of one of the multi-airport sets above
    static func sameCity(arrival: String, departure: String) -> Bool {
        let a = arrival.uppercased()
        let d = departure.uppercased()
        guard !a.isEmpty, !d.isEmpty else { return false }
        if a == d { return true }
        for set in multiAirportCities where set.contains(a) && set.contains(d) {
            return true
        }
        return false
    }

    /// Walk a list of `TravelEvent` (any order) and return all detected
    /// adjacent layovers in chronological order. Idempotent and side-effect
    /// free — call from a view's computed property without worry.
    static func detect(events: [TravelEvent]) -> [TravelConnection] {
        let sorted = events
            .filter { !$0.markedComplete }
            .sorted { $0.departureInstant < $1.departureInstant }

        guard sorted.count >= 2 else { return [] }

        var out: [TravelConnection] = []
        for i in 0..<(sorted.count - 1) {
            let prev = sorted[i]
            let next = sorted[i + 1]
            let prevArrival = prev.arrivalStationCode
            let nextDeparture = next.departureStationCode
            guard sameCity(arrival: prevArrival, departure: nextDeparture) else { continue }
            let layover = next.departureInstant.timeIntervalSince(prev.arrivalInstant)
            guard layover > 0, layover <= maxLayover else { continue }
            out.append(TravelConnection(
                previousId: prev.id,
                nextId: next.id,
                layoverMinutes: Int(layover / 60),
                isSameAirport: prevArrival.uppercased() == nextDeparture.uppercased(),
                prevArrivalCode: prevArrival.uppercased(),
                nextDepartureCode: nextDeparture.uppercased()
            ))
        }
        return out
    }

    /// Build a lookup keyed by the next leg's id — the consumer just needs
    /// "given a TravelEvent, is it the next leg of a connection?". O(1)
    /// query for the rendering loop.
    static func indexByNextId(events: [TravelEvent]) -> [UUID: TravelConnection] {
        let detected = detect(events: events)
        return Dictionary(uniqueKeysWithValues: detected.map { ($0.nextId, $0) })
    }
}
