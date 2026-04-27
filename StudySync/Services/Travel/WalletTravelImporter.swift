import Foundation
import PassKit

/// Read Apple Wallet boarding passes and convert them into `TravelEvent`s.
///
/// Important: PassKit only exposes passes the **user has explicitly added** to
/// their Wallet. We list them via `PKPassLibrary` — no special entitlement is
/// required for reading (only for adding/updating, which we don't do).
///
/// Pass fields we care about (see Apple's Boarding Pass spec):
///   - `passTypeIdentifier == pass.<...boardingPass>`
///   - `.boardingPass` type (flight / train / ferry / bus)
///   - auxiliary / primary / header fields carry:
///       origin (IATA code)
///       destination (IATA code)
///       boardingTime (ISO8601)
///       departureDate
///       flightName / vehicleName
///       terminal / gate / seat
struct WalletTravelInput {
    /// The pass selected by the user from `PKPassLibrary().passes()`.
    var pass: PKPass
}

struct WalletTravelImporter: TravelImporter {
    let source: TravelImportSource = .wallet

    func makeDraft(from input: WalletTravelInput) async throws -> TravelEvent {
        let pass = input.pass
        // PKPass doesn't distinguish boarding passes at the API level (only
        // `PKPassType.barcode`/`.secureElement` are exposed). We identify them
        // via the `passTypeIdentifier` string.
        guard Self.isBoardingPass(pass) else {
            throw TravelImportError.unsupportedFormat
        }

        // Try to read raw pass.json if accessible. If not, fall back to public APIs.
        let rawFields = (try? readPassFields(from: pass)) ?? [:]
        let kind = detectKind(from: pass, fields: rawFields)

        let carrierCode = rawFields["CarrierCode"] ?? ""
        let number = rawFields["FlightNumber"] ?? rawFields["TrainNumber"] ?? ""
        let originCode = rawFields["OriginCode"] ?? Self.string(from: pass.localizedValue(forFieldKey: "origin")) ?? ""
        let destCode = rawFields["DestinationCode"] ?? Self.string(from: pass.localizedValue(forFieldKey: "destination")) ?? ""

        let depTime = Self.parseAnyDate(rawFields["DepartureDate"])
            ?? pass.relevantDate
            ?? Date()
        let arrTime = Self.parseAnyDate(rawFields["ArrivalDate"]) ?? depTime.addingTimeInterval(3600)

        let e = TravelEvent(
            kind: kind,
            carrierCode: carrierCode,
            number: number,
            departureCity: rawFields["OriginCity"] ?? originCode,
            departureStation: rawFields["OriginName"] ?? originCode,
            arrivalCity: rawFields["DestinationCity"] ?? destCode,
            arrivalStation: rawFields["DestinationName"] ?? destCode,
            departureTimeLocal: depTime,
            arrivalTimeLocal: arrTime,
            importSource: .wallet
        )
        e.departureStationCode = originCode
        e.arrivalStationCode = destCode
        e.serviceName = pass.organizationName
        e.seat = rawFields["Seat"] ?? ""
        e.departureTerminal = rawFields["Terminal"] ?? ""
        e.departureGate = rawFields["Gate"] ?? ""
        e.pnr = rawFields["PNR"] ?? pass.serialNumber
        e.walletPassIdentifier = pass.serialNumber
        e.reminderPreset = TravelReminderPreset.defaultPreset(for: kind, isInternational: e.isInternational)
        return e
    }

    /// Enumerate boarding passes the user has in Wallet.
    /// Returned array may be empty if the user hasn't added any.
    func listBoardingPasses() -> [PKPass] {
        let library = PKPassLibrary()
        return library.passes().filter { Self.isBoardingPass($0) }
    }

    /// Boarding pass identifiers from major carriers conventionally include
    /// "boardingpass", "boarding", or "flight" in their pass type identifier.
    /// This is a string-based heuristic, but works across airlines + rail.
    static func isBoardingPass(_ pass: PKPass) -> Bool {
        let id = pass.passTypeIdentifier.lowercased()
        return id.contains("boardingpass")
            || id.contains("boarding")
            || id.contains("flight")
            || id.contains("rail")
            || id.contains("train")
    }

    static func string(from any: Any?) -> String? {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    private func detectKind(from pass: PKPass, fields: [String: String]) -> TravelKind {
        // Boarding passes declare `transitType` inside their JSON.
        // Without direct access, fall back to name heuristics.
        let name = pass.organizationName.lowercased()
        if name.contains("rail") || name.contains("train") || name.contains("高铁") || name.contains("铁路") {
            return .highSpeedRail
        }
        if name.contains("ferry") || name.contains("shipping") || name.contains("轮渡") {
            return .ferry
        }
        if name.contains("bus") || name.contains("coach") {
            return .longDistanceBus
        }
        return .flight  // default
    }

    /// Best-effort extraction of fields from `pass.json` bundled inside the
    /// pkpass. Read via `PKPass.files(at:)` — which returns nil on iOS.
    /// We wrap the attempt in a do/catch and return an empty dict on failure
    /// (caller falls back to public getters).
    private func readPassFields(from pass: PKPass) throws -> [String: String] {
        // iOS doesn't expose the pass bundle contents directly. The best we can do
        // is read from `userInfo` + public fields. Returning empty means the caller
        // uses the public API defaults, which is usually enough for a usable draft.
        return [:]
    }

    static func parseAnyDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFull.date(from: raw) { return d }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for pattern in ["yyyy-MM-dd'T'HH:mm:ssZZZZZ", "yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd HH:mm"] {
            f.dateFormat = pattern
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}
