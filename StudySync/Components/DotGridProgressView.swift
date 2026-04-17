import SwiftUI

struct DotGridProgressView: View {
    let startDate: Date
    let endDate: Date
    var accentColor: Color = .blue
    var dotShape: DotShape = .circle
    var timeUnit: TimeUnit = .day
    var gridColumns: Int? = nil
    var isCompact: Bool = false
    var showAsCountUp: Bool = false

    @State private var hasAppeared = false

    private var totalUnits: Int {
        max(timeUnit.unitCount(from: startDate, to: endDate), 1)
    }

    private var elapsedUnits: Int {
        min(timeUnit.elapsedCount(from: startDate), totalUnits)
    }

    private var columns: Int {
        if let gridColumns { return gridColumns }
        // Auto-calculate based on total
        switch totalUnits {
        case 0...30: return 6
        case 31...90: return 10
        case 91...180: return 14
        case 181...365: return 18
        default: return 20
        }
    }

    private var dotSize: CGFloat {
        if isCompact {
            return totalUnits > 90 ? 3 : (totalUnits > 30 ? 4 : 6)
        }
        // 固定大小，不随数量缩小
        return 10
    }

    private var dotSpacing: CGFloat {
        isCompact ? 2 : (dotSize > 8 ? 4 : 3)
    }

    var body: some View {
        let gridItems = Array(
            repeating: GridItem(.flexible(), spacing: dotSpacing),
            count: columns
        )

        LazyVGrid(columns: gridItems, spacing: dotSpacing) {
            ForEach(0..<totalUnits, id: \.self) { index in
                dotView(at: index)
            }
        }
        .onAppear {
            if !hasAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    hasAppeared = true
                }
            }
        }
    }

    @ViewBuilder
    private func dotView(at index: Int) -> some View {
        let isFilled = index < elapsedUnits
        let isToday = index == elapsedUnits && !isExpired

        Group {
            switch dotShape {
            case .circle:
                Circle()
                    .aspectRatio(1, contentMode: .fit)
            case .square:
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .aspectRatio(1, contentMode: .fit)
            case .diamond:
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .aspectRatio(1, contentMode: .fit)
                    .rotationEffect(.degrees(45))
                    .padding(1)
            case .heart:
                HeartShape()
                    .aspectRatio(1, contentMode: .fit)
            case .star:
                StarShape()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .foregroundStyle(dotColor(isFilled: isFilled, isToday: isToday))
        .overlay {
            if isToday && !isCompact {
                Circle()
                    .stroke(.white.opacity(0.8), lineWidth: 1)
                    .padding(-1)
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.5)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            .easeOut(duration: 0.3).delay(animationDelay(for: index)),
            value: hasAppeared
        )
    }

    private func dotColor(isFilled: Bool, isToday: Bool) -> Color {
        if isToday {
            return accentColor
        }
        return isFilled ? accentColor : accentColor.opacity(0.2)
    }

    private func animationDelay(for index: Int) -> Double {
        if isCompact { return 0 }
        let maxDelay: Double = 0.6
        return Double(index) / Double(max(totalUnits, 1)) * maxDelay
    }

    private var isExpired: Bool {
        Date() > endDate
    }
}

// MARK: - Compact version for cards and widgets

struct MiniDotGridView: View {
    let progress: Double
    let totalDots: Int
    var accentColor: Color = .blue
    var dotShape: DotShape = .circle
    var columns: Int = 10

    private var filledDots: Int {
        Int(Double(totalDots) * progress)
    }

    private var dotSize: CGFloat {
        totalDots > 50 ? 3 : 4
    }

    var body: some View {
        let gridItems = Array(
            repeating: GridItem(.fixed(dotSize), spacing: 2),
            count: columns
        )

        LazyVGrid(columns: gridItems, spacing: 2) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundStyle(
                        index < filledDots ? accentColor : accentColor.opacity(0.12)
                    )
            }
        }
    }
}

#Preview("30 days") {
    DotGridProgressView(
        startDate: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
        endDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())!,
        accentColor: Color(hex: "#5B7FFF"),
        dotShape: .circle
    )
    .padding()
}

#Preview("365 days") {
    DotGridProgressView(
        startDate: Calendar.current.date(byAdding: .day, value: -200, to: Date())!,
        endDate: Calendar.current.date(byAdding: .day, value: 165, to: Date())!,
        accentColor: Color(hex: "#FF6B6B"),
        dotShape: .square
    )
    .padding()
}
