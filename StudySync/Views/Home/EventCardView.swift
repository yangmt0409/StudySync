import SwiftUI

struct EventCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let event: CountdownEvent
    var onTogglePin: (() -> Void)?
    var onDelete: (() -> Void)?

    private var color: Color {
        let base = event.isExpired ? Color.gray : Color(hex: event.colorHex)
        return colorScheme == .dark ? base.opacity(0.85) : base
    }

    /// Primary numeric value shown on the card, respecting timeUnit and
    /// count-up/down mode.
    private var primaryCount: Int {
        event.showAsCountUp ? event.elapsedInUnit : event.remainingInUnit
    }

    /// Unit suffix / label for the numeric value ("天" / "周" / "月").
    private var unitLabel: String {
        event.timeUnit.displayName
    }

    /// Header text for the grid card (respects percentage / count-up / unit).
    private var gridHeaderValue: String {
        if event.showPercentage {
            return "\(Int(event.progress * 100))%"
        }
        return "\(primaryCount) \(unitLabel)"
    }

    var body: some View {
        Group {
            if event.themeStyle == .grid && !event.isExpired {
                gridCard
            } else {
                standardCard
            }
        }
        .shadow(color: color.opacity(0.06), radius: 8, x: 0, y: 4)
        .opacity(event.isExpired ? 0.7 : 1.0)
    }

    // MARK: - Grid Card (Pretty Progress style)

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：标题 + 天数
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(eventFont(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: event.textColorHex))
                        .lineLimit(1)

                    if event.notStarted {
                        Text(L10n.notStartedBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: event.textColorHex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: event.textColorHex).opacity(0.2))
                            )
                    }
                }

                Spacer()

                Text(gridHeaderValue)
                    .font(eventFont(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: event.textColorHex).opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Spacer(minLength: 0)

            // 全幅点阵 - 固定 20 列，底部对齐
            DotGridProgressView(
                startDate: event.startDate,
                endDate: event.endDate,
                accentColor: Color(hex: event.dotColorHex),
                dotShape: event.dotShape,
                timeUnit: event.timeUnit,
                gridColumns: 20,
                isCompact: false,
                showAsCountUp: event.showAsCountUp
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)

                // 背景图片
                if let imageData = event.backgroundImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(0.3)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Standard Card (ring/bar/minimal)

    private var standardCard: some View {
        cardContent
            .background(cardBackground)
            .overlay(cardBorder)
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            // 左侧：emoji
            Text(event.emoji)
                .font(.system(size: 36))
                .frame(width: 50, height: 50)
                .background(Circle().fill(color.opacity(0.12)))

            // 中间：标题 + 分类
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(event.isExpired ? .secondary : .primary)
                        .lineLimit(1)

                    if event.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(color)
                    }
                }

                HStack(spacing: 6) {
                    Text(event.category.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.1)))

                    if event.isExpired {
                        Text(L10n.expired)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.gray.opacity(0.5)))
                    } else if event.notStarted {
                        Text(L10n.notStartedBadge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(color.opacity(0.12)))
                            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
                    } else {
                        Text(event.endDate.formattedChinese)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 右侧：根据主题样式显示
            rightContent
        }
        .padding(14)
    }

    private func eventFont(size: CGFloat, weight: Font.Weight) -> Font {
        let opt = FontOption(rawValue: event.fontName) ?? .default
        return opt.font(size: size, weight: weight)
    }

    // MARK: - Right Content (theme-dependent)

    @ViewBuilder
    private var rightContent: some View {
        if event.isExpired {
            expiredContent
        } else {
            switch event.themeStyle {
            case .grid, .ring:
                ringContent
            case .bar:
                barContent
            case .minimal:
                minimalContent
            }
        }
    }

    private var ringContent: some View {
        VStack(spacing: 4) {
            ProgressRingView(
                progress: event.progress,
                colorHex: event.colorHex,
                lineWidth: 6,
                size: 44,
                showPercentage: false
            )
            .overlay(
                Text("\(primaryCount)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            )

            Text(event.showPercentage ? "\(Int(event.progress * 100))%" : unitLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var barContent: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(primaryCount)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * event.progress)
                }
            }
            .frame(width: 50, height: 4)

            Text(event.showPercentage ? "\(Int(event.progress * 100))%" : unitLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var minimalContent: some View {
        VStack(spacing: 2) {
            Text("\(primaryCount)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(event.showPercentage ? "\(Int(event.progress * 100))%" : unitLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // #8 Check if recently expired (within 24h)
    private var isRecentlyExpired: Bool {
        guard event.isExpired else { return false }
        let hoursSinceExpiry = Date().timeIntervalSince(event.endDate) / 3600
        return hoursSinceExpiry <= 24
    }

    private var expiredContent: some View {
        VStack(spacing: 4) {
            if isRecentlyExpired {
                // #8 Celebration indicator for recently completed
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                Text(L10n.completed)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                ProgressRingView(
                    progress: 1.0,
                    colorHex: "#9CA3AF",
                    lineWidth: 6,
                    size: 44,
                    showPercentage: false
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray)
                )
            }
        }
    }

    // MARK: - Background & Border

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.03), color.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.12), lineWidth: 1)
    }
}

#Preview {
    VStack(spacing: 12) {
        EventCardView(event: CountdownEvent(
            title: "期末考试周", emoji: "📝",
            endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
            category: .academic, colorHex: "#5B7FFF",
            themeStyle: .grid
        ))

        EventCardView(event: CountdownEvent(
            title: "签证到期", emoji: "📋",
            endDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())!,
            category: .visa, colorHex: "#FF6B6B",
            themeStyle: .bar
        ))

        EventCardView(event: CountdownEvent(
            title: "回国", emoji: "✈️",
            endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            category: .travel, colorHex: "#4ECDC4",
            themeStyle: .minimal
        ))
    }
    .padding()
}
