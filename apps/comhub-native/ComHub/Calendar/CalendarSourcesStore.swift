import Foundation
import Observation
@preconcurrency import EventKit
import SwiftUI

/// Eine waehlbare Kalender-Quelle (Apple-EKCalendar oder Atoll).
struct CalendarSource: Identifiable, Equatable {
  let id: String          // EKCalendar.identifier bzw. "atoll"
  let title: String
  let colorHex: String?
}

/// Verfuegbare Kalender (Apple-EKCalendars + Atoll) + die aktiven (persistent).
/// `enabledIds == nil` heisst „alle" (Default). Sobald der User toggelt, wird
/// eine konkrete Menge gespeichert.
@MainActor
@Observable
final class CalendarSourcesStore {
  private(set) var sources: [CalendarSource] = []
  /// Aktive Kalender-Ids; `nil` = alle aktiv.
  private(set) var enabledIds: Set<String>?

  private let store: EKEventStore
  private let defaultsKey = "comhub.calendar.disabledIds"

  init(store: EKEventStore) {
    self.store = store
    refresh()
  }

  /// Liest die Apple-Kalender + fuegt Atoll hinzu; laedt deaktivierte Ids aus den Defaults.
  func refresh() {
    var out: [CalendarSource] = []
    if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
      for cal in store.calendars(for: .event) {
        out.append(CalendarSource(id: cal.calendarIdentifier, title: cal.title,
                                  colorHex: cal.cgColor.flatMap(Self.hex(from:))))
      }
    }
    out.append(CalendarSource(id: "atoll", title: "Atoll", colorHex: "#0A84FF"))
    sources = out.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

    let disabled = Set((UserDefaults.standard.array(forKey: defaultsKey) as? [String]) ?? [])
    enabledIds = disabled.isEmpty ? nil : Set(sources.map(\.id)).subtracting(disabled)
  }

  func isEnabled(_ id: String) -> Bool { enabledIds?.contains(id) ?? true }

  /// Deaktivierte Ids (für den appweiten Hub-Filter). Leer = alle aktiv.
  var disabledIds: Set<String> {
    guard let enabledIds else { return [] }
    return Set(sources.map(\.id)).subtracting(enabledIds)
  }

  /// Persistierte deaktivierte Ids — ohne EKEventStore lesbar (für den App-Start,
  /// damit der Hub-Filter schon vor dem ersten Heute-Laden greift).
  static var persistedDisabled: Set<String> {
    Set((UserDefaults.standard.array(forKey: "comhub.calendar.disabledIds") as? [String]) ?? [])
  }

  func toggle(_ id: String) {
    var enabled = enabledIds ?? Set(sources.map(\.id))
    if enabled.contains(id) { enabled.remove(id) } else { enabled.insert(id) }
    enabledIds = enabled
    let disabled = Set(sources.map(\.id)).subtracting(enabled)
    UserDefaults.standard.set(Array(disabled), forKey: defaultsKey)
  }

  private static func hex(from cg: CGColor) -> String? {
    guard let c = cg.components, c.count >= 3 else { return nil }
    let r = Int((c[0] * 255).rounded()), g = Int((c[1] * 255).rounded()), b = Int((c[2] * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
