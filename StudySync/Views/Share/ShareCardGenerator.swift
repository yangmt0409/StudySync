import SwiftUI

enum ShareCardTemplate: String, CaseIterable, Identifiable {
    case minimal = "极简"
    case dotGrid = "点阵"
    case card = "卡片"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal: return L10n.templateMinimal
        case .dotGrid: return L10n.templateDotGrid
        case .card: return L10n.templateCard
        }
    }
}

enum ShareCardSize: String, CaseIterable {
    case square = "1:1"
    case portrait = "9:16"

    var dimensions: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        }
    }
}

// MARK: - Card Generator

struct ShareCardGenerator {
    @MainActor
    static func render(event: CountdownEvent, template: ShareCardTemplate, size: ShareCardSize, showWatermark: Bool) -> UIImage? {
        let view = ShareCardContent(
            event: event,
            template: template,
            cardSize: size,
            showWatermark: showWatermark
        )
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - Card Content View

struct ShareCardContent: View {
    let event: CountdownEvent
    let template: ShareCardTemplate
    let cardSize: ShareCardSize
    let showWatermark: Bool

    private var color: Color { Color(hex: event.colorHex) }
    private var darkerColor: Color { Color(hex: event.colorHex).opacity(0.85) }

    private var daysValue: Int {
        event.primaryCount
    }

    private var daysLabel: String {
        event.showAsCountUp ? L10n.unitPassed(event.unitLabel) : L10n.unitLeft(event.unitLabel)
    }

    private var progressPercent: Int {
        Int(event.progress * 100)
    }

    var body: some View {
        ZStack {
            switch template {
            case .minimal:
                minimalTemplate
            case .dotGrid:
                dotGridTemplate
            case .card:
                cardTemplate
            }
        }
    }

    // MARK: - Template A: Minimal — Big number, clean and bold

    private var minimalTemplate: some View {
        ZStack {
            LinearGradient(
                colors: [color, darkerColor, color.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle pattern
            Circle()
                .fill(.white.opacity(0.03))
                .frame(width: 800, height: 800)
                .offset(x: 300, y: -200)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 600, height: 600)
                .offset(x: -250, y: 300)

            VStack(spacing: 0) {
                Spacer()

                // Big number
                Text("\(daysValue)")
                    .font(.system(size: 220, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)

                // Label
                Text(daysLabel.uppercased())
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 48)

                // Divider line
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 140, height: 2)
                    .padding(.bottom, 48)

                // Title
                Text(event.title)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                // Progress
                Text(L10n.sharePercentComplete(progressPercent))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 20)

                Spacer()

                if showWatermark {
                    watermark(light: true)
                        .padding(.bottom, 60)
                }
            }
        }
    }

    // MARK: - Template B: Dot Grid — Visual progress focus

    private var dotGridTemplate: some View {
        let total = min(event.totalDays, 200)
        let filled = Int(Double(total) * event.progress)

        // Adaptive columns: fewer dots = fewer columns = bigger dots
        let cols: Int = {
            switch total {
            case 0...30: return 6
            case 31...60: return 8
            case 61...100: return 10
            default: return 12
            }
        }()

        let dotSpacing: CGFloat = total <= 60 ? 14 : 10
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: dotSpacing), count: cols)

        return ZStack {
            // Background gradient
            LinearGradient(
                colors: [color, color.opacity(0.85), Color(hex: "#1a1a2e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Title
                Text(event.title)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .padding(.top, cardSize == .portrait ? 120 : 60)

                // Stats row
                HStack(spacing: 40) {
                    // Days
                    VStack(spacing: 6) {
                        Text("\(daysValue)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text((event.showAsCountUp ? L10n.unitPassed(event.unitLabel) : L10n.unitLeft(event.unitLabel)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 1.5, height: 60)

                    // Percentage
                    VStack(spacing: 6) {
                        Text("\(progressPercent)%")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L10n.shareComplete)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 36)

                // Dot grid — constrained to available space
                GeometryReader { geo in
                    let availableWidth = geo.size.width - 96 // 48 padding each side
                    let totalSpacingW = dotSpacing * CGFloat(cols - 1)
                    let dotSize = (availableWidth - totalSpacingW) / CGFloat(cols)
                    let rows = Int(ceil(Double(total) / Double(cols)))
                    let totalSpacingH = dotSpacing * CGFloat(max(rows - 1, 0))
                    let neededHeight = dotSize * CGFloat(rows) + totalSpacingH
                    let scale = neededHeight > geo.size.height ? geo.size.height / neededHeight : 1.0

                    LazyVGrid(columns: gridItems, spacing: dotSpacing * scale) {
                        ForEach(0..<total, id: \.self) { i in
                            Circle()
                                .frame(width: dotSize * scale, height: dotSize * scale)
                                .foregroundStyle(i < filled ? .white : .white.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 48)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }

                Spacer(minLength: 8).frame(maxHeight: 20)

                // Progress bar
                progressBar
                    .padding(.horizontal, 48)
                    .padding(.bottom, showWatermark ? 20 : 48)

                if showWatermark {
                    watermark(light: true)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Template C: Card — Floating card with ring

    private var cardTemplate: some View {
        ZStack {
            // Soft background
            LinearGradient(
                colors: [color.opacity(0.15), color.opacity(0.05), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative blobs
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 500, height: 500)
                .offset(x: -200, y: -300)

            Circle()
                .fill(color.opacity(0.06))
                .frame(width: 400, height: 400)
                .offset(x: 250, y: 200)

            VStack(spacing: 0) {
                Spacer()

                // Floating card
                VStack(spacing: 48) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.black.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.12), lineWidth: 22)

                        Circle()
                            .trim(from: 0, to: max(event.progress, 0.01))
                            .stroke(
                                color,
                                style: StrokeStyle(lineWidth: 22, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 10) {
                            Text("\(daysValue)")
                                .font(.system(size: 88, weight: .bold, design: .rounded))
                                .foregroundStyle(color)

                            Text(event.showAsCountUp ? L10n.unitPassed(event.unitLabel) : L10n.unitLeft(event.unitLabel))
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 360, height: 360)

                    // Progress text
                    Text(L10n.sharePercentComplete(progressPercent))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundColor(color)

                    // Date range
                    Text("\(event.startDate.formattedShort) → \(event.endDate.formattedShort)")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.vertical, 72)
                .padding(.horizontal, 48)
                .background(
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: color.opacity(0.15), radius: 40, x: 0, y: 20)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 32)

                Spacer()

                if showWatermark {
                    watermark(light: false)
                        .padding(.bottom, 60)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func statColumn(value: String, label: String, valueSize: CGFloat = 28) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: valueSize * 0.43, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.15))
                .frame(height: 10)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.9))
                    .frame(width: max(geo.size.width * event.progress, 8), height: 10)
            }
            .frame(height: 10)
        }
    }

    private func watermark(light: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 16))
            Text("StudySync")
                .font(.system(size: 18, weight: .medium))
        }
        .foregroundStyle(light ? .white.opacity(0.3) : .gray.opacity(0.3))
    }

}
