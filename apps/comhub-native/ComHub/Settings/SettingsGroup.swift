import SwiftUI

/// Eine Einstellungs-Gruppe: Uppercase-Titel + gerahmte Karte mit Zeilen.
struct SettingsGroup<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title.uppercased())
        .font(.system(size: 11.5, weight: .bold)).foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
      VStack(spacing: 0) { content() }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CoTheme.separator, lineWidth: 1))
    }
  }
}

/// Eine Einstellungs-Zeile: farbiges Icon + Titel/Untertitel + optionales Rechts-Element.
struct SettingsRow<Right: View>: View {
  let icon: String
  let iconColor: Color
  let title: String
  var subtitle: String? = nil
  var showDivider: Bool = true
  @ViewBuilder var right: () -> Right

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white)
          .frame(width: 28, height: 28).background(iconColor, in: RoundedRectangle(cornerRadius: 7))
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.system(size: 13.5, weight: .medium))
          if let subtitle { Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.tertiary) }
        }
        Spacer(minLength: 0)
        right()
      }
      .padding(.horizontal, 16).padding(.vertical, 11)
      if showDivider { Divider().padding(.leading, 16) }
    }
  }
}

/// Gruen/grauer Status-Punkt mit Label.
struct SettingsStatusDot: View {
  let on: Bool
  var onLabel = "Erlaubt"
  var offLabel = "Nicht erlaubt"
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(on ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.secondary)
        .frame(width: 8, height: 8)
      Text(on ? onLabel : offLabel).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
}
