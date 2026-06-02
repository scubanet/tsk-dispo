import SwiftUI
import AtollHub

/// Heute-Cockpit: aggregierte Startseite. Sektionen verlinken ins jeweilige
/// Modul über `onOpenModule` (die Shell setzt damit ihren `selectedModule`).
struct CockpitView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CockpitStore()

  /// Navigationswunsch an die Shell (Tippen auf Sektion/Zeile).
  let onOpenModule: (ComHubModule) -> Void

  private static let dateHeader: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Heute").font(.largeTitle.weight(.bold))
          Spacer()
          if store.loading { ProgressView().controlSize(.small) }
        }
        Text(Self.dateHeader.string(from: Date()))
          .font(.headline).foregroundStyle(.secondary)

        // Termine heute (live).
        CockpitSection(title: "Termine", systemImage: "calendar",
                       isEmpty: store.todayEvents.isEmpty,
                       emptyText: "Keine Termine heute",
                       onOpen: { onOpenModule(.kalender) }) {
          ForEach(store.todayEvents) { UnifiedEventRow(event: $0) }
        }

        // Offene Aufgaben (via Hub.allTasks; leer bis Phase 4).
        CockpitSection(title: "Aufgaben", systemImage: "checklist",
                       isEmpty: store.openTasks.isEmpty,
                       emptyText: "Keine offenen Aufgaben",
                       onOpen: { onOpenModule(.tasks) }) {
          ForEach(store.openTasks) { TaskRow(task: $0) }
        }

        // Neue Nachrichten (Kombox, Phase 3 — vorerst Empty-State).
        CockpitSection(title: "Neue Nachrichten", systemImage: "bubble.left.and.bubble.right",
                       isEmpty: true,
                       emptyText: "Noch keine neuen Nachrichten",
                       onOpen: { onOpenModule(.kombox) }) { EmptyView() }

        // Neue Leads (CardInbox, Phase 4 — vorerst Empty-State).
        CockpitSection(title: "Neue Leads", systemImage: "tray.and.arrow.down",
                       isEmpty: true,
                       emptyText: "Noch keine neuen Leads",
                       onOpen: { onOpenModule(.cardInbox) }) { EmptyView() }
      }
      .padding(20)
      .frame(maxWidth: 700, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task { await store.reload(using: hub) }
  }
}

/// Eine Cockpit-Sektion: tippbarer Kopf (→ Modul) + Inhalt oder Empty-State.
private struct CockpitSection<Content: View>: View {
  let title: String
  let systemImage: String
  let isEmpty: Bool
  let emptyText: String
  let onOpen: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button(action: onOpen) {
        HStack(spacing: 6) {
          Image(systemName: systemImage)
          Text(title).font(.title3.weight(.semibold))
          Spacer()
          Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
      }
      .buttonStyle(.plain)

      if isEmpty {
        Text(emptyText).font(.callout).foregroundStyle(.secondary)
          .padding(.vertical, 4)
      } else {
        VStack(alignment: .leading, spacing: 2) { content() }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }
}

/// Eine Aufgaben-Zeile fürs Cockpit (Titel + optionale Fälligkeit + Quell-Badge).
private struct TaskRow: View {
  let task: UnifiedTask

  private static let dueFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "circle").font(.caption).foregroundStyle(.secondary)
      Text(task.title).font(.callout).lineLimit(1)
      Spacer(minLength: 0)
      if let due = task.due {
        Text(Self.dueFormatter.string(from: due))
          .font(.caption).foregroundStyle(.secondary)
      }
      Text(task.source.type == .atoll ? "Atoll" : "Apple")
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(.quaternary, in: Capsule())
    }
    .padding(.vertical, 2)
  }
}
