import Foundation
import CoreLocation

/// Lightweight weather service backed by Open-Meteo (free, no API key).
/// Fetches current temperature + weather code for a given coordinate.
///
/// Response is cached in-memory for 15 minutes per rounded coordinate, so
/// revisiting the same event detail screen does not re-hit the network.
@Observable
final class WeatherService {
    static let shared = WeatherService()

    struct Current: Equatable {
        let temperatureC: Double
        let code: Int
        let isDay: Bool

        var symbolName: String {
            // Open-Meteo WMO weather codes → SF Symbols
            switch code {
            case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
            case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
            case 3: return "cloud.fill"
            case 45, 48: return "cloud.fog.fill"
            case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
            case 61, 63, 65, 66, 67: return "cloud.rain.fill"
            case 71, 73, 75, 77: return "cloud.snow.fill"
            case 80, 81, 82: return "cloud.heavyrain.fill"
            case 85, 86: return "cloud.snow.fill"
            case 95: return "cloud.bolt.fill"
            case 96, 99: return "cloud.bolt.rain.fill"
            default: return "cloud.fill"
            }
        }

        /// Rounded integer with degree symbol, e.g. "23°".
        var temperatureLabel: String {
            "\(Int(temperatureC.rounded()))°"
        }
    }

    private struct CacheEntry {
        let current: Current
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 15 * 60

    private init() {}

    /// Fetch current weather for coordinate. Returns nil on failure.
    func current(for coordinate: CLLocationCoordinate2D) async -> Current? {
        let key = Self.cacheKey(for: coordinate)

        if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return entry.current
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let current = Current(
                temperatureC: decoded.current.temperature_2m,
                code: decoded.current.weather_code,
                isDay: decoded.current.is_day == 1
            )
            cache[key] = CacheEntry(current: current, fetchedAt: Date())
            return current
        } catch {
            return nil
        }
    }

    private static func cacheKey(for coord: CLLocationCoordinate2D) -> String {
        // Round to ~1 km so small map jitter reuses the cache.
        let lat = (coord.latitude * 100).rounded() / 100
        let lon = (coord.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }
}

// MARK: - Open-Meteo DTO

private struct OpenMeteoResponse: Decodable {
    struct CurrentBlock: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }
    let current: CurrentBlock
}
