import SwiftUI
import AtollHub

/// Eine Kontaktlisten-Zeile: Avatar + Name + Quell-Chips + erste E-Mail.
/// `selected` faerbt die Zeile im Akzent (weisser Text).
struct ContactRow: View {
  let contact: MergedContact
  let selected: Bool

  var body: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contact.displayName, size: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(contact.displayName)
          .font(.system(size: 13.5, weight: .semibold))
          .foregroundStyle(selected ? .white : .primary)
          .lineLimit(1)
        HStack(spacing: 6) {
          ForEach(contact.sources, id: \.self) { src in
            Text(src == .atoll ? "Atoll" : "Apple")
              .font(.system(size: 10.5, weight: .medium))
              .padding(.horizontal, 6).padding(.vertical, 1)
              .foregroundStyle(selected ? .white : .secondary)
              .background(selected ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(.quaternary),
                          in: RoundedRectangle(cornerRadius: 5))
          }
          if let mail = contact.emails.first {
            Text(mail)
              .font(.system(size: 11.5))
              .foregroundStyle(selected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
              .lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 7)
    .background(selected ? CoColor.accent : .clear)
    .contentShape(Rectangle())
  }
}
