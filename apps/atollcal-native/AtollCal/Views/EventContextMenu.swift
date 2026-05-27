import SwiftUI
import EventKit
import AtollCore

/// `EKEvent` isn't `Identifiable` out of the box. Wrap it for use with
/// `.sheet(item:)` bindings driven by context-menu actions.
struct IdentifiableEKEvent: Identifiable, Hashable {
  let id: String
  let event: EKEvent

  init(_ event: EKEvent) {
    self.event = event
    self.id = event.eventIdentifier ?? "ek-\(ObjectIdentifier(event).hashValue)"
  }

  static func == (lhs: IdentifiableEKEvent, rhs: IdentifiableEKEvent) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Shared `.contextMenu` content for any view that displays a `CalendarEvent`.
///
/// Usage:
/// ```
/// .contextMenu {
///   AtollEventContextMenu(
///     event: ev,
///     onView: { selectedEvent = ev },
///     onEdit: { ek in editingEKEvent = IdentifiableEKEvent(ek) },
///     onDelete: { ek in try? calendarStore.remove(ek) },
///     onOpenAtollWeb: { openURL(URL(string: "https://atoll.swiss")!) }
///   )
/// }
/// ```
///
/// Edit/Delete are only rendered for system events on a writable calendar.
/// "Auf atoll.swiss öffnen" only appears for ATOLL events. Always renders
/// "Anzeigen" so the user has a path to the detail sheet.
struct AtollEventContextMenu: View {
  let event: CalendarEvent
  let onView: () -> Void
  var onEdit: ((EKEvent) -> Void)? = nil
  var onDelete: ((EKEvent) -> Void)? = nil
  var onOpenAtollWeb: (() -> Void)? = nil

  var body: some View {
    Button { onView() } label: {
      Label("Anzeigen", systemImage: "eye")
    }

    switch event {
    case .system(let ek):
      if (ek.calendar?.allowsContentModifications ?? false) {
        if let onEdit {
          Button { onEdit(ek) } label: {
            Label("Bearbeiten", systemImage: "pencil")
          }
        }
        if let onDelete {
          Divider()
          Button(role: .destructive) {
            onDelete(ek)
          } label: {
            Label("Löschen", systemImage: "trash")
          }
        }
      }
    case .atoll:
      if let onOpenAtollWeb {
        Divider()
        Button(action: onOpenAtollWeb) {
          Label("Auf atoll.swiss öffnen", systemImage: "arrow.up.right.square")
        }
      }
    case .anniversary:
      // Anniversaries live in the Contacts app — no in-app edit/delete.
      EmptyView()
    }
  }
}
