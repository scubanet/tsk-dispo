import SwiftUI
import AtollHub

/// Rechte Spalte: grosser Avatar, Name, Quellen, Aktions-Buttons (Mail/Anruf),
/// Detail-Zeilen (E-Mail/Telefon/Quellen).
struct ContactDetailPane: View {
  let contact: MergedContact?
  /// Einstieg zum Bearbeiten (wird in einer spaeteren Task verdrahtet).
  var onEdit: (() -> Void)? = nil
  @Environment(\.openURL) private var openURL

  /// dd.MM.yyyy, de_CH / Europe/Zurich.
  private static let birthdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    f.dateFormat = "dd.MM.yyyy"
    return f
  }()

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
            CoChip(text: contact.kind == .organization ? "Firma" : "Person")
              .padding(.top, 8)
            Text(contact.sources.map { $0 == .atoll ? "Atoll" : "Apple" }.joined(separator: " · "))
              .font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 3)
            actions(contact).padding(.top, 20)
          }
          .padding(.horizontal, 30).padding(.top, 36).padding(.bottom, 22)
          .overlay(alignment: .topTrailing) { editButton }
          Divider()
          VStack(spacing: 0) {
            detailRow("E-Mail", contact.emails, accent: true)
            detailRow("Telefon", contact.phones, accent: true)
            if let org = contact.organizationName, !org.isEmpty {
              detailRow("Firma", [org], accent: false)
            }
            ForEach(Array(contact.addresses.enumerated()), id: \.offset) { _, addr in
              addressRow(addr)
            }
            if let bday = contact.birthday {
              detailRow("Geburtstag", [Self.birthdayFormatter.string(from: bday)], accent: false)
            }
            chipRow("Sprachen", contact.languages)
            chipRow("Rollen", contact.roles)
            chipRow("Tags", contact.tags)
            if let notes = contact.notes, !notes.isEmpty {
              notesRow(notes)
            }
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
  private var editButton: some View {
    if let onEdit {
      Button(action: onEdit) {
        Image(systemName: "square.and.pencil")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(CoColor.accent)
          .frame(width: 34, height: 34)
          .background(CoColor.accent.opacity(0.12), in: Circle())
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Bearbeiten")
      .padding(.trailing, 22)
      .padding(.top, 22)
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
      .contentShape(Rectangle())
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

  @ViewBuilder
  private func addressRow(_ addr: PostalAddress) -> some View {
    let line = addr.oneLine
    if !line.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text("Adresse").font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
        Text(line).font(.system(size: 13.5)).foregroundStyle(.primary).textSelection(.enabled)
        if let label = addr.label, !label.isEmpty {
          Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 9)
      .overlay(alignment: .bottom) { Divider() }
    }
  }

  @ViewBuilder
  private func chipRow(_ label: String, _ values: [String]) -> some View {
    let shown = values.filter { !$0.isEmpty }
    if !shown.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
        ChipFlow(spacing: 6, lineSpacing: 6) {
          ForEach(shown, id: \.self) { CoChip(text: $0) }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 9)
      .overlay(alignment: .bottom) { Divider() }
    }
  }

  @ViewBuilder
  private func notesRow(_ notes: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Notizen").font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
      Text(notes).font(.system(size: 13.5)).foregroundStyle(.primary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 9)
    .overlay(alignment: .bottom) { Divider() }
  }
}

/// Einfaches Flow-Layout: legt Kinder zeilenweise um, bricht bei Breite um.
private struct ChipFlow: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxLineWidth: CGFloat = 0
    for sv in subviews {
      let size = sv.sizeThatFits(.unspecified)
      if x > 0, x + size.width > maxWidth {
        maxLineWidth = max(maxLineWidth, x - spacing)
        x = 0; y += lineHeight + lineSpacing; lineHeight = 0
      }
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    maxLineWidth = max(maxLineWidth, x - spacing)
    return CGSize(width: maxWidth == .infinity ? maxLineWidth : maxWidth, height: y + lineHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
    for sv in subviews {
      let size = sv.sizeThatFits(.unspecified)
      if x > bounds.minX, x + size.width > bounds.maxX {
        x = bounds.minX; y += lineHeight + lineSpacing; lineHeight = 0
      }
      sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}
