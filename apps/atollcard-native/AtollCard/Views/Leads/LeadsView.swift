import SwiftUI

/// Inbox tab — date-sectioned list of leads, filter pills on top.
struct LeadsView: View {
  @Environment(LeadStore.self)   private var leadStore
  @Environment(CardStore.self)   private var cardStore
  @Environment(ToastCenter.self) private var toast

  @State private var filter: LeadFilter = .all
  @State private var selected: Lead?

  enum LeadFilter: Hashable {
    case all
    case card(UUID)
    case hot

    var label: String {
      switch self {
      case .all: "Alle"
      case .card(let id): "Karte"  // resolved at render time
      case .hot: "Heiss"
      }
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
        HeaderBar(pill: "Leads", meta: "KW \(currentWeek()) · \(leadStore.leads.count)")
        BigTitleView(leading: "Inbox", accent: "\(Calendar.current.component(.year, from: .now))")
        filterPills.padding(.top, 10).padding(.horizontal, 24)

        ForEach(filteredSections, id: \.id) { section in
          Section(header: SectionHeaderRow(label: section.label,
                                           subtitle: section.subtitle,
                                           trailing: section.leads.count == 1 ? "1 neu" : nil)) {
            VStack(spacing: 8) {
              ForEach(section.leads) { lead in
                LeadRowView(lead: lead, cardBadge: badge(for: lead.cardId))
                  .onTapGesture { selected = lead }
              }
            }
            .padding(.horizontal, 16)
          }
        }
      }
      .padding(.bottom, 24)
    }
    .background(Color.cardPageBackground)
    .refreshable { await leadStore.refresh() }
    .sheet(item: $selected) { lead in
      LeadDetailSheet(lead: lead)
        .presentationDetents([.medium, .large])
    }
  }

  // MARK: - Filter pills

  @ViewBuilder
  private var filterPills: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        filterPill("Alle · \(leadStore.leads.count)", tone: .blue, active: filter == .all) {
          filter = .all
        }
        ForEach(cardStore.cards) { card in
          let count = leadStore.leads.filter { $0.cardId == card.id }.count
          filterPill("\(card.title.short) · \(count)", tone: tone(for: card),
                     active: filter == .card(card.id)) {
            filter = .card(card.id)
          }
        }
        filterPill("Heiss · \(leadStore.newCount)", tone: .rose, active: filter == .hot) {
          filter = .hot
        }
      }
    }
  }

  @ViewBuilder
  private func filterPill(_ label: String, tone: PillTone, active: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(active ? tone.foreground : tone.background, in: Capsule())
        .foregroundStyle(active ? Color.white : tone.foreground)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Sections

  private var filteredSections: [LeadSection] {
    let filtered: [Lead] = switch filter {
    case .all:               leadStore.leads
    case .card(let id):      leadStore.leads.filter { $0.cardId == id }
    case .hot:               leadStore.leads.filter { $0.status == .new }
    }
    // Build sections from a temporary store-equivalent — keeps the logic in one place.
    let temp = TempSectionBuilder(leads: filtered)
    return temp.sections()
  }

  // MARK: - Helpers

  private func badge(for cardId: UUID) -> String? {
    guard let card = cardStore.cards.first(where: { $0.id == cardId }) else { return nil }
    return switch card.theme.preset {
    case .courseDirector: "CD"
    case .seaExplorers:   "SE"
    case .privat:         "P"
    case .custom:         card.badge.map { String($0.prefix(2).uppercased()) }
    }
  }

  private func tone(for card: Card) -> PillTone {
    switch card.theme.preset {
    case .courseDirector: .beige
    case .seaExplorers:   .purple
    case .privat:         .green
    case .custom:         .blue
    }
  }

  private func currentWeek() -> Int {
    Calendar.current.component(.weekOfYear, from: .now)
  }
}

private extension String {
  /// "PADI Course Director" → "CD Karte", "SeaExplorers Manager" → "SE Karte"
  var short: String {
    if contains("Course Director") { return "CD Karte" }
    if contains("SeaExplorers")    { return "SE Karte" }
    if contains("Privat")          { return "P Karte" }
    return self
  }
}

/// Standalone copy of `LeadStore.groupedByDay` so a filtered list still
/// produces correctly-sorted sections.
private struct TempSectionBuilder {
  let leads: [Lead]
  func sections() -> [LeadSection] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
          let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
      return [LeadSection(label: "ALLE", subtitle: nil, leads: leads)]
    }
    var heute: [Lead] = [], gestern: [Lead] = [], dieseWoche: [Lead] = [], aelter: [Lead] = []
    for lead in leads {
      let day = cal.startOfDay(for: lead.capturedAt)
      if day == today          { heute.append(lead) }
      else if day == yesterday { gestern.append(lead) }
      else if day >= weekStart { dieseWoche.append(lead) }
      else                     { aelter.append(lead) }
    }
    var sections: [LeadSection] = []
    if !heute.isEmpty      { sections.append(LeadSection(label: "HEUTE", subtitle: format(today),     leads: heute)) }
    if !gestern.isEmpty    { sections.append(LeadSection(label: "GESTERN", subtitle: format(yesterday), leads: gestern)) }
    if !dieseWoche.isEmpty { sections.append(LeadSection(label: "DIESE WOCHE", subtitle: weekRange(weekStart), leads: dieseWoche)) }
    if !aelter.isEmpty     { sections.append(LeadSection(label: "ÄLTER", subtitle: nil, leads: aelter)) }
    return sections
  }
  private func format(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM.yy"
    return f.string(from: d)
  }
  private func weekRange(_ start: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM."
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    return "\(f.string(from: start))–\(f.string(from: end))"
  }
}
