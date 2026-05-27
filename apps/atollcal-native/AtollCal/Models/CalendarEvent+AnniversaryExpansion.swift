import Foundation

extension CalendarEvent {
  /// Expand a single `ContactAnniversary` into the per-year all-day events
  /// that fall inside `range`. Mirrors the `expandATOLL` pattern so the
  /// callers in SidebarView / iPhoneRootView treat both ATOLL course days
  /// and anniversaries identically.
  ///
  /// One contact produces one event per calendar year covered by the range
  /// — typically 1 for a 30-day agenda, 3 for a 3-month mini-cal window
  /// straddling year boundaries.
  static func expandAnniversary(
    _ anniversary: ContactAnniversary,
    in range: DateInterval
  ) -> [CalendarEvent] {
    let cal = Calendar.current
    return anniversary.occurrences(in: range, calendar: cal).map { occ in
      CalendarEvent.anniversary(
        contactName: anniversary.contactName,
        dayDate: occ.date,
        ageYears: occ.ageYears,
        contactID: anniversary.id
      )
    }
  }
}
