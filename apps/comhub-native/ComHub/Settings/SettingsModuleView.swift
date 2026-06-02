import SwiftUI
import AtollCore

/// Einstellungen: Konto-Kopf, Abmelden, Apple-Berechtigungen, Atoll-Konto,
/// Darstellung, Version.
struct SettingsModuleView: View {
  @Environment(AuthState.self) private var auth
  @Environment(AppleAuthorizationService.self) private var appleAuth
  @Environment(\.openURL) private var openURL

  private var user: CurrentUser? {
    if case .signedIn(let u) = auth.status { return u }
    return nil
  }
  private var appVersion: String {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    return "\(Config.appName) \(v) (\(b))"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        accountGroup
        permissionsGroup
        appearanceGroup
        Text(appVersion).font(.system(size: 11.5)).foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.horizontal, 30).padding(.vertical, 26)
      .frame(maxWidth: 620, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { appleAuth.refreshStatus() }
  }

  private var header: some View {
    HStack(spacing: 16) {
      CoAvatar(name: user?.name ?? "ComHub", size: 64)
      VStack(alignment: .leading, spacing: 2) {
        Text(user?.name ?? "—").font(.system(size: 21, weight: .bold))
        Text("\(user?.email ?? "—") · ComHub Konto").font(.system(size: 13)).foregroundStyle(.tertiary)
      }
      Spacer()
    }
  }

  private var accountGroup: some View {
    SettingsGroup(title: "Konto") {
      SettingsRow(icon: "person.crop.circle", iconColor: CoColor.accent,
                  title: "Atoll-Konto", subtitle: user.map { $0.role.displayName } ?? "Angemeldet") {
        SettingsStatusDot(on: true, onLabel: "Verbunden", offLabel: "Getrennt")
      }
      SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: Color(red: 1, green: 0.27, blue: 0.23),
                  title: "Abmelden", showDivider: false) {
        Button("Abmelden", role: .destructive) { Task { await auth.signOut() } }
          .buttonStyle(.borderless)
      }
    }
  }

  private var permissionsGroup: some View {
    SettingsGroup(title: "Apple-Berechtigungen") {
      SettingsRow(icon: "calendar", iconColor: Color(red: 1, green: 0.27, blue: 0.23),
                  title: "Kalender") { SettingsStatusDot(on: appleAuth.calendars == .authorized) }
      SettingsRow(icon: "checklist", iconColor: Color(red: 1, green: 0.62, blue: 0.04),
                  title: "Erinnerungen") { SettingsStatusDot(on: appleAuth.reminders == .authorized) }
      SettingsRow(icon: "person.2", iconColor: Color(red: 0.56, green: 0.56, blue: 0.58),
                  title: "Kontakte") { SettingsStatusDot(on: appleAuth.contacts == .authorized) }
      SettingsRow(icon: "gearshape", iconColor: .secondary, title: "Berechtigungen verwalten",
                  subtitle: "Erneut anfragen oder in den Systemeinstellungen", showDivider: false) {
        HStack(spacing: 8) {
          Button("Anfragen") { Task { await appleAuth.requestAll() } }.buttonStyle(.borderless)
          Button("System") { openSystemPrivacy() }.buttonStyle(.borderless)
        }
      }
    }
  }

  private var appearanceGroup: some View {
    SettingsGroup(title: "Darstellung") {
      SettingsRow(icon: "circle.lefthalf.filled", iconColor: Color(red: 1, green: 0.62, blue: 0.04),
                  title: "Erscheinungsbild", subtitle: "Folgt den Systemeinstellungen (Hell/Dunkel)",
                  showDivider: false) { EmptyView() }
    }
  }

  private func openSystemPrivacy() {
    #if os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
      openURL(url)
    }
    #else
    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    #endif
  }
}
