import Foundation

/// Quellneutrale Eingabe fuer Termin-Erstellen/-Bearbeiten. `calendarId == nil`
/// heisst „Standard-Kalender des Geraets".
public struct EventDraft: Sendable, Equatable {
  public var title: String
  public var start: Date
  public var end: Date
  public var isAllDay: Bool
  public var location: String?
  public var calendarId: String?

  public init(title: String, start: Date, end: Date, isAllDay: Bool = false,
              location: String? = nil, calendarId: String? = nil) {
    self.title = title; self.start = start; self.end = end
    self.isAllDay = isAllDay; self.location = location; self.calendarId = calendarId
  }
}
