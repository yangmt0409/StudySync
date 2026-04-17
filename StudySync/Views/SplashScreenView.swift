import SwiftUI
import SwiftData

// MARK: - SplashScreenView

struct SplashScreenView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var colorScheme

    @State private var phase = 0
    @State private var screenSize: CGSize = .zero

    // Phase 1: path drawing
    @State private var bottomDotOpacity: Double = 0
    @State private var pathTrim: CGFloat = 0
    @State private var topDotScale: CGFloat = 0
    @State private var topDotGlow: CGFloat = 0

    // Phase 2: reveal
    @State private var strokeFade: Double = 1
    @State private var revealRadius: CGFloat = 0
    @State private var showMain = false

    private var isDark: Bool { colorScheme == .dark }
    private var bgColor: Color {
        isDark ? Color(red: 0.043, green: 0.082, blue: 0.157) : .white
    }
    private var logoColor: Color {
        isDark ? Color(hex: "60A5FA") : Color(hex: "1A73E8")
    }

    var body: some View {
        // MainTabView is the ROOT — no GeometryReader wrapper
        MainTabView()
            .opacity(showMain ? 1 : 0)
            .fullScreenCover(isPresented: Binding(
                get: { showMain && !hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingView()
            }
            .overlay {
                // Splash animation as overlay on top of MainTabView
                if phase < 4 {
                    GeometryReader { geo in
                        let W = geo.size.width
                        let H = geo.size.height

                        let logoTop = H * 0.20
                        let logoBottom = H * 0.94
                        let logoHeight = logoBottom - logoTop
                        let logoWidth = logoHeight * 0.48
                        let logoCX = W / 2
                        let logoCY = (logoTop + logoBottom) / 2

                        let topDotX = logoCX + logoWidth * 0.22
                        let topDotY = logoTop
                        let bottomDotX = logoCX - logoWidth * 0.22
                        let bottomDotY = logoBottom

                        let strokeW = logoHeight * 0.055

                        ZStack {
                            // Masked bg for reveal animation
                            bgColor.ignoresSafeArea()
                                .mask(
                                    Rectangle()
                                        .ignoresSafeArea()
                                        .overlay(
                                            Circle()
                                                .frame(width: revealRadius, height: revealRadius)
                                                .position(x: topDotX, y: topDotY)
                                                .blendMode(.destinationOut)
                                        )
                                        .compositingGroup()
                                )
                                .opacity(showMain ? 1 : 0)

                            // Solid bg before reveal starts
                            if !showMain {
                                bgColor.ignoresSafeArea()
                            }

                            // S-curve stroke
                            SLogoPath()
                                .trim(from: 0, to: pathTrim)
                                .stroke(logoColor, style: StrokeStyle(
                                    lineWidth: strokeW, lineCap: .round, lineJoin: .round))
                                .frame(width: logoWidth, height: logoHeight)
                                .position(x: logoCX, y: logoCY)
                                .opacity(strokeFade)

                            // Bottom dot
                            Circle()
                                .fill(logoColor.opacity(0.35))
                                .frame(width: strokeW * 1.6, height: strokeW * 1.6)
                                .position(x: bottomDotX, y: bottomDotY)
                                .opacity(bottomDotOpacity * strokeFade)

                            // Top dot
                            Circle()
                                .fill(logoColor)
                                .frame(width: strokeW * 2.4, height: strokeW * 2.4)
                                .position(x: topDotX, y: topDotY)
                                .scaleEffect(topDotScale)
                                .shadow(color: logoColor.opacity(topDotGlow), radius: 20)
                                .opacity(strokeFade)
                        }
                        .onAppear {
                            screenSize = geo.size
                            let diag = Foundation.sqrt(W * W + H * H)
                            animate(diag: diag)
                        }
                    }
                    .ignoresSafeArea()
                    .transition(.identity)
                }
            }
            .animation(.easeInOut(duration: 0.01), value: phase >= 4)
    }

    private func animate(diag: CGFloat) {
        let fast = hasLaunchedBefore
        phase = 1

        // Bottom dot
        withAnimation(.easeOut(duration: 0.2)) { bottomDotOpacity = 1 }
        HapticEngine.shared.impact(.soft)

        // Draw S-curve — one fluid motion
        let dur: Double = fast ? 0.7 : 1.1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.timingCurve(0.25, 0.0, 0.12, 1.0, duration: dur)) {
                pathTrim = 1
            }
        }

        // Haptic at diagonal crossing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + dur * 0.45) {
            HapticEngine.shared.impact(.light)
        }

        // Top dot pops
        let dotTime = 0.1 + dur - 0.06
        DispatchQueue.main.asyncAfter(deadline: .now() + dotTime) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { topDotScale = 1 }
            withAnimation(.easeOut(duration: 0.2)) { topDotGlow = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.25)) { topDotGlow = 0 }
            }
            HapticEngine.shared.impact(.medium)
        }

        // Phase 2: fade out stroke + start reveal
        let t2 = dotTime + 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + t2) {
            phase = 2
            showMain = true
            // Fade out logo
            withAnimation(.easeOut(duration: 0.25)) { strokeFade = 0 }
            // Expand reveal circle — one smooth motion
            HapticEngine.shared.impact(.light)
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.55)) {
                revealRadius = diag * 1.6
            }
        }

        // Done
        DispatchQueue.main.asyncAfter(deadline: .now() + t2 + 0.6) {
            phase = 4
            hasLaunchedBefore = true
        }
    }
}

// MARK: - S-Logo Path
// Matches SVG icon: bottom-left → left-bulging arc → sharp diagonal → right-bulging arc → top-right
// Asymmetric: lower arc wider, upper arc tighter

struct SLogoPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Bottom-left start
        p.move(to: CGPoint(x: w * 0.28, y: h))

        // Lower arc — sweeps far left, then curves smoothly into the crossing
        p.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.50),
            control1: CGPoint(x: w * -0.30, y: h * 0.92),
            control2: CGPoint(x: w * -0.20, y: h * 0.52)
        )

        // Upper arc — continues seamlessly, sweeps far right up to top
        p.addCurve(
            to: CGPoint(x: w * 0.72, y: 0),
            control1: CGPoint(x: w * 1.20, y: h * 0.48),
            control2: CGPoint(x: w * 1.25, y: h * 0.06)
        )

        return p
    }
}

// MARK: - Previews

#Preview("Light") {
    SplashScreenView()
        .modelContainer(for: [CountdownEvent.self, UserSettings.self, DeadlineRecord.self, AIAccount.self, StudyGoal.self, CheckInRecord.self], inMemory: true)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashScreenView()
        .modelContainer(for: [CountdownEvent.self, UserSettings.self, DeadlineRecord.self, AIAccount.self, StudyGoal.self, CheckInRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
