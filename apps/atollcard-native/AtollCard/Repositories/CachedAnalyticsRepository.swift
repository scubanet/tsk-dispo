import Foundation
import OSLog

/// Decorator around a remote `AnalyticsRepository` that falls back to a
/// local cache rollup when offline.
///
/// Strategy:
/// - **Online**: delegate to the remote (canonical numbers — the server sees
///   scans the device never pulled), then opportunistically prime the cache
///   by ensuring whatever we already have stays warm. We don't try to
///   overwrite analytics in the cache — analytics aren't a stored entity, the
///   underlying `ScanEntity` + `LeadEntity` rows are. A separate refresh on
///   the lead/card repos keeps those rows current.
/// - **Offline**: compute the rollup in-process from the cached
///   `ScanEntity` + `LeadEntity` rows. Lower-fidelity than the server view
///   (we only see what was synced before the device dropped offline) but
///   keeps the dashboard non-empty.
///
/// No mutation queue — analytics are read-only.
final class CachedAnalyticsRepository: AnalyticsRepository {
  private let remote: AnalyticsRepository
  private let cache:  CacheStore
  private let reach:  ReachabilityMonitor
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "cached-analytics-repo")

  /// Stable sentinel matching `SupabaseAnalyticsRepository.fetchAggregateAnalytics`
  /// so callers can switch repositories without the aggregate id changing.
  private static let aggregateId = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!

  init(remote: AnalyticsRepository, cache: CacheStore, reach: ReachabilityMonitor) {
    self.remote = remote
    self.cache  = cache
    self.reach  = reach
  }

  func fetchAnalytics(cardId: UUID, range: DateRangeOption) async throws -> CardAnalytics {
    let online = await MainActor.run { reach.isConnected }
    if online {
      do {
        return try await remote.fetchAnalytics(cardId: cardId, range: range)
      } catch {
        Self.logger.warning("remote fetchAnalytics failed, falling back to cache rollup: \(error.localizedDescription, privacy: .public)")
      }
    }
    return await rollupFromCache(cardId: cardId, range: range, all: false)
  }

  func fetchAggregateAnalytics(range: DateRangeOption) async throws -> CardAnalytics {
    let online = await MainActor.run { reach.isConnected }
    if online {
      do {
        return try await remote.fetchAggregateAnalytics(range: range)
      } catch {
        Self.logger.warning("remote fetchAggregateAnalytics failed, falling back to cache rollup: \(error.localizedDescription, privacy: .public)")
      }
    }
    return await rollupFromCache(cardId: Self.aggregateId, range: range, all: true)
  }

  // MARK: - Local Rollup

  /// Mirrors `SupabaseAnalyticsRepository.aggregate(...)` so a cache-fallback
  /// reading has the same shape as the online answer. `all == true` rolls up
  /// every card; otherwise it filters to `cardId`.
  private func rollupFromCache(cardId: UUID, range: DateRangeOption, all: Bool) async -> CardAnalytics {
    let cutoff = cutoffDate(for: range)
    let (scans, leads) = await MainActor.run {
      (cache.scans(), cache.leads())
    }
    let filteredScans = scans.filter { scan in
      if !all, scan.cardId != cardId { return false }
      if let cutoff, scan.scannedAt < cutoff { return false }
      return true
    }
    let filteredLeads = leads.filter { lead in
      if !all, lead.cardId != cardId { return false }
      if let cutoff, lead.capturedAt < cutoff { return false }
      return true
    }

    let cal = Calendar.current
    let scansByDay = bucketByDay(filteredScans.map(\.scannedAt), cutoff: cutoff, calendar: cal)
    let leadsByDay = bucketByDay(filteredLeads.map(\.capturedAt), cutoff: cutoff, calendar: cal)

    var byCountry: [String: Int] = [:]
    for s in filteredScans where s.ipCountry != nil {
      byCountry[s.ipCountry!, default: 0] += 1
    }
    var byField: [Scan.TappedField: Int] = [:]
    for s in filteredScans where s.fieldTapped != nil {
      byField[s.fieldTapped!, default: 0] += 1
    }

    let totalScans = filteredScans.count
    let totalLeads = filteredLeads.count
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

  /// Buckets a list of timestamps into per-day counts, zero-filling gaps so
  /// the chart line doesn't jump. Same algorithm as the Supabase rollup.
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
    guard let days = range.days else { return nil }
    return Calendar.current.date(byAdding: .day, value: -days, to: .now)
  }
}
