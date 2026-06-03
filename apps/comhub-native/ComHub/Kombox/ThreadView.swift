import SwiftUI
import AtollHub

/// Reader: Kopf (Kontakt) + Tages-Verlauf (Bubbles/Mail/System) + Composer.
/// Pro Nachricht „Loeschen" via Kontextmenue.
/// Eine protokollierbare Aktivitaet (Quick-Log) — Identifiable fuer `.sheet(item:)`.
struct LogKind: Identifiable {
  let id = UUID()
  let eventType: String   // "note" | "call" | "meeting_past" | "task"
  let title: String
  let icon: String
}

struct ThreadView: View {
  let store: KomboxStore
  @Environment(Hub.self) private var hub
  @State private var logKind: LogKind?

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var contactName: String {
    store.thread.flatMap(\.events).first?.contactName
      ?? store.conversations.first { $0.id == store.selectedContactId }?.contactName ?? ""
  }

  var body: some View {
    if store.selectedContactId == nil {
      ContentUnavailableView("Konversation wählen", systemImage: "bubble.left.and.bubble.right")
    } else {
      VStack(spacing: 0) {
        header
        Divider()
        messages
        Divider()
        KomboxComposer(store: store)
      }
      .sheet(item: $logKind) { kind in
        LogActivitySheet(kind: kind) { summary, body in
          await store.logActivity(eventType: kind.eventType, summary: summary, body: body)
        }
      }
    }
  }

  private var header: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contactName, size: 30)
      Text(contactName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
      Spacer()
      if store.selectedContactId != nil {
        Menu {
          Button { logKind = LogKind(eventType: "note", title: "Notiz", icon: "note.text") }
            label: { Label("Notiz", systemImage: "note.text") }
          Button { logKind = LogKind(eventType: "call", title: "Anruf", icon: "phone") }
            label: { Label("Anruf", systemImage: "phone") }
          Button { logKind = LogKind(eventType: "meeting_past", title: "Meeting", icon: "person.2") }
            label: { Label("Meeting", systemImage: "person.2") }
          Button { logKind = LogKind(eventType: "task", title: "Aufgabe", icon: "checklist") }
            label: { Label("Aufgabe", systemImage: "checklist") }
        } label: {
          Label("Protokollieren", systemImage: "plus.circle")
            .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(CoColor.module(.kombox))
        .fixedSize()
      }
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var messages: some View {
    if store.thread.isEmpty {
      ContentUnavailableView(store.loadingThread ? "Lädt…" : "Keine Nachrichten", systemImage: "bubble.left")
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(store.thread) { section in
            HStack {
              Spacer()
              Text(Self.dayLabel.string(from: section.day))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.quaternary.opacity(0.4), in: Capsule())
              Spacer()
            }
            .padding(.top, 6)
            ForEach(section.events) { event in
              ThreadMessageRow(
                event: event,
                onReply: {
                  if event.kind == .email {
                    store.pendingReplySubject = reSubject(event.subject ?? event.summary)
                    store.pendingReplyChannel = "email"
                  } else {
                    store.pendingReplyChannel = "whatsapp"
                  }
                },
                onTask: { Task { try? await hub.createTask(title: taskTitle(event), due: nil, listId: nil) } },
                onDelete: { Task { await store.deleteEvent(id: event.id) } }
              )
            }
          }
        }
        .padding(12)
      }
    }
  }

  /// Betreff fuer eine Antwort: „Re: …" voranstellen (nicht doppelt).
  private func reSubject(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.lowercased().hasPrefix("re:") { return t }
    return t.isEmpty ? "Re:" : "Re: \(t)"
  }

  /// Aufgaben-Titel aus einer Nachricht (Betreff bzw. Body, gekuerzt).
  private func taskTitle(_ event: KomboxEvent) -> String {
    let raw = (event.subject ?? event.body ?? event.summary).trimmingCharacters(in: .whitespacesAndNewlines)
    let oneLine = raw.replacingOccurrences(of: "\n", with: " ")
    return oneLine.count > 120 ? String(oneLine.prefix(120)) + "…" : (oneLine.isEmpty ? "Aufgabe" : oneLine)
  }
}

/// Eine Nachricht im Verlauf + Hover-Aktionsleiste (macOS) und Kontextmenue
/// (iOS Long-Press / macOS Rechtsklick): Antworten · Task · Loeschen.
private struct ThreadMessageRow: View {
  let event: KomboxEvent
  let onReply: () -> Void
  let onTask: () -> Void
  let onDelete: () -> Void
  @State private var hovering = false

  private var canReply: Bool { event.kind == .whatsapp || event.kind == .email }
  private var alignTrailing: Bool { event.direction == .outbound }

  var body: some View {
    switch event.kind {
    case .system:
      KomboxSystemMarker(event: event)
    case .note, .call, .meeting, .task:
      KomboxLogMarker(event: event)
    default:
      HStack(spacing: 0) {
        if alignTrailing { Spacer(minLength: 40) }
        // Pille als Overlay OBEN-RECHTS auf der Bubble — Cursor bleibt auf der
        // Bubble, daher kein Hover-Abbruch. Hover-Bereich um die Pille leicht
        // erweitert (Top-Inset), damit sie bequem erreichbar ist.
        card
          .overlay(alignment: .topTrailing) {
            actionBar
              .padding(6)
              .opacity(hovering ? 1 : 0)
              .allowsHitTesting(hovering)
              .animation(.easeInOut(duration: 0.12), value: hovering)
          }
          .contentShape(Rectangle())
          .onHover { hovering = $0 }
          .contextMenu {
            if canReply { Button { onReply() } label: { Label("Antworten", systemImage: "arrowshape.turn.up.left") } }
            Button { onTask() } label: { Label("Als Aufgabe", systemImage: "checklist") }
            Button(role: .destructive) { onDelete() } label: { Label("Löschen", systemImage: "trash") }
          }
        if !alignTrailing { Spacer(minLength: 40) }
      }
    }
  }

  @ViewBuilder
  private var card: some View {
    switch event.kind {
    case .whatsapp: KomboxBubbleCard(event: event)
    case .email:    KomboxMailCard(event: event)
    default:        EmptyView()
    }
  }

  private var actionBar: some View {
    HStack(spacing: 2) {
      if canReply {
        iconButton("arrowshape.turn.up.left", "Antworten", action: onReply)
      }
      iconButton("checklist", "Als Aufgabe", action: onTask)
      iconButton("trash", "Löschen", role: .destructive, action: onDelete)
    }
    .padding(3)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
  }

  private func iconButton(_ symbol: String, _ help: String,
                          role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
    Button(role: role, action: action) {
      Image(systemName: symbol).font(.system(size: 11))
        .foregroundStyle(role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        .frame(width: 24, height: 22)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

/// Eingabe-Sheet fuer einen Quick-Log-Eintrag (Titel Pflicht · Notiz optional).
private struct LogActivitySheet: View {
  let kind: LogKind
  let onSave: (_ summary: String, _ body: String?) async -> Bool
  @State private var summary = ""
  @State private var note = ""

  private var canSave: Bool {
    !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    CoSheetScaffold(
      icon: kind.icon,
      tint: CoColor.module(.kombox),
      title: kind.title,
      saveTitle: "Speichern",
      canSave: canSave,
      onSave: {
        let s = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return await onSave(s, b.isEmpty ? nil : b)
      }
    ) {
      Section("Titel") {
        TextField("Titel", text: $summary)
      }
      Section("Notiz") {
        TextField("Notiz (optional)", text: $note, axis: .vertical)
          .lineLimit(3...10)
      }
    }
  }
}
