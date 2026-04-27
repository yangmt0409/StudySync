import Foundation

/// Parse PDF417 and QR barcodes found on boarding passes / rail tickets.
///
/// Two formats we support:
///
/// ### 1. IATA BCBP (Bar-Coded Boarding Pass) — flights
/// Defined in IATA Resolution 792. Fixed-width ASCII format readable from
/// the paper/mobile boarding pass barcode. Example:
///   `M1YANG/MAITONG    EABCD1 PEKYYZCA 981 115Y014A0001 100`
///    ^                ^PNR  ^ORG^DST^CA ^NUM ^DAY ^SEAT
///
/// ### 2. Chinese 12306 rail ticket QR
/// QR payload from printed high-speed rail tickets includes coded car + seat
/// + train number but the actual text format is proprietary / unpublished.
/// We can detect the format by looking for the "C" prefix at start; full
/// decoding requires the 12306 app. We just grab the train number if present.
struct BarcodeTravelInput {
    /// Raw string captured from an AVFoundation barcode scan.
    var payload: String
    /// Hint from the scanner: `.pdf417` (flight) or `.qr` (rail / other).
    var format: BarcodeFormat
}

enum BarcodeFormat {
    case pdf417
    case qr
    case other
}

struct BarcodeTravelImporter: TravelImporter {
    let source: TravelImportSource = .barcode

    func makeDraft(from input: BarcodeTravelInput) async throws -> TravelEvent {
        switch input.format {
        case .pdf417:
            return try parseBCBP(input.payload)
        case .qr:
            return try parseRailQR(input.payload)
        case .other:
            throw TravelImportError.unsupportedFormat
        }
    }

    // MARK: - BCBP (flights)

    /// Parse an IATA-compliant boarding pass barcode.
    /// Supports "M1" (mandatory-only) format plus optional trailing fields.
    /// Returns a draft with the reliably parsed fields; user fills in the
    /// airline's airport names by following up with an API lookup if desired.
    private func parseBCBP(_ raw: String) throws -> TravelEvent {
        // BCBP layout:
        //   M<n>      - Version + number of legs
        //   Name     - positions 3..22 (20 chars, "LAST/FIRST")
        //   Electronic ticket indicator (E or blank) - 23
        //   PNR      - 24..30 (7 chars)
        //   From    - 31..33 (3-letter IATA)
        //   To      - 34..36
        //   Carrier - 37..39 (airline code, right-padded)
        //   Flight  - 40..44 (5 chars, right-justified)
        //   Day of year (Julian) - 45..47 (3 digits)
        //   Class    - 48
        //   Seat    - 49..52
        //   Check-in seq - 53..57
        //   Status  - 58
        let str = raw
        guard str.hasPrefix("M"), str.count >= 58 else {
            throw TravelImportError.unsupportedFormat
        }

        let chars = Array(str)
        func slice(_ start: Int, _ end: Int) -> String {
            let lo = min(start, chars.count)
            let hi = min(end, chars.count)
            guard lo < hi else { return "" }
            return String(chars[lo..<hi]).trimmingCharacters(in: .whitespaces)
        }

        let name = slice(2, 22)
        let pnr = slice(23, 30)
        let from = slice(30, 33)
        let to = slice(33, 36)
        let carrier = slice(36, 39)
        let flightNumber = slice(39, 44).trimmingCharacters(in: CharacterSet(charactersIn: " 0"))
        let julianDay = slice(44, 47)
        let seat = slice(48, 52)

        // Reconstruct a scheduled date using Julian day + current year.
        // (BCBP doesn't encode the year; boarding passes typically expire
        //  same-year. If user scans an old pass, they can correct the date.)
        let dayOfYear = Int(julianDay) ?? 0
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: now)
        // iOS 17-safe way to construct a date from day-of-year:
        // set month=1, day=dayOfYear and let Calendar normalize.
        var comp = DateComponents()
        comp.year = year
        comp.month = 1
        comp.day = max(1, dayOfYear)
        let date = cal.date(from: comp) ?? now

        let e = TravelEvent(
            kind: .flight,
            carrierCode: carrier.trimmingCharacters(in: .whitespaces),
            number: flightNumber,
            departureCity: from,
            departureStation: from,
            arrivalCity: to,
            arrivalStation: to,
            departureTimeLocal: date,
            arrivalTimeLocal: date.addingTimeInterval(3600),  // placeholder
            importSource: .barcode
        )
        e.departureStationCode = from
        e.arrivalStationCode = to
        e.seat = seat
        e.pnr = pnr
        e.passengerName = name.replacingOccurrences(of: "/", with: " ")
        return e
    }

    // MARK: - Rail QR (China 12306)

    /// Parse a 12306 high-speed rail ticket QR code.
    /// The payload format is proprietary + encrypted, so we extract only what
    /// the user can verify: train number if present in plain text, else fail.
    private func parseRailQR(_ raw: String) throws -> TravelEvent {
        // Look for "G"/"D"/"C" + digits anywhere in the string
        let pattern = #"[GDC]\d{1,5}"#
        if let range = raw.range(of: pattern, options: .regularExpression) {
            let designator = String(raw[range])
            let kind: TravelKind = designator.hasPrefix("C") ? .intercityTrain : .highSpeedRail
            let e = TravelEvent(
                kind: kind,
                carrierCode: String(designator.prefix(1)),
                number: String(designator.dropFirst()),
                importSource: .barcode
            )
            return e
        }
        throw TravelImportError.unsupportedFormat
    }
}
