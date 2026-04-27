import Foundation

/// Receives text/URL payloads from:
///   - `studysync://travel?...` URL schemes
///   - Share Extension hand-offs (via App Group UserDefaults queue)
///   - Manual paste in the AddTravelView
///
/// Applies format detection + parsing using simple regex heuristics. Known
/// supported sources (best to worst reliability):
///
///   * Ctrip / 携程 HTML+text share
///   * 12306 confirmation email text
///   * Generic airline itinerary text
///   * Freeform text — best effort designator scan
///
/// Consumers of this service get back either a `TravelEvent` draft or the
/// identified designator (for passing into FlightAPIImporter).
struct ShareIntakeService {

    enum IntakeResult {
        /// Parsed enough to propose a full draft (still user-confirmable).
        case draft(TravelEvent)
        /// Only identified the flight number — caller should run API lookup.
        case designator(carrierCode: String, number: String, kind: TravelKind, date: Date?)
        /// Nothing recognizable.
        case unknown
    }

    func parse(_ payload: String) -> IntakeResult {
        let normalized = payload
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
        if normalized.isEmpty { return .unknown }

        // 1. Try to extract designator + date
        if let designator = extractDesignator(normalized) {
            // Date hint: look for YYYY-MM-DD / M月d日 / MMM d, YYYY
            let date = extractDate(normalized)
            return .designator(
                carrierCode: designator.carrier,
                number: designator.number,
                kind: designator.kind,
                date: date
            )
        }

        return .unknown
    }

    private struct Designator {
        let carrier: String
        let number: String
        let kind: TravelKind
    }

    private func extractDesignator(_ text: String) -> Designator? {
        let upper = text.uppercased()
        // Try flight first (most specific patterns first)
        let patterns: [(String, TravelKind)] = [
            (#"\b[A-Z]{2,3}\s?\d{1,4}[A-Z]?\b"#, .flight),
            (#"\b[GDC]\d{1,5}\b"#, .highSpeedRail),
            (#"\b[KTZYL]\d{1,5}\b"#, .train),
        ]
        for (pattern, kind) in patterns {
            if let range = upper.range(of: pattern, options: .regularExpression) {
                let raw = String(upper[range]).replacingOccurrences(of: " ", with: "")
                if let digitIdx = raw.firstIndex(where: { $0.isNumber }) {
                    return Designator(
                        carrier: String(raw[..<digitIdx]),
                        number: String(raw[digitIdx...]),
                        kind: kind
                    )
                }
            }
        }
        return nil
    }

    private func extractDate(_ text: String) -> Date? {
        let patterns: [String] = [
            #"\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b"#,         // 2026-04-25
            #"\b\d{1,2}月\s?\d{1,2}日\b"#,                  // 4月25日
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+20\d{2}\b"#,
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let raw = String(text[range])
                if let d = Self.parseFlexibleDate(raw) { return d }
            }
        }
        return nil
    }

    static func parseFlexibleDate(_ raw: String) -> Date? {
        let formatters: [DateFormatter] = [
            dateFormatter("yyyy-MM-dd"),
            dateFormatter("yyyy/MM/dd"),
            dateFormatter("MMM d, yyyy", locale: "en_US_POSIX"),
            dateFormatter("M月d日", locale: "zh_CN"),
        ]
        for f in formatters {
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }

    static func dateFormatter(_ pattern: String, locale: String = "en_US_POSIX") -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = pattern
        f.locale = Locale(identifier: locale)
        return f
    }

    // MARK: - URL scheme

    /// Parse `studysync://travel?flight=CA981&date=2026-04-25` style deep links.
    /// Defensively caps query values at 256 characters to avoid regex DoS via a
    /// malicious deep link.
    static func parseTravelURL(_ url: URL) -> IntakeResult {
        guard url.scheme == "studysync", url.host == "travel" else { return .unknown }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        let maxLength = 256
        let flight = (queryItems.first { $0.name == "flight" }?.value ?? "").prefix(maxLength)
        let train  = (queryItems.first { $0.name == "train"  }?.value ?? "").prefix(maxLength)
        let dateRaw = (queryItems.first { $0.name == "date" }?.value ?? "").prefix(maxLength)
        let date = parseFlexibleDate(String(dateRaw))

        let combined = String(flight.isEmpty ? train : flight)
        if combined.isEmpty { return .unknown }
        let service = ShareIntakeService()
        if let d = service.extractDesignator(combined) {
            return .designator(carrierCode: d.carrier, number: d.number, kind: d.kind, date: date)
        }
        return .unknown
    }
}
