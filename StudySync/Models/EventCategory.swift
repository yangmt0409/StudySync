import Foundation
import SwiftUI

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case academic = "学业"
    case visa = "签证"
    case travel = "旅行"
    case life = "生活"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .academic: return L10n.categoryAcademic
        case .visa: return L10n.categoryVisa
        case .travel: return L10n.categoryTravel
        case .life: return L10n.categoryLife
        }
    }

    var icon: String {
        switch self {
        case .academic: return "book.fill"
        case .visa: return "doc.text.fill"
        case .travel: return "airplane"
        case .life: return "heart.fill"
        }
    }

    var defaultEmoji: String {
        switch self {
        case .academic: return "📚"
        case .visa: return "📄"
        case .travel: return "✈️"
        case .life: return "🌟"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .academic: return "#5B7FFF"
        case .visa: return "#FF6B6B"
        case .travel: return "#4ECDC4"
        case .life: return "#FFB347"
        }
    }
}
