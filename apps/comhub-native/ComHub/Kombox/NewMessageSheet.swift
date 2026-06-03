import SwiftUI
import AtollHub

/// Neue Mail/WhatsApp an einen bestehenden Kontakt (mit Atoll-Member + passendem Empfaenger).
struct NewMessageSheet: View {
  let contacts: [MergedContact]
  let onSend: (_ atollContactId: String, _ channel: KomboxChannel, _ body: String, _ subject: String?) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var search = ""
  @State private var selected: MergedContact?
  @State private var channel: KomboxChannel = .whatsapp
  @State private var subject = ""
  @State private var messageText = ""

  // Nur Kontakte mit Atoll-Member (comms-outbound braucht die rohe contacts.id) und je
  // nach Kanal passendem Empfaenger (Mail: hat E-Mail; WhatsApp: hat Telefon).
  private func atollId(_ c: MergedContact) -> String? {
    guard let m = c.members.first(where: { $0.source.type == .atoll }) else { return nil }
    return SourceID.raw(from: m.id)
  }

  private var eligible: [MergedContact] {
    contacts
      .filter { atollId($0) != nil }
      .filter { search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) }
  }

  private var canSend: Bool {
    guard let s = selected, atollId(s) != nil,
          !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
    return channel == .mail ? !s.emails.isEmpty : !s.phones.isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Picker("Kanal", selection: $channel) {
          Text("WhatsApp").tag(KomboxChannel.whatsapp)
          Text("Mail").tag(KomboxChannel.mail)
        }
        .pickerStyle(.segmented)

        Section("Empfänger") {
          TextField("Suche", text: $search)
          ForEach(eligible) { c in
            Button {
              selected = c
            } label: {
              HStack {
                Text(c.displayName)
                Spacer()
                if selected?.id == c.id {
                  Image(systemName: "checkmark").foregroundStyle(.tint)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }

        if channel == .mail {
          Section("Betreff") { TextField("Betreff", text: $subject) }
        }

        Section("Nachricht") {
          TextField("Text", text: $messageText, axis: .vertical)
        }
      }
      .navigationTitle("Neue Nachricht")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Senden") {
            if let s = selected, let id = atollId(s) {
              onSend(id, channel, messageText, channel == .mail ? (subject.isEmpty ? nil : subject) : nil)
              dismiss()
            }
          }
          .disabled(!canSend)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 460, minHeight: 520)
    #endif
  }
}
