import Foundation
import SwiftData

@Model
final class GradeComponent {
    var id: UUID = UUID()
    var name: String = ""
    var weightPercent: Double = 0          // e.g. 30.0 means 30%
    var scoreNumerator: Double?            // raw score earned (e.g. 42)
    var scoreDenominator: Double?          // raw score total  (e.g. 50)
    var scorePercent: Double?              // directly entered % (e.g. 84.0)
    var inputModeRaw: String = "raw"       // "raw" | "percent"
    var isFinal: Bool = false              // designate as the "final exam / project"
    var sortOrder: Int = 0
    var course: GradeCourse?

    // MARK: - Computed

    var inputMode: ComponentInputMode {
        get { ComponentInputMode(rawValue: inputModeRaw) ?? .raw }
        set { inputModeRaw = newValue.rawValue }
    }

    /// The effective percentage score (0–100) for this component.
    var effectivePercent: Double? {
        switch inputMode {
        case .raw:
            guard let num = scoreNumerator, let den = scoreDenominator, den > 0 else { return nil }
            return (num / den) * 100
        case .percent:
            return scorePercent
        }
    }

    /// Whether the user has entered a score.
    var hasScore: Bool {
        effectivePercent != nil
    }

    // MARK: - Init

    init(name: String, weightPercent: Double, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.weightPercent = weightPercent
        self.sortOrder = sortOrder
    }
}

// MARK: - Input Mode

enum ComponentInputMode: String, Codable, CaseIterable {
    case raw
    case percent

    var displayName: String {
        switch self {
        case .raw:     return L10n.gradeRawScore
        case .percent: return L10n.gradePercentScore
        }
    }
}
