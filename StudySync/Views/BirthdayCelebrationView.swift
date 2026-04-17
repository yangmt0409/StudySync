import SwiftUI

/// Full-screen birthday celebration overlay shown once per year on the user's birthday.
/// Uses confetti particles, cake emoji, and a personalized greeting.
struct BirthdayCelebrationView: View {
    let displayName: String
    let onDismiss: () -> Void

    @State private var particles: [ConfettiParticle] = []
    @State private var showContent = false
    @State private var cakeScale: CGFloat = 0
    @State private var glowOpacity: Double = 0
    @State private var timer: Timer?
    @State private var viewSize: CGSize = CGSize(width: 400, height: 800)

    private let birthdayColors: [Color] = [
        .pink, .orange, .yellow, .green, .cyan, .blue, .purple,
        Color(hex: "#FF6B9D"), Color(hex: "#FFD93D"), Color(hex: "#4ECDC4")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark backdrop
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
                        context.fill(
                            RoundedRectangle(cornerRadius: particle.size * 0.2)
                                .rotation(.degrees(particle.rotation))
                                .path(in: rect),
                            with: .color(particle.color)
                        )
                    }
                }
                .ignoresSafeArea()

                // Center content
                if showContent {
                    VStack(spacing: 20) {
                        // Cake emoji with glow
                        Text("🎂")
                            .font(.system(size: 80))
                            .scaleEffect(cakeScale)
                            .shadow(color: .orange.opacity(glowOpacity), radius: 30)

                        VStack(spacing: 8) {
                            Text(L10n.birthdayGreeting(name: displayName))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(L10n.birthdayWish)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        // Decorative emoji row
                        HStack(spacing: 12) {
                            Text("🎉").font(.title)
                            Text("🎈").font(.title)
                            Text("🎁").font(.title)
                            Text("🥳").font(.title)
                            Text("🎊").font(.title)
                        }
                        .padding(.top, 4)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .onAppear {
                viewSize = geo.size
                startAnimation()
                HapticEngine.shared.celebrationBurst()

                // Show content with spring
                withAnimation(.spring(duration: 0.6).delay(0.2)) {
                    showContent = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
                    cakeScale = 1
                }
                // Glow pulse
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.5)) {
                    glowOpacity = 0.6
                }

                // Auto dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    dismiss()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) { showContent = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            timer?.invalidate()
            onDismiss()
        }
    }

    private func startAnimation() {
        // Initial burst — more particles for birthday
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
                    particles[i].opacity -= 0.003
                }
                particles.removeAll { $0.opacity <= 0 || $0.y > viewSize.height + 50 }
                if particles.count < 120 {
                    particles.append(makeParticle())
                }
            }
        }
    }

    private func makeParticle() -> ConfettiParticle {
        ConfettiParticle(
            x: CGFloat.random(in: 0...viewSize.width),
            y: CGFloat.random(in: -120...(-20)),
            size: CGFloat.random(in: 6...16),
            color: birthdayColors.randomElement()!,
            opacity: 1.0,
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -10...10),
            velocityX: CGFloat.random(in: -3...3),
            velocityY: CGFloat.random(in: 1...5)
        )
    }
}

// MARK: - Birthday Check Helper

enum BirthdayChecker {
    /// Returns true if today matches the user's birthday (month + day).
    static func isBirthdayToday(_ birthday: Date?) -> Bool {
        guard let birthday else { return false }
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let bday = cal.dateComponents([.month, .day], from: birthday)
        return today.month == bday.month && today.day == bday.day
    }

    /// Returns the key for tracking whether we've shown the birthday celebration today.
    static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "birthdayCelebration_\(formatter.string(from: Date()))"
    }

    /// Whether the celebration has already been shown today.
    static var hasShownToday: Bool {
        UserDefaults.standard.bool(forKey: todayKey)
    }

    /// Mark the celebration as shown for today.
    static func markShown() {
        UserDefaults.standard.set(true, forKey: todayKey)
    }
}
