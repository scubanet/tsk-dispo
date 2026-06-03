import SwiftUI
import AtollHub

/// Neue Mail/WhatsApp an einen bestehenden Kontakt (mit Atoll-Member + passendem Empfaenger).
/// Empfaenger-Auswahl ueber einen eigenen, suchbaren Picker (Push) — nicht inline,
/// damit Kanal/Betreff/Text immer sichtbar bleiben.
struct NewMessageSheet: View {
  let contacts: [MergedContact]
  let onSend: (_ atollContactId: String, _ channel: KomboxChannel, _ body: String, _ subject: String?) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var selected: MergedContact?
  @State private var channel: KomboxChannel = .whatsapp
  @State private var subject = ""
  @State private var messageText = ""
  @State private var showPicker = false

  static func atollId(_ c: MergedContact) -> String? {
    guard let m = c.members.first(where: { $0.source.type == .atoll }) else { return nil }
    return SourceID.raw(from: m.id)
  }

  /// Kontakte mit Atoll-Member + je nach Kanal passendem Empfaenger.
  private func eligible(for channel: KomboxChannel) -> [MergedContact] {
    contacts.filter { Self.atollId($0) != nil }
      .filter { channel == .mail ? !$0.emails.isEmpty : !$0.phones.isEmpty }
  }

  private var recipientValid: Bool {
    guard let s = selected, Self.atollId(s) != nil else { return false }
    return channel == .mail ? !s.emails.isEmpty : !s.phones.isEmpty
  }
  private var canSend: Bool {
    recipientValid && !messageText.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private var recipientDetail: String? {
    guard let s = selected else { return nil }
    return channel == .mail ? s.emails.first : s.phones.first
  }

  var body: some View {
    CoSheetScaffold(
      icon: "square.and.pencil",
      tint: CoColor.module(.kombox),
      title: "Neue Nachricht",
      saveTitle: "Senden",
      canSave: canSend,
      onSave: {
        if let s = selected, let id = Self.atollId(s) {
          onSend(id, channel, messageText, channel == .mail ? (subject.isEmpty ? nil : subject) : nil)
        }
      }
    ) {
      Section("Kanal") {
        Picker("Kanal", selection: $channel) {
          Text("WhatsApp").tag(KomboxChannel.whatsapp)
          Text("Mail").tag(KomboxChannel.mail)
        }
        .pickerStyle(.segmented)
      }

      Section("Empfänger") {
        Button { showPicker = true } label: {
          HStack {
            if let s = selected {
              VStack(alignment: .leading, spacing: 2) {
                Text(s.displayName).foregroundStyle(.primary)
                if let d = recipientDetail { Text(d).font(.caption).foregroundStyle(.secondary) }
              }
            } else {
              Text("Empfänger wählen").foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if selected != nil, !recipientValid {
          Text(channel == .mail ? "Keine E-Mail hinterlegt." : "Keine Telefonnummer hinterlegt.")
            .font(.caption).foregroundStyle(.red)
        }
      }

      if channel == .mail {
        Section("Betreff") { TextField("Betreff", text: $subject) }
      }

      Section("Nachricht") {
        TextField("Text", text: $messageText, axis: .vertical)
          .lineLimit(4...12)
      }
    }
    .sheet(isPresented: $showPicker) {
      RecipientPicker(contacts: eligible(for: channel), selected: $selected)
    }
  }
}

/// Suchbare Einzelauswahl eines Empfaengers.
private struct RecipientPicker: View {
  let contacts: [MergedContact]
  @Binding var selected: MergedContact?
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  private var filtered: [MergedContact] {
    search.isEmpty ? contacts
      : contacts.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
  }

  var body: some View {
    NavigationStack {
      List(filtered) { c in
        Button {
          selected = c; dismiss()
        } label: {
          HStack {
            Text(c.displayName)
            Spacer()
            if selected?.id == c.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .searchable(text: $search, prompt: "Kontakt suchen")
      .navigationTitle("Empfänger")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
      }
      .overlay {
        if filtered.isEmpty {
          ContentUnavailableView("Keine passenden Kontakte", systemImage: "person.crop.circle.badge.questionmark")
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 380, minHeight: 460)
    #endif
  }
}
