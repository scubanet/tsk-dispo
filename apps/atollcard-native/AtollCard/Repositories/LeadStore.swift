import Foundation
import Observation
import OSLog
import Supabase

@MainActor
@Observable
public final class LeadStore {
  public private(set) var leads: [Lead] = []
  public private(set) var lastError: Error?

  /// Card titles indexed by id — used by the notification to render
  /// "PADI Course Director" alongside the lead name. Filled by `CardStore`
  /// via `setCardTitles(_:)` so we don't have to re-fetch.
  private var cardTitles: [UUID: String] = [:]

  private let repository: LeadRepository
  private var realtimeTask: Task<Void, Never>?
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "leads")

  public init(repository: LeadRepository) {
    self.repository = repository
  }

  // No deinit: `realtimeTask` is `@MainActor`-isolated and Swift 6's
  // nonisolated deinit can't touch it. The Task captures `[weak self]`
  // so it self-terminates naturally when the store is deallocated.

  public func setCardTitles(_ titles: [UUID: String]) {
    cardTitles = titles
  }

  public var newCount: Int { leads.filter { $0.status == .new }.count }

  public func refresh() async {
    do {
      leads = try await repository.fetchAll()
      lastError = nil
    } catch {
      Self.logger.error("refresh failed: \(error.localizedDescription, privacy: .public)")
      lastError = error
    }
  }

  public func updateStatus(id: UUID, status: LeadStatus) async {
    do {
      try await repository.updateStatus(id: id, status: status)
      await refresh()
    } catch {
      lastError = error
    }
  }

  public func markImported(id: UUID) async {
    do {
      try await repository.markImported(id: id)
      await refresh()
    } catch {
      lastError = error
    }
  }

  // MARK: - Realtime

  /// Subscribe to `card_leads` INSERTs server-side. New rows arrive over
  /// websocket → prepended to the in-memory list → a local notification is
  /// scheduled. RLS keeps the channel scoped to our cards automatically.
  public func startRealtime() {
    realtimeTask?.cancel()
    realtimeTask = Task { [weak self] in
      guard let self else { return }
      let channel = SupabaseClient.shared.channel("public:card_leads")
      let inserts = channel.postgresChange(
        InsertAction.self,
        schema: "public",
        table: "card_leads"
      )
      // subscribeWithError throws if the websocket can't reach the server;
      // the unauthenticated/network error path is treated as "log and stop"
      // rather than crash the app.
      do {
        try await channel.subscribeWithError()
      } catch {
        Self.logger.error("realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
        return
      }
      for await change in inserts {
        await self.handleRealtimeInsert(change.record)
      }
    }
  }

  public func stopRealtime() {
    realtimeTask?.cancel()
    realtimeTask = nil
  }

  private func handleRealtimeInsert(_ record: [String: AnyJSON]) async {
    // Decode the JSON dict back into our Lead struct via the same Codable
    // path we use for REST. Keeps one source of truth for column names.
    do {
      let data = try JSONEncoder().encode(record)
      let lead = try JSONDecoder().decode(Lead.self, from: data)

      // Prepend (we sort by capturedAt desc, so newest first).
      if !leads.contains(where: { $0.id == lead.id }) {
        leads.insert(lead, at: 0)
      }

      // Fire a local notification — uses card title if known, else fallback.
      let cardTitle = cardTitles[lead.cardId] ?? "AtollCard"
      await NotificationService.shared.scheduleLeadNotification(lead, cardTitle: cardTitle)
    } catch {
      Self.logger.error("realtime decode failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Helpers used by LeadsView

  /// Section grouping for the inbox: HEUTE / GESTERN / DIESE WOCHE / ÄLTER.
  public func groupedByDay() -> [LeadSection] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
          let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
      return [LeadSection(label: "ALLE", subtitle: nil, leads: leads)]
    }

    var heute: [Lead] = []
    var gestern: [Lead] = []
    var dieseWoche: [Lead] = []
    var aelter: [Lead] = []

    for lead in leads {
      let day = cal.startOfDay(for: lead.capturedAt)
      if day == today          { heute.append(lead) }
      else if day == yesterday { gestern.append(lead) }
      else if day >= weekStart { dieseWoche.append(lead) }
      else                     { aelter.append(lead) }
    }

    var sections: [LeadSection] = []
    if !heute.isEmpty {
      sections.append(LeadSection(label: "HEUTE", subtitle: Self.dateLabel(today), leads: heute))
    }
    if !gestern.isEmpty {
      sections.append(LeadSection(label: "GESTERN", subtitle: Self.dateLabel(yesterday), leads: gestern))
    }
    if !dieseWoche.isEmpty {
      sections.append(LeadSection(label: "DIESE WOCHE", subtitle: Self.weekRangeLabel(weekStart),
                                  leads: dieseWoche))
    }
    if !aelter.isEmpty {
      sections.append(LeadSection(label: "ÄLTER", subtitle: nil, leads: aelter))
    }
    return sections
  }

  private static func dateLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "dd.MM.yy"
    return f.string(from: date)
  }

  private static func weekRangeLabel(_ weekStart: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "dd.MM."
    let cal = Calendar.current
    let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(f.string(from: weekStart))–\(f.string(from: weekEnd))"
  }
}

public struct LeadSection: Identifiable, Hashable {
  public let id = UUID()
  public let label: String
  public let subtitle: String?
  public let leads: [Lead]
}
