import Foundation
import SwiftUI
import OSLog

/// Single-day forecast bundle. The mini summary the agenda needs:
/// high/low temperature in °C plus the SF Symbol that represents the day's
/// overall condition.
struct DailyForecast: Hashable, Sendable {
  /// Date the forecast represents (start of day in the local calendar).
  let date: Date
  /// Forecasted high in °C.
  let highC: Double
  /// Forecasted low in °C.
  let lowC: Double
  /// SF Symbol name for the condition (e.g., "sun.max.fill", "cloud.sun.fill").
  let symbolName: String

  /// Convenience: format temperature pair as "23°/9°".
  func tempLabel() -> String {
    let hi = Int(highC.rounded())
    let lo = Int(lowC.rounded())
    return "\(hi)°/\(lo)°"
  }
}

/// Observable store for daily weather forecasts.
///
/// Backed by **Open-Meteo** — a free public weather API that doesn't require
/// an account, token, or Apple-Developer entitlement. Trade-off vs. WeatherKit:
/// no Apple-native hourly data, no severe-weather alerts, but covers our
/// "daily high/low + condition icon" need perfectly and works on any device
/// out of the box.
///
/// **History note:** we tried WeatherKit twice (20./21. May 2026) but ran
/// into persistent `WDSJWTAuthenticatorServiceListener.Errors Code=2` even
/// after enabling WeatherKit on the App ID in the Apple Developer portal.
/// The JWT-token issuer apparently caches longer than Apple documents, and
/// the manual-provisioning-profile reset dance was a frustrating dead end.
/// If you want to retry WeatherKit later, the previous implementation
/// lives in git history (commit before this rollback). Until then,
/// Open-Meteo is the pragmatic choice.
///
/// Forecast covers ~14 days; the API returns ISO date strings that we map
/// to the user's calendar with `Calendar.current.startOfDay(for:)`.
///
/// **Status:** location is hardcoded to Zürich (47.3769, 8.5417). The next
/// iteration should switch to user-configurable location (settings) and/or
/// optional CoreLocation-current-position with permission prompt.
@MainActor
@Observable
final class WeatherStore {
  /// Forecast map keyed by `Calendar.current.startOfDay(for:)`.
  private(set) var dailyByDate: [Date: DailyForecast] = [:]

  /// Last refresh timestamp. Used to throttle (don't refetch within 30 min).
  private(set) var lastRefresh: Date?

  /// Last error from a fetch attempt. UI can surface this if useful;
  /// for now we just keep it for diagnostics.
  private(set) var lastError: Error?

  /// Hardcoded for now — Zürich. See class docs above.
  private let latitude = 47.3769
  private let longitude = 8.5417

  private static let logger = Logger(subsystem: "swiss.atoll.cal", category: "weather")

  /// Refetches the forecast unless we refreshed within the last 30 min.
  /// Pass `force: true` to override the throttle (e.g., pull-to-refresh).
  func refreshIfNeeded(force: Bool = false) async {
    if !force, let last = lastRefresh, Date().timeIntervalSince(last) < 30 * 60 {
      return
    }
    await refresh()
  }

  /// Unconditional fetch from Open-Meteo.
  func refresh() async {
    let url = URL(string:
      "https://api.open-meteo.com/v1/forecast" +
      "?latitude=\(latitude)" +
      "&longitude=\(longitude)" +
      "&daily=temperature_2m_max,temperature_2m_min,weather_code" +
      "&timezone=auto" +
      "&forecast_days=14"
    )!

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
      dailyByDate = Self.parse(response)
      lastRefresh = Date()
      lastError = nil
      Self.logger.debug("loaded \(self.dailyByDate.count, privacy: .public) days from Open-Meteo")
    } catch {
      lastError = error
      Self.logger.error(
        "Open-Meteo fetch failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Look up a forecast for a specific day. Returns `nil` if the day is
  /// outside the cached window or the store hasn't been refreshed.
  func forecast(for date: Date) -> DailyForecast? {
    let key = Calendar.current.startOfDay(for: date)
    return dailyByDate[key]
  }

  // MARK: - Parsing

  /// Decode the API's "parallel-arrays" JSON shape into a date-keyed map.
  private static func parse(_ response: OpenMeteoResponse) -> [Date: DailyForecast] {
    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = TimeZone(identifier: response.timezone) ?? .current

    let cal = Calendar.current
    var result: [Date: DailyForecast] = [:]

    let count = min(
      response.daily.time.count,
      response.daily.temperature_2m_max.count,
      response.daily.temperature_2m_min.count,
      response.daily.weather_code.count
    )

    for i in 0..<count {
      guard let date = isoFormatter.date(from: response.daily.time[i]) else { continue }
      let key = cal.startOfDay(for: date)
      result[key] = DailyForecast(
        date: key,
        highC: response.daily.temperature_2m_max[i],
        lowC:  response.daily.temperature_2m_min[i],
        symbolName: Self.symbolName(for: response.daily.weather_code[i])
      )
    }
    return result
  }

  /// WMO weather codes → SF Symbol names. Covers all standard WMO codes the
  /// Open-Meteo `weather_code` field returns. Unknown codes fall back to a
  /// neutral cloud icon.
  ///
  /// Reference: https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  private static func symbolName(for code: Int) -> String {
    switch code {
    case 0:           return "sun.max.fill"               // Clear sky
    case 1:           return "sun.min.fill"               // Mainly clear
    case 2:           return "cloud.sun.fill"             // Partly cloudy
    case 3:           return "cloud.fill"                 // Overcast
    case 45, 48:      return "cloud.fog.fill"             // Fog
    case 51, 53, 55:  return "cloud.drizzle.fill"         // Drizzle
    case 56, 57:      return "cloud.sleet.fill"           // Freezing drizzle
    case 61, 63, 65:  return "cloud.rain.fill"            // Rain
    case 66, 67:      return "cloud.sleet.fill"           // Freezing rain
    case 71, 73, 75:  return "cloud.snow.fill"            // Snow
    case 77:          return "snowflake"                  // Snow grains
    case 80, 81, 82:  return "cloud.heavyrain.fill"       // Rain showers
    case 85, 86:      return "cloud.snow.fill"            // Snow showers
    case 95:          return "cloud.bolt.rain.fill"       // Thunderstorm
    case 96, 99:      return "cloud.bolt.fill"            // Thunderstorm w/ hail
    default:          return "cloud.fill"
    }
  }
}

// MARK: - Wire JSON shape

/// Open-Meteo response envelope. The API returns parallel arrays under
/// `daily`, one entry per forecast day. The `timezone` field tells us how to
/// interpret the date strings (Open-Meteo with `timezone=auto` returns local
/// times for the requested coordinates).
private struct OpenMeteoResponse: Decodable {
  let timezone: String
  let daily: Daily

  struct Daily: Decodable {
    let time: [String]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let weather_code: [Int]
  }
}
