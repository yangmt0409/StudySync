import SwiftUI

enum FontOption: String, CaseIterable, Identifiable {
    case `default` = "default"
    case rounded = "rounded"
    case serif = "serif"
    case mono = "mono"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return L10n.fontDefault
        case .rounded: return L10n.fontRounded
        case .serif: return L10n.fontSerif
        case .mono: return L10n.fontMono
        }
    }

    var preview: String { "StudySync 留时 123" }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .default:
            return .system(size: size, weight: weight)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
