import SwiftUI
import AtollHub

/// Rechte Spalte: grosser Avatar, Name, Quellen, Aktions-Buttons (Mail/Anruf),
/// Detail-Zeilen (E-Mail/Telefon/Quellen).
struct ContactDetailPane: View {
  let contact: MergedContact?
  @Environment(\.openURL) private var openURL

  var body: some View {
    if let contact {
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 0) {
            CoAvatar(name: contact.displayName, size: 92)
            Text(contact.displayName)
              .font(.system(size: 24, weight: .bold))
              .multilineTextAlignment(.center)
              .padding(.top, 16)
            Text(contact.sources.map { $0 == .atoll ? "Atoll" : "Apple" }.joined(separator: " · "))
              .font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 3)
            actions(contact).padding(.top, 20)
          }
          .padding(.horizontal, 30).padding(.top, 36).padding(.bottom, 22)
          Divider()
          VStack(spacing: 0) {
            detailRow("E-Mail", contact.emails, accent: true)
            detailRow("Telefon", contact.phones, accent: true)
            detailRow("Quellen", [contact.sources.map { $0 == .atoll ? "Atoll" : "Apple" }.joined(separator: ", ")], accent: false)
          }
          .padding(.horizontal, 30).padding(.vertical, 6)
          .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
      }
    } else {
      ContentUnavailableView("Kein Kontakt ausgewählt", systemImage: "person.2",
                             description: Text("Wähle links einen Kontakt aus."))
    }
  }

  @ViewBuilder
  private func actions(_ contact: MergedContact) -> some View {
    HStack(spacing: 10) {
      if let mail = contact.emails.first, let url = URL(string: "mailto:\(mail)") {
        actionButton("Mail", "envelope") { openURL(url) }
      }
      if let phone = contact.phones.first,
         let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
        actionButton("Anruf", "phone") { openURL(url) }
      }
    }
  }

  private func actionButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: icon).font(.system(size: 19)).foregroundStyle(CoColor.accent)
          .frame(width: 42, height: 42)
          .background(CoColor.accent.opacity(0.12), in: Circle())
        Text(label).font(.system(size: 11)).foregroundStyle(CoColor.accent)
      }
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func detailRow(_ label: String, _ values: [String], accent: Bool) -> some View {
    let shown = values.filter { !$0.isEmpty }
    if !shown.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
        ForEach(shown, id: \.self) { v in
          Text(v).font(.system(size: 13.5))
            .foregroundStyle(accent ? CoColor.accent : Color.primary)
            .textSelection(.enabled)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 9)
      .overlay(alignment: .bottom) { Divider() }
    }
  }
}
