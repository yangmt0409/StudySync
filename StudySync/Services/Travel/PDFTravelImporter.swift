import Foundation
import PDFKit

/// Best-effort parser for PDF boarding passes and e-tickets.
///
/// Strategy:
///   1. Extract text content via PDFKit.
///   2. Scan the full text for flight/train designators + airport IATA codes
///      + times.
///   3. Return a draft populated with whatever we found; user confirms in UI.
///
/// This is intentionally permissive — every airline and OTA formats their
/// PDF differently, and we don't want to fail hard on a slightly different
/// layout. Empty fields will show up as blanks in the confirmation form.
struct PDFTravelInput {
    /// URL to the PDF file (typically provided via Files picker or Share
    /// Extension). Caller retains ownership; we read it once.
    var fileURL: URL
}

struct PDFTravelImporter: TravelImporter {
    let source: TravelImportSource = .pdf

    func makeDraft(from input: PDFTravelInput) async throws -> TravelEvent {
        guard let doc = PDFDocument(url: input.fileURL) else {
            throw TravelImportError.readFailed(String(localized: "无法读取 PDF"))
        }
        let fullText = Self.extractText(from: doc)
        if fullText.isEmpty {
            throw TravelImportError.readFailed(String(localized: "PDF 内容为空"))
        }

        let kind = Self.detectKind(text: fullText)
        let (carrier, number) = Self.extractDesignator(text: fullText, kind: kind)
        let iataCodes = Self.extractIataCodes(text: fullText)
        let origin = iataCodes.first ?? ""
        let destination = iataCodes.count > 1 ? iataCodes[1] : ""
        let (depTime, arrTime) = Self.extractTimes(text: fullText)

        let e = TravelEvent(
            kind: kind,
            carrierCode: carrier,
            number: number,
            departureCity: origin,
            departureStation: origin,
            arrivalCity: destination,
            arrivalStation: destination,
            departureTimeLocal: depTime ?? Date(),
            arrivalTimeLocal: arrTime ?? (depTime ?? Date()).addingTimeInterval(3600),
            importSource: .pdf
        )
        e.departureStationCode = origin
        e.arrivalStationCode = destination
        return e
    }

    // MARK: - Parsing

    /// Cap to protect against pathological PDFs (a 50 MB scanned book would
    /// OOM the app and the regex passes would take forever). A boarding pass
    /// PDF is typically <10 KB; we're very permissive at 1 MB.
    private static let maxExtractedBytes = 1_000_000

    static func extractText(from doc: PDFDocument) -> String {
        var buf = ""
        for i in 0..<doc.pageCount {
            if buf.utf8.count >= maxExtractedBytes { break }
            if let text = doc.page(at: i)?.string {
                buf += text + "\n"
            }
        }
        // Hard cap — if a single page exceeds the limit, truncate.
        if buf.utf8.count > maxExtractedBytes {
            return String(buf.prefix(maxExtractedBytes))
        }
        return buf
    }

    static func detectKind(text: String) -> TravelKind {
        let t = text.lowercased()
        if t.contains("boarding pass") || t.contains("登机牌") || t.contains("flight") { return .flight }
        if t.contains("高铁") || t.contains("动车") || t.contains("bullet train") { return .highSpeedRail }
        if t.contains("train") || t.contains("铁路") { return .train }
        if t.contains("ferry") || t.contains("轮渡") { return .ferry }
        if t.contains("bus") || t.contains("coach") || t.contains("大巴") { return .longDistanceBus }
        return .flight
    }

    static func extractDesignator(text: String, kind: TravelKind) -> (String, String) {
        let upper = text.uppercased()
        let pattern: String
        switch kind {
        case .flight:
            pattern = #"\b[A-Z]{2,3}\s?\d{1,4}[A-Z]?\b"#
        case .highSpeedRail:
            pattern = #"\b[GDC]\d{1,5}\b"#
        case .train:
            pattern = #"\b[KTZYL]\d{1,5}\b"#
        default:
            return ("", "")
        }
        guard let range = upper.range(of: pattern, options: .regularExpression) else { return ("", "") }
        let match = String(upper[range]).replacingOccurrences(of: " ", with: "")
        if let digitIdx = match.firstIndex(where: { $0.isNumber }) {
            return (String(match[..<digitIdx]), String(match[digitIdx...]))
        }
        return ("", match)
    }

    /// Pull out 3-letter IATA airport codes (for flights). Heuristic returns
    /// all unique uppercase 3-letter tokens surrounded by word boundaries.
    /// Caveat: this matches random uppercase triplets; caller reviews.
    static func extractIataCodes(text: String) -> [String] {
        let upper = text.uppercased()
        var seen = Set<String>()
        var ordered: [String] = []
        // Common English non-airport 3-letter tokens to filter out
        let stopWords: Set<String> = ["THE", "AND", "FOR", "PDF", "NOT", "YES", "ALL", "NEW", "GMT", "UTC", "PST", "EST"]
        guard let regex = try? NSRegularExpression(pattern: #"\b[A-Z]{3}\b"#) else {
            return []
        }
        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)
        // Stop early once we have enough candidates — a boarding pass has 2
        // IATA codes (origin + destination). 20 is generous and prevents
        // runaway work on large books of uppercase text.
        let maxMatches = 20
        regex.enumerateMatches(in: upper, range: range) { match, _, stop in
            guard let match else { return }
            let code = nsText.substring(with: match.range)
            if stopWords.contains(code) { return }
            if seen.insert(code).inserted {
                ordered.append(code)
                if ordered.count >= maxMatches { stop.pointee = true }
            }
        }
        return ordered
    }

    /// Find two HH:MM time stamps in the text, interpreting them as
    /// departure and arrival. When only one is found, we return it for
    /// departure and leave arrival nil (caller fills arrival manually).
    static func extractTimes(text: String) -> (Date?, Date?) {
        guard let regex = try? NSRegularExpression(pattern: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#) else {
            return (nil, nil)
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return (nil, nil) }

        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        func build(_ hm: String) -> Date? {
            let parts = hm.split(separator: ":").map { Int($0) ?? 0 }
            guard parts.count == 2 else { return nil }
            return cal.date(byAdding: DateComponents(hour: parts[0], minute: parts[1]), to: today)
        }

        let first = build(nsText.substring(with: matches[0].range))
        let second = matches.count > 1 ? build(nsText.substring(with: matches[1].range)) : nil
        return (first, second)
    }
}
