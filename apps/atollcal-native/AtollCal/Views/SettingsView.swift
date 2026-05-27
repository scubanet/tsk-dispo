import SwiftUI
import EventKit
import AtollCore

struct SettingsView: View {
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AuthState.self) var auth
  @Environment(\.dismiss) var dismiss

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("secondaryTimeZoneID") private var secondaryTimeZoneID: String = ""

  @State private var enabledIds: Set<String> = []

  /// Curated list of secondary time-zone options. The empty string disables
  /// the overlay; other entries are valid `TimeZone(identifier:)` strings.
  private let secondaryTimeZoneOptions: [(id: String, label: String)] = [
    ("", "Keine"),
    ("Asia/Manila", "Manila (Philippinen)"),
    ("Asia/Bangkok", "Bangkok / Indonesien"),
    ("Asia/Dubai", "Dubai"),
    ("America/New_York", "New York"),
    ("America/Los_Angeles", "Los Angeles"),
    ("Australia/Sydney", "Sydney"),
    ("Pacific/Auckland", "Auckland"),
    ("UTC", "UTC"),
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section("Kalender-Quellen") {
          if calendarStore.authorizationStatus != .fullAccess {
            VStack(alignment: .leading, spacing: 6) {
              Text("Kalender-Zugriff verweigert").bold()
              Text("Erlaube Zugriff in den System-Einstellungen, um deine Kalender zu nutzen.")
                .font(.caption).foregroundColor(.secondary)
            }
          } else if calendarStore.calendars.isEmpty {
            Text("Keine Kalender gefunden.")
              .foregroundColor(.secondary)
          } else {
            ForEach(calendarStore.calendars, id: \.calendarIdentifier) { cal in
              Toggle(isOn: Binding(
                get: { enabledIds.contains(cal.calendarIdentifier) },
                set: { newValue in
                  if newValue { enabledIds.insert(cal.calendarIdentifier) }
                  else { enabledIds.remove(cal.calendarIdentifier) }
                  persist()
                }
              )) {
                HStack {
                  // Apple's Birthdays calendar (type == .birthday) often has
                  // `cgColor == nil`. `Color(cgColor:)` is non-optional and
                  // would crash — fall back to a neutral pink that matches
                  // the system Birthdays tint.
                  Circle()
                    .fill(calendarColor(cal))
                    .frame(width: 10, height: 10)
                  Text(cal.title)
                  Spacer()
                  Text(cal.source.title).font(.caption).foregroundColor(.secondary)
                }
              }
            }
          }
        }

        Section("ATOLL") {
          Toggle("Meine Tauchkurs-Einsätze", isOn: $atollEnabled)
          if case .signedIn(let user) = auth.status {
            HStack {
              Text("Eingeloggt als")
              Spacer()
              Text(user.email ?? user.name).font(.caption).foregroundColor(.secondary)
            }
            Button("Abmelden", role: .destructive) {
              Task { await auth.signOut() }
              dismiss()
            }
          } else {
            Text("ATOLL nicht verbunden")
              .foregroundColor(.secondary)
          }
        }

        Section("Zweite Zeitzone") {
          Picker("Anzeige in Day/Week-View", selection: $secondaryTimeZoneID) {
            ForEach(secondaryTimeZoneOptions, id: \.id) { opt in
              Text(opt.label).tag(opt.id)
            }
          }
          if !secondaryTimeZoneID.isEmpty,
             let tz = TimeZone(identifier: secondaryTimeZoneID) {
            HStack {
              Text("Aktuell")
              Spacer()
              Text(currentTimeIn(tz))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
            }
          }
        }

        Section("Über") {
          HStack {
            Text("AtollCal")
            Spacer()
            Text("v0.1 (Build 1)").font(.caption).foregroundColor(.secondary)
          }
          HStack {
            Text("Datenquelle")
            Spacer()
            Text(Config.tenantName).font(.caption).foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Einstellungen")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Schließen") { dismiss() }
        }
      }
      .onAppear {
        // Lade aktuelle enabled-Set aus AppStorage
        if let data = enabledCalendarIdsJSON.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
          enabledIds = Set(arr)
        }
        // Default: ALLE enabled wenn AppStorage leer (= erstes Öffnen)
        if enabledIds.isEmpty && !calendarStore.calendars.isEmpty {
          enabledIds = Set(calendarStore.calendars.map { $0.calendarIdentifier })
          persist()
        }
      }
    }
  }

  private func persist() {
    let arr = Array(enabledIds)
    if let data = try? JSONEncoder().encode(arr),
       let str = String(data: data, encoding: .utf8) {
      enabledCalendarIdsJSON = str
    }
  }

  /// Safe colour lookup — Apple's Birthdays calendar can have `cgColor == nil`,
  /// which would crash `Color(cgColor:)`. Fall back to the system pink so the
  /// swatch matches Apple's own Calendar UI for that calendar.
  private func calendarColor(_ cal: EKCalendar) -> Color {
    if let cg = cal.cgColor as CGColor? {
      return Color(cgColor: cg)
    }
    return .pink
  }

  /// Current wall-clock time in the given timezone, formatted as "HH:mm".
  private func currentTimeIn(_ tz: TimeZone) -> String {
    let f = DateFormatter()
    f.timeZone = tz
    f.dateFormat = "HH:mm"
    return f.string(from: Date())
  }
}
