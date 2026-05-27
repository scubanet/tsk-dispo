import SwiftUI

/// Main "Meine Karten" screen — header pill, big title, tab pills,
/// horizontal card gallery, the selected card's detail block, and a
/// recent-leads section.
struct CardsView: View {
  @Environment(CardStore.self)   private var cardStore
  @Environment(LeadStore.self)   private var leadStore
  @Environment(ToastCenter.self) private var toast

  @State private var topTab: String = "personas"
  @State private var editingCard: Card?
  @State private var pendingDelete: Card?

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        HeaderBar(pill: "Cards", meta: "\(cardStore.cards.count) Personas")
        BigTitleView(leading: "Meine", accent: "Karten")
        TabPillBar(tabs: [
          .init(id: "personas", label: "Personas", count: cardStore.cards.count),
          .init(id: "leads",    label: "Leads",    count: leadStore.leads.count),
          .init(id: "stats",    label: "Stats")
        ], selection: $topTab)

        gallery
          .padding(.top, 4)
          .padding(.bottom, 12)

        if let selected = cardStore.selected {
          PersonaDetailCard(card: selected, person: MockSeed.dominik)
            .padding(.horizontal, 16)
        }

        recentLeadsSection
      }
      .padding(.bottom, 16)
    }
    .background(Color.cardPageBackground)
    .refreshable {
      await cardStore.refresh()
      await leadStore.refresh()
    }
    .sheet(item: $editingCard) { card in
      CardEditorSheet(card: card)
    }
    .alert("Karte löschen?", isPresented: Binding(
      get: { pendingDelete != nil },
      set: { if !$0 { pendingDelete = nil } }
    )) {
      Button("Löschen", role: .destructive) {
        if let target = pendingDelete {
          Task {
            await cardStore.delete(id: target.id)
            toast.show("Karte gelöscht", kind: .info)
            pendingDelete = nil
          }
        }
      }
      Button("Abbrechen", role: .cancel) { pendingDelete = nil }
    } message: {
      Text(pendingDelete.map { "Die Karte „\($0.title)“ wird permanent entfernt." } ?? "")
    }
  }

  // MARK: - Gallery

  @ViewBuilder
  private var gallery: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 16) {
        ForEach(cardStore.cards) { card in
          BizCardView(
            card: card,
            person: MockSeed.dominik,
            scansCount: estimatedScans(for: card),
            leadsCount: leadStore.leads.filter { $0.cardId == card.id }.count
          )
          .onTapGesture {
            withAnimation(.spring) { cardStore.selectedID = card.id }
          }
          .scaleEffect(card.id == cardStore.selectedID ? 1.0 : 0.96)
          .contextMenu {
            Button {
              editingCard = card
            } label: {
              Label("Bearbeiten", systemImage: "pencil")
            }
            if !card.isDefault {
              Button {
                Task {
                  await cardStore.setDefault(id: card.id)
                  toast.show("Default: \(card.title)", kind: .info)
                }
              } label: {
                Label("Als Default", systemImage: "star")
              }
            }
            Divider()
            Button(role: .destructive) {
              pendingDelete = card
            } label: {
              Label("Löschen", systemImage: "trash")
            }
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 8)
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollIndicators(.hidden)

    HStack(spacing: 6) {
      ForEach(cardStore.cards) { card in
        Capsule()
          .fill(card.id == cardStore.selectedID ? Color.primary : Color.gray.opacity(0.25))
          .frame(width: card.id == cardStore.selectedID ? 18 : 6, height: 6)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 8)
  }

  // MARK: - Recent leads (last 5)

  @ViewBuilder
  private var recentLeadsSection: some View {
    let recent = Array(leadStore.leads.prefix(5))
    if !recent.isEmpty {
      SectionHeaderRow(
        label: "RECENT LEADS",
        subtitle: weekLabel(),
        trailing: "\(leadStore.newCount) neu"
      )
      VStack(spacing: 8) {
        ForEach(recent) { lead in
          LeadRowView(
            lead: lead,
            cardBadge: badge(forCardId: lead.cardId)
          )
        }
      }
      .padding(.horizontal, 16)
    }
  }

  // MARK: - Helpers

  private func estimatedScans(for card: Card) -> Int {
    // Until the analytics store is per-card hot, just synthesise a number
    // from the seed analytics so the cards in the gallery feel populated.
    let preset = MockSeed.analytics(for: card.id, range: .thirtyDays)
    return preset.totalScans
  }

  private func badge(forCardId id: UUID) -> String? {
    guard let card = cardStore.cards.first(where: { $0.id == id }) else { return nil }
    switch card.theme.preset {
    case .courseDirector: return "CD"
    case .seaExplorers:   return "SE"
    case .privat:         return "P"
    case .custom:         return card.badge?.prefix(2).uppercased()
    }
  }

  private func weekLabel() -> String {
    let cal = Calendar.current
    let week = cal.component(.weekOfYear, from: .now)
    return "KW \(week)"
  }
}
