import Foundation
import SwiftUI

// MARK: - Currency Pair

struct CurrencyPair: Identifiable, Hashable {
    var id: String { "\(from)\(to)" }
    let from: String
    let to: String
    let fromFlag: String
    let toFlag: String
    let fromName: String
    let toName: String

    static let popular: [CurrencyPair] = [
        CurrencyPair(from: "CAD", to: "CNY", fromFlag: "🇨🇦", toFlag: "🇨🇳", fromName: "加元", toName: "人民币"),
        CurrencyPair(from: "USD", to: "CNY", fromFlag: "🇺🇸", toFlag: "🇨🇳", fromName: "美元", toName: "人民币"),
        CurrencyPair(from: "AUD", to: "CNY", fromFlag: "🇦🇺", toFlag: "🇨🇳", fromName: "澳元", toName: "人民币"),
        CurrencyPair(from: "GBP", to: "CNY", fromFlag: "🇬🇧", toFlag: "🇨🇳", fromName: "英镑", toName: "人民币"),
        CurrencyPair(from: "EUR", to: "CNY", fromFlag: "🇪🇺", toFlag: "🇨🇳", fromName: "欧元", toName: "人民币"),
        CurrencyPair(from: "JPY", to: "CNY", fromFlag: "🇯🇵", toFlag: "🇨🇳", fromName: "日元", toName: "人民币"),
        CurrencyPair(from: "HKD", to: "CNY", fromFlag: "🇭🇰", toFlag: "🇨🇳", fromName: "港币", toName: "人民币"),
        CurrencyPair(from: "MOP", to: "CNY", fromFlag: "🇲🇴", toFlag: "🇨🇳", fromName: "澳门币", toName: "人民币"),
    ]
}

// MARK: - Exchange Rate Service

@Observable
final class ExchangeRateService {
    static let shared = ExchangeRateService()

    /// Rates stored as X → CNY (e.g. "CAD": 5.12 means 1 CAD = 5.12 CNY)
    var rates: [String: Double] = [:]
    var isLoading = false
    var isOffline = false
    var lastUpdated: Date?
    var error: String?

    private let cacheKey = "cached_exchange_rates_v5"
    private let cacheTimestampKey = "cached_rates_timestamp_v5"

    private init() {
        loadCache()
    }

    // MARK: - Fetch Rates (frankfurter.app — ECB data)

    @MainActor
    func fetchRates() async {
        isLoading = true
        error = nil

        // Frankfurter uses EUR as default base.
        // We fetch EUR → all target currencies, then compute cross rates to CNY.
        let currencies = ["CNY", "CAD", "USD", "AUD", "GBP", "JPY", "HKD"]
        let symbolsParam = currencies.joined(separator: ",")

        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=EUR&symbols=\(symbolsParam)") else {
            isLoading = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Fallback to backup API
                await fetchRatesFromBackup()
                return
            }

            struct FrankfurterResponse: Codable {
                let base: String
                let date: String
                let rates: [String: Double]
            }

            let result = try JSONDecoder().decode(FrankfurterResponse.self, from: data)

            guard let eurToCny = result.rates["CNY"], eurToCny > 0 else {
                await fetchRatesFromBackup()
                return
            }

            var convertedRates: [String: Double] = [:]

            // EUR → CNY is directly available
            convertedRates["EUR"] = eurToCny

            // For other currencies X:
            // EUR → X (from API)
            // EUR → CNY (from API)
            // X → CNY = EUR→CNY / EUR→X
            for currency in ["CAD", "USD", "AUD", "GBP", "JPY", "HKD"] {
                if let eurToX = result.rates[currency], eurToX > 0 {
                    convertedRates[currency] = eurToCny / eurToX
                }
            }

            // MOP is pegged to HKD at ~1.03 (not in ECB data)
            if let hkdRate = convertedRates["HKD"] {
                convertedRates["MOP"] = hkdRate / 1.03
            }

            rates = convertedRates
            lastUpdated = Date()
            isOffline = false
            saveCache()
        } catch {
            // Network error — try backup
            await fetchRatesFromBackup()
        }

        isLoading = false
    }

    // MARK: - Backup API (open.er-api.com)

    @MainActor
    private func fetchRatesFromBackup() async {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            applyOfflineState()
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)

            struct APIResponse: Codable {
                let result: String
                let rates: [String: Double]
            }

            let response = try JSONDecoder().decode(APIResponse.self, from: data)

            if response.result == "success",
               let usdToCny = response.rates["CNY"], usdToCny > 0 {

                var convertedRates: [String: Double] = [:]
                let currencies = ["CAD", "USD", "AUD", "GBP", "EUR", "JPY", "HKD", "MOP"]

                for currency in currencies {
                    if currency == "USD" {
                        convertedRates["USD"] = usdToCny
                    } else if let usdToX = response.rates[currency], usdToX > 0 {
                        convertedRates[currency] = usdToCny / usdToX
                    }
                }

                rates = convertedRates
                lastUpdated = Date()
                isOffline = false
                saveCache()
            } else {
                applyOfflineState()
            }
        } catch {
            applyOfflineState()
        }
    }

    private func applyOfflineState() {
        self.error = L10n.networkError
        isOffline = true
        isLoading = false
    }

    // MARK: - Get Rate

    func rate(for pair: CurrencyPair) -> Double? {
        return rates[pair.from]
    }

    func convert(amount: Double, pair: CurrencyPair, reversed: Bool) -> Double {
        guard let r = rate(for: pair), r > 0 else { return 0 }
        return reversed ? amount / r : amount * r
    }

    // MARK: - Cache

    private func saveCache() {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        }
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([String: Double].self, from: data) {
            rates = cached
            let ts = UserDefaults.standard.double(forKey: cacheTimestampKey)
            if ts > 0 {
                lastUpdated = Date(timeIntervalSince1970: ts)
            }
            isOffline = true
        }
    }
}
