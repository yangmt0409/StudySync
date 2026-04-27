import SwiftUI

struct ExchangeRateView: View {
    var service = ExchangeRateService.shared

    @State private var selectedPair: CurrencyPair = CurrencyPair.popular[0]
    @State private var inputAmount: String = "100"
    @State private var isReversed = false

    private var currentRate: Double {
        service.rate(for: selectedPair) ?? 0
    }

    private var convertedAmount: Double {
        let amount = Double(inputAmount) ?? 0
        return service.convert(amount: amount, pair: selectedPair, reversed: isReversed)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                rateCard
                calculatorCard
                quickAmounts
                currencyPairSelector
                statusBar
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
        .dismissKeyboardToolbar()
        .task {
            await service.fetchRates()
        }
        .refreshable {
            await service.fetchRates()
        }
    }

    // MARK: - Rate Card

    private var rateCard: some View {
        VStack(spacing: SSSpacing.lg) {
            HStack {
                Text("\(selectedPair.fromFlag) \(selectedPair.from)")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(selectedPair.toFlag) \(selectedPair.to)")
                    .font(.system(size: 18, weight: .semibold))
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
        VStack(spacing: SSSpacing.xl) {
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
            HStack(spacing: SSSpacing.mdLg) {
                ForEach([100, 500, 1000, 5000, 10000], id: \.self) { amount in
                    Button {
                        inputAmount = "\(amount)"
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Text("\(amount)")
                            .font(SSFont.chipLabel)
                            .foregroundStyle(inputAmount == "\(amount)" ? .white : .primary)
                            .padding(.horizontal, SSSpacing.xl)
                            .padding(.vertical, SSSpacing.md)
                            .background(
                                Capsule()
                                    .fill(inputAmount == "\(amount)"
                                          ? SSColor.brand : Color(.tertiarySystemFill))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Currency Pair Selector

    private var currencyPairSelector: some View {
        VStack(alignment: .leading, spacing: SSSpacing.mdLg) {
            Text(L10n.currencyPair)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(CurrencyPair.popular.enumerated()), id: \.element.id) { index, pair in
                    Button {
                        selectedPair = pair
                        HapticEngine.shared.selection()
                    } label: {
                        HStack(spacing: SSSpacing.mdLg) {
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
                                    .font(.system(size: 16))
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
                RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
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
                Text(L10n.updatedAt + date.formatted(date: .abbreviated, time: .shortened))
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, SSSpacing.xs)
        .padding(.bottom, SSSpacing.xl)
    }
}

#Preview {
    NavigationStack {
        ExchangeRateView()
            .navigationTitle("汇率")
    }
}
