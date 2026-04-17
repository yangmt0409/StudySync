import SwiftUI
import SwiftData
import Combine

struct ToolsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var settingsArray: [UserSettings]
    @State private var currentTime = Date()
    var service = ExchangeRateService.shared

    @State private var selectedPair: CurrencyPair = CurrencyPair.popular[0]
    @State private var inputAmount: String = "100"
    @State private var isReversed = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var settings: UserSettings? { settingsArray.first }

    private var homeTimeZone: TimeZone {
        settings?.homeTimeZone ?? TimeZone(identifier: "Asia/Shanghai")!
    }

    private var studyTimeZone: TimeZone {
        settings?.studyTimeZone ?? TimeZone(identifier: "America/Toronto")!
    }

    private var currentRate: Double {
        service.rate(for: selectedPair) ?? 0
    }

    private var convertedAmount: Double {
        let amount = Double(inputAmount) ?? 0
        return service.convert(amount: amount, pair: selectedPair, reversed: isReversed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 双时钟 - 左右并排
                    dualClockSection

                    // 分隔
                    sectionHeader(L10n.exchangeRate)

                    // 汇率卡片
                    rateCard

                    // 计算器
                    calculatorCard

                    // 快捷金额
                    quickAmounts

                    // 货币对列表
                    currencyPairSelector

                    // 状态
                    statusBar
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.md)
            }
            .background {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.tools)
            .navigationBarTitleDisplayMode(.large)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .task {
                await service.fetchRates()
            }
            .refreshable {
                await service.fetchRates()
            }
        }
    }

    // MARK: - Dual Clock Section

    private var dualClockSection: some View {
        HStack(spacing: 12) {
            CompactClockCard(
                icon: "house.fill",
                label: settings?.homeCityName ?? L10n.defaultHomeCity,
                time: currentTime,
                timeZone: homeTimeZone,
                accentColorHex: "#FF6B6B"
            )

            CompactClockCard(
                icon: "mappin.circle.fill",
                label: settings?.studyCityName ?? L10n.defaultStudyCity,
                time: currentTime,
                timeZone: studyTimeZone,
                accentColorHex: "#5B7FFF"
            )
        }
    }

    private var timeDifferenceBadge: some View {
        let homeOffset = homeTimeZone.secondsFromGMT(for: currentTime)
        let studyOffset = studyTimeZone.secondsFromGMT(for: currentTime)
        let diffHours = (homeOffset - studyOffset) / 3600

        return Text(L10n.timeDifference(abs(diffHours)))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, SSSpacing.xs)
            .background(
                Capsule()
                    .fill(SSColor.fillTertiary)
            )
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(SSFont.heading2)
            Spacer()
        }
        .padding(.top, SSSpacing.md)
    }

    // MARK: - Rate Card

    private var rateCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(selectedPair.fromFlag) \(selectedPair.from)")
                    .font(SSFont.heading3)

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(selectedPair.toFlag) \(selectedPair.to)")
                    .font(SSFont.heading3)
            }

            Text(String(format: "1 %@ = %.4f %@",
                         selectedPair.from, currentRate, selectedPair.to))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SSColor.brand)
        }
        .padding(SSSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Calculator

    private var calculatorCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(isReversed ? selectedPair.toFlag : selectedPair.fromFlag)
                    .font(.system(size: 24))

                TextField("0", text: $inputAmount)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)

                Text(isReversed ? selectedPair.to : selectedPair.from)
                    .font(SSFont.bodyMedium)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isReversed.toggle()
                }
                HapticEngine.shared.selection()
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(SSColor.brand)
                    .rotationEffect(.degrees(isReversed ? 180 : 0))
            }

            HStack {
                Text(isReversed ? selectedPair.fromFlag : selectedPair.toFlag)
                    .font(.system(size: 24))

                Spacer()

                Text(String(format: "%.2f", convertedAmount))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SSColor.travel)

                Text(isReversed ? selectedPair.from : selectedPair.to)
                    .font(SSFont.bodyMedium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SSSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(.background)
        )
    }

    // MARK: - Quick Amounts

    private var quickAmounts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach([100, 500, 1000, 5000, 10000], id: \.self) { amount in
                    Button {
                        inputAmount = "\(amount)"
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Text("\(amount)")
                            .font(SSFont.chipLabel)
                            .foregroundStyle(inputAmount == "\(amount)" ? .white : .primary)
                            .padding(.horizontal, SSSpacing.xl)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(inputAmount == "\(amount)"
                                          ? SSColor.brand : SSColor.fillTertiary)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Currency Pair Selector

    private var currencyPairSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.currencyPair)
                .font(SSFont.chipLabel)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(CurrencyPair.popular.enumerated()), id: \.element.id) { index, pair in
                    Button {
                        selectedPair = pair
                        HapticEngine.shared.selection()
                    } label: {
                        HStack(spacing: 10) {
                            Text(pair.fromFlag)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.from)
                                    .font(SSFont.bodySmallSemibold)
                                    .foregroundStyle(.primary)
                                Text(pair.fromName)
                                    .font(SSFont.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let rate = service.rate(for: pair) {
                                Text(String(format: "%.4f", rate))
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }

                            if selectedPair.id == pair.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(SSFont.body)
                                    .foregroundStyle(SSColor.brand)
                            }
                        }
                        .padding(.vertical, SSSpacing.lg)
                        .padding(.horizontal, SSSpacing.xl)
                    }

                    if index < CurrencyPair.popular.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
            )
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack {
            if service.isOffline {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.orange)
                Text(L10n.offlineData)
                    .font(SSFont.footnote)
                    .foregroundStyle(.orange)
            }

            Spacer()

            if let date = service.lastUpdated {
                Text(L10n.updatedAt + date.formattedTime(in: .current))
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, SSSpacing.xl)
    }
}

// MARK: - Compact Clock Card

struct CompactClockCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let label: String
    let time: Date
    let timeZone: TimeZone
    let accentColorHex: String

    private var color: Color { Color(hex: accentColorHex) }

    private var timeComponents: (hour: Int, minute: Int, second: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute, .second], from: time)
        return (comps.hour ?? 0, comps.minute ?? 0, comps.second ?? 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // 标签
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(SSFont.footnote)
                    .foregroundStyle(color)

                Text(label)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 时间
            Text(String(format: "%02d:%02d", timeComponents.hour, timeComponents.minute))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: timeComponents.minute)

            // 日期
            Text(time.formattedDate(in: timeZone))
                .font(SSFont.micro)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SSSpacing.xl)
        .padding(.horizontal, SSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(colorScheme == .dark ? 0.05 : 0.03),
                            color.opacity(colorScheme == .dark ? 0.1 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .stroke(color.opacity(colorScheme == .dark ? 0.2 : 0.12), lineWidth: 1)
        )
    }
}

#Preview {
    ToolsView()
        .modelContainer(for: [CountdownEvent.self, UserSettings.self], inMemory: true)
}
