import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let colorHex: String
    var lineWidth: CGFloat = 8
    var size: CGFloat = 56
    var showPercentage: Bool = true

    @State private var animatedProgress: Double = 0

    private var color: Color {
        Color(hex: colorHex)
    }

    var body: some View {
        ZStack {
            // 背景环
            Circle()
                .stroke(
                    Color(.systemGray5),
                    lineWidth: lineWidth
                )

            // 进度环
            Circle()
                .trim(from: 0, to: CGFloat(min(animatedProgress, 1.0)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.5),
                            color,
                            color.opacity(0.8),
                            color
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // 百分比文字
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = newValue
            }
        }
        // #13 Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.progressLabel)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRingView(progress: 0.3, colorHex: "#5B7FFF")
        ProgressRingView(progress: 0.65, colorHex: "#FF6B6B")
        ProgressRingView(progress: 0.9, colorHex: "#4ECDC4")
    }
    .padding()
}
