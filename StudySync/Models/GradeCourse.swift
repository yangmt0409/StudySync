import Foundation
import SwiftData

@Model
final class GradeCourse {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "📘"
    var colorHex: String = "#5B7FFF"
    var targetGradePercent: Double = 90.0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \GradeComponent.course)
    var components: [GradeComponent] = []

    // MARK: - Computed

    var sortedComponents: [GradeComponent] {
        components.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Sum of all component weights (should be 100).
    var totalWeight: Double {
        components.reduce(0) { $0 + $1.weightPercent }
    }

    /// Whether total weight is valid (== 100 within epsilon).
    var isWeightValid: Bool {
        abs(totalWeight - 100.0) < 0.01
    }

    /// Sum of weights for components that have entered scores.
    var enteredWeight: Double {
        components.filter(\.hasScore).reduce(0) { $0 + $1.weightPercent }
    }

    /// Sum of weights for components that do NOT have scores yet.
    var remainingWeight: Double {
        components.filter { !$0.hasScore }.reduce(0) { $0 + $1.weightPercent }
    }

    /// Current weighted contribution from entered components (as a fraction of 100).
    /// e.g. if Midterm (30%, scored 80%) → contributes 24.0 points out of 100.
    var currentWeightedScore: Double {
        var total = 0.0
        for comp in components where comp.hasScore {
            if let pct = comp.effectivePercent {
                total += (pct / 100.0) * comp.weightPercent
            }
        }
        return total
    }

    /// The component designated as "Final Exam / Final Project".
    var finalComponent: GradeComponent? {
        components.first(where: \.isFinal)
    }

    /// What score is needed specifically on the Final to reach `targetGradePercent`.
    ///
    /// Formula: needed = (target − currentWeightedScore) / finalWeight × 100
    /// Returns `nil` if no final is designated, final already has a score, or weight is 0.
    var neededScoreOnFinal: Double? {
        guard let final = finalComponent, !final.hasScore, final.weightPercent > 0 else { return nil }
        let needed = ((targetGradePercent - currentWeightedScore) / final.weightPercent) * 100
        return max(needed, 0)
    }

    /// Fallback: average score needed across all remaining (unentered) components.
    var neededScoreOnRemaining: Double? {
        let rw = remainingWeight
        guard rw > 0 else { return nil }
        let needed = ((targetGradePercent - currentWeightedScore) / rw) * 100
        return max(needed, 0)
    }

    /// The effective "needed" score — prefers final-specific, falls back to remaining.
    var neededScore: Double? {
        neededScoreOnFinal ?? neededScoreOnRemaining
    }

    /// Whether the target is still achievable (needed ≤ 100%).
    var isTargetReachable: Bool {
        guard let needed = neededScore else {
            return currentWeightedScore >= targetGradePercent - 0.01
        }
        return needed <= 100.0
    }

    // MARK: - Init

    init(name: String, emoji: String = "📘", colorHex: String = "#5B7FFF", targetGradePercent: Double = 90.0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.targetGradePercent = targetGradePercent
        self.isArchived = false
        self.createdAt = Date()
        self.components = []
    }
}
