import Foundation

/// How a travel event was imported. Used for analytics + tailoring refresh
/// behavior (e.g., only flights imported via API get real-time status polling).
nonisolated enum TravelImportSource: String, Codable, CaseIterable, Sendable {
    case manual           // typed in by the user
    case flightAPI        // looked up via AviationStack
    case wallet           // imported from Apple Wallet pkpass
    case calendar         // auto-promoted from an EventKit event / .ics
    case barcode          // scanned PDF417 / QR barcode
    case pdf              // parsed from a PDF boarding pass
    case shareExtension   // received via iOS share sheet
    case urlScheme        // opened via studysync:// deep link
    case railStationDB    // manual + auto-complete from HSR station database

    var label: String {
        switch self {
        case .manual:          return String(localized: "手动输入")
        case .flightAPI:       return String(localized: "航班号查询")
        case .wallet:          return String(localized: "Apple Wallet")
        case .calendar:        return String(localized: "日历导入")
        case .barcode:         return String(localized: "扫描条码")
        case .pdf:             return String(localized: "PDF 解析")
        case .shareExtension:  return String(localized: "分享导入")
        case .urlScheme:       return String(localized: "深链接")
        case .railStationDB:   return String(localized: "车次查询")
        }
    }

    var symbolName: String {
        switch self {
        case .manual:          return "square.and.pencil"
        case .flightAPI:       return "magnifyingglass"
        case .wallet:          return "wallet.pass.fill"
        case .calendar:        return "calendar"
        case .barcode:         return "barcode.viewfinder"
        case .pdf:             return "doc.fill"
        case .shareExtension:  return "square.and.arrow.up"
        case .urlScheme:       return "link"
        case .railStationDB:   return "tram"
        }
    }

    /// Whether this source supports pulling fresh status data after import.
    /// Only flights from the API can be refreshed; everything else is static.
    var supportsStatusRefresh: Bool {
        self == .flightAPI || self == .wallet
    }
}
