import SwiftUI
import AtollHub

/// Reader: Kopf (Kontakt) + Tages-Verlauf (Bubbles/Mail/System) + Composer.
/// Pro Nachricht „Loeschen" via Kontextmenue.
struct ThreadView: View {
  let store: KomboxStore
  @Environment(Hub.self) private var hub

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
    }
  }

  private var header: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contactName, size: 30)
      Text(contactName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
      Spacer()
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
    if event.kind == .system {
      KomboxSystemMarker(event: event)
    } else {
      // Pille direkt NEBEN der Bubble (gleiche HStack, kein Gap) — bleibt beim
      // Hinfahren sichtbar. Immer praesent (opacity), damit kein Layout-Sprung.
      HStack(alignment: .center, spacing: 6) {
        if alignTrailing { Spacer(minLength: 40); actionBar }
        card
        if !alignTrailing { actionBar; Spacer(minLength: 40) }
      }
      .onHover { hovering = $0 }
      .contextMenu {
        if canReply { Button { onReply() } label: { Label("Antworten", systemImage: "arrowshape.turn.up.left") } }
        Button { onTask() } label: { Label("Als Aufgabe", systemImage: "checklist") }
        Button(role: .destructive) { onDelete() } label: { Label("Löschen", systemImage: "trash") }
      }
    }
  }

  @ViewBuilder
  private var card: some View {
    switch event.kind {
    case .whatsapp: KomboxBubbleCard(event: event)
    case .email:    KomboxMailCard(event: event)
    case .system:   EmptyView()
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
    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    .opacity(hovering ? 1 : 0)
    .allowsHitTesting(hovering)
    .animation(.easeInOut(duration: 0.12), value: hovering)
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
