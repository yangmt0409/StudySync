import SwiftUI
import EventKit

struct AppUrgencyOverlay: View {
    var urgencyEngine = UrgencyEngine.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var breathPhase: Bool = false

    private var opacityMultiplier: Double {
        colorScheme == .dark ? 1.0 : 0.7
    }

    var body: some View {
        if urgencyEngine.hasActiveDeadline
            && urgencyEngine.lavaEffectEnabled
            && urgencyEngine.globalBorderEnabled
            && urgencyEngine.urgencyLevel > 0.05
        {
            let level = urgencyEngine.urgencyLevel
            let color = urgencyEngine.urgencyColor

            // Four edge gradients
            ZStack {
                // Top edge
                LinearGradient(
                    colors: [
                        color.opacity(level * 0.4 * opacityMultiplier * (breathPhase ? 1.0 : 0.6)),
                        color.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.15)
                )

                // Bottom edge — only center portion, avoid corners
                LinearGradient(
                    colors: [
                        color.opacity(level * 0.25 * opacityMultiplier * (breathPhase ? 1.0 : 0.6)),
                        color.opacity(0)
                    ],
                    startPoint: .bottom,
                    endPoint: UnitPoint(x: 0.5, y: 0.88)
                )
                .mask(
                    LinearGradient(
                        colors: [.clear, .white, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                // Left edge — only center portion, avoid corners
                LinearGradient(
                    colors: [
                        color.opacity(level * 0.15 * opacityMultiplier * (breathPhase ? 1.0 : 0.5)),
                        color.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: 0.08, y: 0.5)
                )
                .mask(
                    LinearGradient(
                        colors: [.clear, .white, .white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Right edge — only center portion, avoid corners
                LinearGradient(
                    colors: [
                        color.opacity(level * 0.15 * opacityMultiplier * (breathPhase ? 1.0 : 0.5)),
                        color.opacity(0)
                    ],
                    startPoint: .trailing,
                    endPoint: UnitPoint(x: 0.92, y: 0.5)
                )
                .mask(
                    LinearGradient(
                        colors: [.clear, .white, .white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .compositingGroup()
            .onAppear {
                startBreathing()
            }
            .onChange(of: level) { _, newLevel in
                startBreathing()
            }
        }
    }

    private func startBreathing() {
        let level = urgencyEngine.urgencyLevel
        // Faster breathing at higher urgency
        let duration = 2.0 + (1.0 - level) * 2.0

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            breathPhase = true
        }
    }
}

// MARK: - Urgency Banner (for HomeView)

struct UrgencyBanner: View {
    var urgencyEngine = UrgencyEngine.shared
    var onTap: (() -> Void)?

    var body: some View {
        if urgencyEngine.hasActiveDeadline,
           urgencyEngine.lavaEffectEnabled,
           let deadline = urgencyEngine.mostUrgentDeadline
        {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 8) {
                    Text("⚠️")
                    Text(deadline.title ?? L10n.noTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    Spacer()

                    Text(urgencyEngine.formattedRemainingTime)
                        .font(.subheadline.bold().monospacedDigit())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(urgencyEngine.urgencyColor)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
