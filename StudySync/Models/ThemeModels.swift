import Foundation
import SwiftUI

// MARK: - Dot Shape

enum DotShape: String, Codable, CaseIterable, Identifiable {
    case circle = "圆形"
    case square = "方形"
    case diamond = "菱形"
    case heart = "爱心"
    case star = "星星"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circle: return L10n.dotCircle
        case .square: return L10n.dotSquare
        case .diamond: return L10n.dotDiamond
        case .heart: return L10n.dotHeart
        case .star: return L10n.dotStar
        }
    }

    var icon: String {
        switch self {
        case .circle: return "circle.fill"
        case .square: return "square.fill"
        case .diamond: return "diamond.fill"
        case .heart: return "heart.fill"
        case .star: return "star.fill"
        }
    }

    @ViewBuilder
    func shape(size: CGFloat) -> some View {
        switch self {
        case .circle:
            Circle().frame(width: size, height: size)
        case .square:
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .frame(width: size, height: size)
        case .diamond:
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))
        case .heart:
            HeartShape()
                .frame(width: size, height: size)
        case .star:
            StarShape()
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Heart Shape

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.85))
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.3),
            control1: CGPoint(x: w * 0.1, y: h * 0.7),
            control2: CGPoint(x: 0, y: h * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.2),
            control1: CGPoint(x: 0, y: h * 0.05),
            control2: CGPoint(x: w * 0.35, y: h * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.3),
            control1: CGPoint(x: w * 0.65, y: h * 0.1),
            control2: CGPoint(x: w, y: h * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.85),
            control1: CGPoint(x: w, y: h * 0.5),
            control2: CGPoint(x: w * 0.9, y: h * 0.7)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Star Shape

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        var path = Path()

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Time Unit

enum TimeUnit: String, Codable, CaseIterable, Identifiable {
    case day = "天"
    case week = "周"
    case month = "月"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return L10n.unitDay
        case .week: return L10n.unitWeek
        case .month: return L10n.unitMonth
        }
    }

    func unitCount(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        switch self {
        case .day:
            return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 1)
        case .week:
            return max(calendar.dateComponents([.weekOfYear], from: start, to: end).weekOfYear ?? 0, 1)
        case .month:
            return max(calendar.dateComponents([.month], from: start, to: end).month ?? 0, 1)
        }
    }

    func elapsedCount(from start: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .day:
            return max(calendar.dateComponents([.day], from: start, to: now).day ?? 0, 0)
        case .week:
            return max(calendar.dateComponents([.weekOfYear], from: start, to: now).weekOfYear ?? 0, 0)
        case .month:
            return max(calendar.dateComponents([.month], from: start, to: now).month ?? 0, 0)
        }
    }
}

// MARK: - Theme Style

enum ThemeStyle: String, Codable, CaseIterable, Identifiable {
    case grid = "点阵"
    case ring = "进度环"
    case bar = "进度条"
    case minimal = "极简"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid: return L10n.themeGrid
        case .ring: return L10n.themeRing
        case .bar: return L10n.themeBar
        case .minimal: return L10n.themeMinimal
        }
    }

    var icon: String {
        switch self {
        case .grid: return "circle.grid.3x3.fill"
        case .ring: return "circle.dotted"
        case .bar: return "chart.bar.fill"
        case .minimal: return "textformat.size"
        }
    }
}
