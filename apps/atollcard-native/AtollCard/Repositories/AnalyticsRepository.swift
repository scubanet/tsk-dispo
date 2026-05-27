import Foundation

/// Aggregated analytics computed from `card_scans` + `card_leads`.
/// The web-side computes these via a `card_analytics` view; the app reads
/// it back as one struct per card per time range.
public struct CardAnalytics: Identifiable, Hashable, Sendable {
  public var id: UUID { cardId }
  public let cardId: UUID
  public let range: DateRangeOption
  public let totalScans: Int
  public let totalLeads: Int
  public let conversionRate: Double      // 0…1
  public let scansByDay: [DailyCount]
  public let leadsByDay: [DailyCount]
  public let scansByCountry: [String: Int]   // ISO-3166-1 alpha-2 → count
  public let scansByField: [Scan.TappedField: Int]

  public init(
    cardId: UUID,
    range: DateRangeOption,
    totalScans: Int,
    totalLeads: Int,
    conversionRate: Double,
    scansByDay: [DailyCount],
    leadsByDay: [DailyCount],
    scansByCountry: [String: Int],
    scansByField: [Scan.TappedField: Int]
  ) {
    self.cardId = cardId
    self.range = range
    self.totalScans = totalScans
    self.totalLeads = totalLeads
    self.conversionRate = conversionRate
    self.scansByDay = scansByDay
    self.leadsByDay = leadsByDay
    self.scansByCountry = scansByCountry
    self.scansByField = scansByField
  }
}

public struct DailyCount: Hashable, Sendable, Identifiable {
  public let date: Date
  public let count: Int
  public var id: Date { date }

  public init(date: Date, count: Int) {
    self.date = date
    self.count = count
  }
}

public enum DateRangeOption: String, CaseIterable, Identifiable, Sendable {
  case sevenDays   = "7d"
  case thirtyDays  = "30d"
  case ninetyDays  = "90d"
  case allTime     = "all"

  public var id: String { rawValue }
  public var label: String {
    switch self {
    case .sevenDays: "7 Tage"
    case .thirtyDays: "30 Tage"
    case .ninetyDays: "90 Tage"
    case .allTime: "Gesamt"
    }
  }

  public var days: Int? {
    switch self {
    case .sevenDays: 7
    case .thirtyDays: 30
    case .ninetyDays: 90
    case .allTime: nil
    }
  }
}

public protocol AnalyticsRepository: Sendable {
  func fetchAnalytics(cardId: UUID, range: DateRangeOption) async throws -> CardAnalytics
  func fetchAggregateAnalytics(range: DateRangeOption) async throws -> CardAnalytics
}

// MARK: - Mock

public final class MockAnalyticsRepository: AnalyticsRepository, @unchecked Sendable {
  public init() {}

  public func fetchAnalytics(cardId: UUID, range: DateRangeOption) async throws -> CardAnalytics {
    MockSeed.analytics(for: cardId, range: range)
  }

  public func fetchAggregateAnalytics(range: DateRangeOption) async throws -> CardAnalytics {
    MockSeed.aggregateAnalytics(range: range)
  }
}

// MARK: - Supabase

import Supabase
import AtollCore

/// Postgrest-backed `AnalyticsRepository`. Reads `card_scans` + `card_leads`
/// directly and rolls them up in-process. Once volume grows we can migrate
/// to a server-side `card_analytics` view and read that instead.
public final class SupabaseAnalyticsRepository: AnalyticsRepository, @unchecked Sendable {
  public init() {}

  private var client: SupabaseClient { .shared }

  public func fetchAnalytics(cardId: UUID, range: DateRangeOption) async throws -> CardAnalytics {
    let cutoff = cutoffDate(for: range)

    var scansQ = client.from("card_scans").select().eq("card_id", value: cardId)
    if let cutoff { scansQ = scansQ.gte("scanned_at", value: cutoff) }
    let scans: [Scan] = try await scansQ.execute().value

    var leadsQ = client.from("card_leads").select().eq("card_id", value: cardId)
    if let cutoff { leadsQ = leadsQ.gte("captured_at", value: cutoff) }
    let leads: [Lead] = try await leadsQ.execute().value

    return aggregate(cardId: cardId, range: range, scans: scans, leads: leads, cutoff: cutoff)
  }

  public func fetchAggregateAnalytics(range: DateRangeOption) async throws -> CardAnalytics {
    let cutoff = cutoffDate(for: range)

    var scansQ = client.from("card_scans").select()
    if let cutoff { scansQ = scansQ.gte("scanned_at", value: cutoff) }
    let scans: [Scan] = try await scansQ.execute().value

    var leadsQ = client.from("card_leads").select()
    if let cutoff { leadsQ = leadsQ.gte("captured_at", value: cutoff) }
    let leads: [Lead] = try await leadsQ.execute().value

    // Aggregate identifier — stable for the view but won't conflict with any
    // real card UUID.
    let aggregateId = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!
    return aggregate(cardId: aggregateId, range: range, scans: scans, leads: leads, cutoff: cutoff)
  }

  // MARK: - Rollup

  private func aggregate(cardId: UUID, range: DateRangeOption,
                         scans: [Scan], leads: [Lead], cutoff: Date?) -> CardAnalytics {
    let cal = Calendar.current

    let scansByDay  = bucketByDay(scans.map(\.scannedAt),  cutoff: cutoff, calendar: cal)
    let leadsByDay  = bucketByDay(leads.map(\.capturedAt), cutoff: cutoff, calendar: cal)

    var byCountry: [String: Int] = [:]
    for s in scans where s.ipCountry != nil {
      byCountry[s.ipCountry!, default: 0] += 1
    }

    var byField: [Scan.TappedField: Int] = [:]
    for s in scans where s.fieldTapped != nil {
      byField[s.fieldTapped!, default: 0] += 1
    }

    let totalScans = scans.count
    let totalLeads = leads.count
    return CardAnalytics(
      cardId: cardId,
      range: range,
      totalScans: totalScans,
      totalLeads: totalLeads,
      conversionRate: totalScans == 0 ? 0 : Double(totalLeads) / Double(totalScans),
      scansByDay: scansByDay,
      leadsByDay: leadsByDay,
      scansByCountry: byCountry,
      scansByField: byField
    )
  }

  /// Buckets a list of timestamps into a per-day count. The X-axis fills
  /// gaps with zero-count days so the chart line doesn't jump.
  private func bucketByDay(_ dates: [Date], cutoff: Date?, calendar cal: Calendar) -> [DailyCount] {
    let start = cal.startOfDay(for: cutoff ?? dates.min() ?? .now)
    let end   = cal.startOfDay(for: .now)
    guard start <= end else { return [] }

    var counts: [Date: Int] = [:]
    for date in dates {
      let day = cal.startOfDay(for: date)
      counts[day, default: 0] += 1
    }

    var result: [DailyCount] = []
    var day = start
    while day <= end {
      result.append(DailyCount(date: day, count: counts[day] ?? 0))
      guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return result
  }

  private func cutoffDate(for range: DateRangeOption) -> Date? {
    guard let days = range.days else { return nil }     // .allTime → no cutoff
    return Calendar.current.date(byAdding: .day, value: -days, to: .now)
  }
}
