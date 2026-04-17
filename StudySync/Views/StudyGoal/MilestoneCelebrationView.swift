import SwiftUI

struct MilestoneCelebrationView: View {
    let goalTitle: String
    let goalEmoji: String
    let milestone: Milestone
    let colorHex: String
    let onDismiss: () -> Void

    @State private var particles: [ConfettiParticle] = []
    @State private var showContent = false
    @State private var showBadge = false
    @State private var badgeScale: CGFloat = 0.1
    @State private var ringProgress: CGFloat = 0
    @State private var timer: Timer?
    @State private var viewSize: CGSize = CGSize(width: 400, height: 800)
    @State private var isDismissing = false

    private var color: Color { Color(hex: colorHex) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                // Confetti
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.x - particle.size / 2,
                            y: particle.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        context.opacity = particle.opacity

                        if particle.size > 10 {
                            // Star-shaped for bigger particles
                            context.fill(
                                Circle().path(in: rect),
                                with: .color(particle.color)
                            )
                        } else {
                            context.fill(
                                RoundedRectangle(cornerRadius: particle.size * 0.2)
                                    .rotation(.degrees(particle.rotation))
                                    .path(in: rect),
                                with: .color(particle.color)
                            )
                        }
                    }
                }
                .ignoresSafeArea()

                // Center content
                if showContent {
                    VStack(spacing: 0) {
                        // Milestone badge with ring
                        ZStack {
                            // Glow ring
                            Circle()
                                .trim(from: 0, to: ringProgress)
                                .stroke(
                                    AngularGradient(
                                        colors: [color, color.opacity(0.5), .yellow, color],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 110, height: 110)
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 100, height: 100)

                            Text(milestone.emoji)
                                .font(.system(size: 48))
                                .scaleEffect(showBadge ? 1 : 0.1)
                        }
                        .padding(.bottom, 20)

                        // Title
                        Text(L10n.goalMilestoneReached)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(2)
                            .padding(.bottom, 8)

                        Text(milestone.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 12)

                        // Goal info
                        HStack(spacing: 6) {
                            Text(goalEmoji)
                                .font(.system(size: 18))
                            Text(goalTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.bottom, 24)

                        // Count badge
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("\(milestone.count)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(color.gradient)
                        )
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .scaleEffect(showBadge ? 1 : 0.95)
                }
            }
            .onAppear {
                viewSize = geo.size
                startAnimation()
                HapticEngine.shared.celebrationBurst()

                withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.2)) {
                    showContent = true
                }

                withAnimation(.spring(duration: 0.8, bounce: 0.5).delay(0.5)) {
                    showBadge = true
                    badgeScale = 1.0
                }

                withAnimation(.easeInOut(duration: 1.2).delay(0.4)) {
                    ringProgress = 1.0
                }

                // Auto dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    dismiss()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            timer?.invalidate()
            onDismiss()
        }
    }

    private func startAnimation() {
        // Initial burst
        for _ in 0..<80 {
            particles.append(makeParticle())
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y += particles[i].velocityY
                    particles[i].x += particles[i].velocityX
                    particles[i].rotation += particles[i].rotationSpeed
                    particles[i].velocityY += 0.25
                    particles[i].opacity -= 0.005
                }

                particles.removeAll { $0.opacity <= 0 || $0.y > viewSize.height + 50 }

                if particles.count < 120 {
                    particles.append(makeParticle())
                }
            }
        }
    }

    private func makeParticle() -> ConfettiParticle {
        let screenWidth = viewSize.width
        let colors: [Color] = [
            color, color.opacity(0.8),
            .yellow, .white, .orange, .mint,
            Color(hex: colorHex).opacity(0.6)
        ]

        return ConfettiParticle(
            x: CGFloat.random(in: 0...screenWidth),
            y: CGFloat.random(in: -120...(-10)),
            size: CGFloat.random(in: 5...16),
            color: colors.randomElement()!,
            opacity: 1.0,
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -10...10),
            velocityX: CGFloat.random(in: -3...3),
            velocityY: CGFloat.random(in: 0.5...3.5)
        )
    }
}

#Preview {
    MilestoneCelebrationView(
        goalTitle: "每日阅读",
        goalEmoji: "📖",
        milestone: Milestone(count: 30, emoji: "🔥", title: "30 天坚持"),
        colorHex: "#5B7FFF",
        onDismiss: {}
    )
}
