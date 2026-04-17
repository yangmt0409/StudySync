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
            VStack(spacing: 16) {
                rateCard
                calculatorCard
                quickAmounts
                currencyPairSelector
                statusBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
        .task {
            await service.fetchRates()
        }
        .refreshable {
            await service.fetchRates()
        }
    }

    // MARK: - Rate Card

    private var rateCard: some View {
        VStack(spacing: 12) {
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
                .foregroundStyle(Color(hex: "#5B7FFF"))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                    .font(.system(size: 16, weight: .medium))
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
                    .foregroundStyle(Color(hex: "#5B7FFF"))
                    .rotationEffect(.degrees(isReversed ? 180 : 0))
            }

            HStack {
                Text(isReversed ? selectedPair.fromFlag : selectedPair.toFlag)
                    .font(.system(size: 24))

                Spacer()

                Text(String(format: "%.2f", convertedAmount))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#4ECDC4"))

                Text(isReversed ? selectedPair.from : selectedPair.to)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(inputAmount == "\(amount)" ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(inputAmount == "\(amount)"
                                          ? Color(hex: "#5B7FFF") : Color(.tertiarySystemFill))
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
                .font(.system(size: 14, weight: .semibold))
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
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(pair.fromName)
                                    .font(.system(size: 12))
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
                                    .foregroundStyle(Color(hex: "#5B7FFF"))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
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
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            Spacer()

            if let date = service.lastUpdated {
                Text(L10n.updatedAt + date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 16)
    }
}

#Preview {
    NavigationStack {
        ExchangeRateView()
            .navigationTitle("汇率")
    }
}
