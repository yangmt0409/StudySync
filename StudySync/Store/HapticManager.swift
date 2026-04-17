import UIKit

final class HapticEngine {
    static let shared = HapticEngine()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {}

    // MARK: - Impact

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: lightGenerator.impactOccurred()
        case .medium: mediumGenerator.impactOccurred()
        case .heavy: heavyGenerator.impactOccurred()
        default: UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    // MARK: - Notification

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }

    // MARK: - Selection

    func selection() {
        selectionGenerator.selectionChanged()
    }

    // MARK: - Convenience

    func lightImpact() { lightGenerator.impactOccurred() }
    func mediumImpact() { mediumGenerator.impactOccurred() }
    func heavyImpact() { heavyGenerator.impactOccurred() }

    func success() { notification(.success) }
    func warning() { notification(.warning) }
    func error() { notification(.error) }

    // MARK: - Celebration Pattern

    func celebrationBurst() {
        notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            heavyGenerator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            heavyGenerator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            mediumGenerator.impactOccurred()
        }
    }
}
