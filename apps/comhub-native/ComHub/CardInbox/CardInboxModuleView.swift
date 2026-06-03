import SwiftUI
import AtollHub

/// CardInbox-Modul: read-only Liste der AtollCard-Leads (`v_card_leads_inbox`).
/// Import passiert im Web — hier nur Anzeige + Status (neu/importiert).
struct CardInboxModuleView: View {
  @State private var store = CardInboxStore()
  @State private var expanded: Set<String> = []

  private var accent: Color { CoColor.module(.cardInbox) }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
    }
    .task { await store.reload() }
  }

  private var header: some View {
    HStack {
      Text("CardInbox").font(.system(size: 17, weight: .bold))
      Spacer()
      Text("\(store.leads.count)").font(.system(size: 12)).foregroundStyle(.tertiary)
      IconButton(systemName: "arrow.clockwise", help: "Aktualisieren") {
        Task { await store.reload() }
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
  }

  @ViewBuilder
  private var content: some View {
    if store.loading && store.leads.isEmpty {
      CoSkeletonRows().frame(maxHeight: .infinity, alignment: .top)
    } else if store.leads.isEmpty {
      ContentUnavailableView("Keine Leads", systemImage: "tray")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(store.leads) { lead in
            LeadRow(lead: lead, accent: accent,
                    isExpanded: expanded.contains(lead.id),
                    onToggle: { toggle(lead) })
            Divider().opacity(0.4)
          }
        }
      }
    }
  }

  private func toggle(_ lead: CardLead) {
    if expanded.contains(lead.id) { expanded.remove(lead.id) }
    else { expanded.insert(lead.id) }
  }
}

/// Eine Lead-Zeile: Avatar, Name, Kontaktzeile, Topic-Chip, Datum + Status-Chip,
/// optional die Nachricht (2 Zeilen, beim Antippen voll ausgeklappt).
private struct LeadRow: View {
  let lead: CardLead
  let accent: Color
  let isExpanded: Bool
  let onToggle: () -> Void

  private var contactLine: String? {
    let parts = [lead.email, lead.phone].compactMap { $0 }.filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var body: some View {
    Button(action: onToggle) {
      HStack(alignment: .top, spacing: 11) {
        CoAvatar(name: lead.displayName, size: 36, color: accent)
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(lead.displayName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 0)
            if !lead.capturedDateText.isEmpty {
              Text(lead.capturedDateText).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
          }
          if let contactLine {
            Text(contactLine).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
          }
          if let msg = lead.message, !msg.isEmpty {
            Text(msg)
              .font(.system(size: 12.5)).foregroundStyle(.secondary)
              .lineLimit(isExpanded ? nil : 2)
              .fixedSize(horizontal: false, vertical: isExpanded)
          }
          HStack(spacing: 6) {
            if let topic = lead.topic, !topic.isEmpty {
              CoChip(text: topic, color: accent)
            }
            if let card = lead.cardTitle, !card.isEmpty {
              CoChip(text: card)
            }
            statusChip
          }
          .padding(.top, 1)
        }
      }
      .padding(.horizontal, 14).padding(.vertical, 11)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var statusChip: some View {
    lead.isImported
      ? CoChip(text: "importiert", color: CoColor.module(.kombox))
      : CoChip(text: "neu", color: CoColor.accent)
  }
}
