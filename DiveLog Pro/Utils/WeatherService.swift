import Foundation
import WeatherKit
import CoreLocation
import os

/// Wrapper around WeatherKit that returns our internal weather codes
/// matching the values used in `Dive.weather` ("sunny", "partly_cloudy", ...).
/// Renamed to `DiveWeatherService` to avoid a name clash with
/// `WeatherKit.WeatherService`.
actor DiveWeatherService {
    static let shared = DiveWeatherService()
    private let kit = WeatherKit.WeatherService.shared
    private let log = Logger(subsystem: "com.weckherlin.DiveLogPro", category: "weather")

    struct Snapshot: Sendable {
        let condition: String     // maps directly to Dive.weather
        let airTempC: Double
        let windSpeedKmh: Double
    }

    enum WeatherError: LocalizedError {
        case tooOld
        case notAvailable
        case networkFailed(underlying: String)

        var errorDescription: String? {
            switch self {
            case .tooOld:                  return "Weather only available within the last year."
            case .notAvailable:            return "No weather data for this location and date."
            case .networkFailed(let msg):  return "Weather service unreachable: \(msg)"
            }
        }
    }

    /// Fetches weather for a location + date. Historical limit: ~1 year back.
    func fetch(lat: Double, lon: Double, date: Date) async throws -> Snapshot {
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
        guard date > oneYearAgo else { throw WeatherError.tooOld }

        let location = CLLocation(latitude: lat, longitude: lon)
        let isNearNow = abs(date.timeIntervalSince(Date())) < 3600

        do {
            if isNearNow {
                let current = try await kit.weather(for: location, including: .current)
                return Snapshot(
                    condition: Self.map(current.condition),
                    airTempC: current.temperature.converted(to: .celsius).value,
                    windSpeedKmh: current.wind.speed.converted(to: .kilometersPerHour).value
                )
            } else {
                // Hourly window ±30min around the target date
                let hourly = try await kit.weather(
                    for: location,
                    including: .hourly(
                        startDate: date.addingTimeInterval(-1800),
                        endDate: date.addingTimeInterval(1800)
                    )
                )
                guard let closest = hourly.forecast.min(by: {
                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                }) else { throw WeatherError.notAvailable }

                return Snapshot(
                    condition: Self.map(closest.condition),
                    airTempC: closest.temperature.converted(to: .celsius).value,
                    windSpeedKmh: closest.wind.speed.converted(to: .kilometersPerHour).value
                )
            }
        } catch let err as WeatherError {
            throw err
        } catch {
            // Log full underlying NSError details to Xcode console so we can
            // distinguish real network failure from "WeatherKit capability
            // missing on AppID" / "simulator auth error" / rate-limited.
            let ns = error as NSError
            log.error("WeatherKit failed: domain=\(ns.domain, privacy: .public) code=\(ns.code) desc=\(ns.localizedDescription, privacy: .public) userInfo=\(String(describing: ns.userInfo), privacy: .public)")
            let summary = "\(ns.domain) \(ns.code) — \(ns.localizedDescription)"
            throw WeatherError.networkFailed(underlying: summary)
        }
    }

    /// Maps WeatherKit's `WeatherCondition` enum to our internal string codes.
    private static func map(_ c: WeatherCondition) -> String {
        switch c {
        case .clear, .mostlyClear, .hot:
            return "sunny"
        case .partlyCloudy:
            return "partly_cloudy"
        case .cloudy, .mostlyCloudy, .smoky, .haze:
            return "cloudy"
        case .drizzle, .rain, .heavyRain, .sunShowers,
             .isolatedThunderstorms, .scatteredThunderstorms,
             .strongStorms, .thunderstorms,
             .freezingDrizzle, .freezingRain, .hail:
            return "rainy"
        case .breezy, .windy, .tropicalStorm, .hurricane,
             .blowingDust, .blowingSnow:
            return "windy"
        case .foggy:
            return "foggy"
        default:
            return "cloudy"
        }
    }
}
