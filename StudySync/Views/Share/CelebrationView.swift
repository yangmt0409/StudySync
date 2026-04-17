import SwiftUI

struct CelebrationView: View {
    let eventTitle: String
    let colorHex: String
    let onDismiss: () -> Void

    @State private var particles: [ConfettiParticle] = []
    @State private var showText = false
    @State private var timer: Timer?
    @State private var viewSize: CGSize = CGSize(width: 400, height: 800)

    private var color: Color { Color(hex: colorHex) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                // Confetti particles
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

                // Center text
                if showText {
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 64))

                        Text(eventTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(L10n.completed)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                viewSize = geo.size
                startAnimation()
                HapticEngine.shared.celebrationBurst()

                withAnimation(.spring(duration: 0.5).delay(0.3)) {
                    showText = true
                }

                // Auto dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    dismiss()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            showText = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            timer?.invalidate()
            onDismiss()
        }
    }

    private func startAnimation() {
        // Generate initial burst
        for _ in 0..<60 {
            particles.append(makeParticle())
        }

        // Continue adding particles
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Update existing particles
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y += particles[i].velocityY
                    particles[i].x += particles[i].velocityX
                    particles[i].rotation += particles[i].rotationSpeed
                    particles[i].velocityY += 0.3 // gravity
                    particles[i].opacity -= 0.004
                }

                // Remove dead particles
                particles.removeAll { $0.opacity <= 0 || $0.y > viewSize.height + 50 }

                // Add new ones (up to a limit)
                if particles.count < 100 {
                    particles.append(makeParticle())
                }
            }
        }
    }

    private func makeParticle() -> ConfettiParticle {
        let screenWidth = viewSize.width
        let colors: [Color] = [
            color, color.opacity(0.8),
            .yellow, .white, .orange,
            Color(hex: colorHex).opacity(0.6)
        ]

        return ConfettiParticle(
            x: CGFloat.random(in: 0...screenWidth),
            y: CGFloat.random(in: -100...(-20)),
            size: CGFloat.random(in: 6...14),
            color: colors.randomElement()!,
            opacity: 1.0,
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -8...8),
            velocityX: CGFloat.random(in: -2...2),
            velocityY: CGFloat.random(in: 1...4)
        )
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
    var rotation: Double
    var rotationSpeed: Double
    var velocityX: CGFloat
    var velocityY: CGFloat
}

// MARK: - Clear Background for fullScreenCover

struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    CelebrationView(
        eventTitle: "期末考试周",
        colorHex: "#5B7FFF",
        onDismiss: {}
    )
}
