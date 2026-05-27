import SwiftUI
import EventKit
import AtollCore
import AtollDesign

/// Fantastical-style iPhone (and iPad-compact) root view.
///
/// Replaces the time-grid-as-primary `mainContent` on iPhone with a Mini-Month
/// + Agenda layout. Day/Week/Month/Quarter/Year views become secondary,
/// reachable from a toolbar Menu (wired by `CalendarRoot` in Chunk 4).
///
/// Layout:
/// ```
/// ┌───────────────────────────────┐
/// │  Mai 2026                     │  ← month-year title
/// │                               │
/// │  KW  Mo Di Mi Do Fr Sa So     │  ← MiniMonthCalendar
/// │  ··  · · · · · · ·  (6 rows)  │
/// │                               │
/// │  ─────                        │  ← divider
/// │  HEUTE 20.05.26               │  ← AgendaList
/// │  • Termin 1                   │
/// │  • Termin 2                   │
/// │  MORGEN 21.05.26              │
/// │  ⋮                            │
/// └───────────────────────────────┘
/// ```
///
/// **Data plumbing:** mirrors `SidebarView` (rebuildBuckets / rebuildMiniCalCounts)
/// pattern. The duplication is intentional for the Pragmatic Phase 1 cut; the
/// shared rebuild logic will be extracted into an `@Observable` `AgendaController`
/// during Phase 1.5 once both views have stabilised against the new layout.
///
/// **Toolbar wiring:** this view does not own a toolbar. `CalendarRoot` mounts it
/// inside a `NavigationStack` and supplies the toolbar (today / view-kind menu /
/// add / settings). Keeps `iPhoneRootView` reusable in previews and tests.
struct IPhoneRootView: View {
  @Binding var focusedDate: Date
  @Binding var selectedEvent: CalendarEvent?

  @Environment(SystemCalendarStore.self) private var calendarStore
  @Environment(AtollEventLoader.self) private var atollLoader
  @Environment(ContactsAnniversaryStore.self) private var anniversaryStore
  @Environment(AuthState.self) private var auth
  @Environment(\.locale) private var locale
  /// GL-005 H1: Reduced Motion — drops the auto-scroll animation when set.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all

  /// Month displayed in the mini-calendar header. Driven by `focusedDate`
  /// changes (synced) but can also be advanced via chevrons; chevrons set
  /// `focusedDate` so the rest of the app follows.
  @State private var miniCalMonth: Date = Calendar.current.startOfDay(for: Date())

  /// Agenda horizon — total days loaded forward from today. Grows as the
  /// endless-scroll sentinel triggers.
  @State private var agendaHorizonDays: Int = 30

  /// Snapshot of buckets for the agenda. Rebuilt whenever events change.
  @State private var buckets: [DayBucket] = []

  /// Per-day list of distinct event colours (max 3, deduped). Drives the
  /// coloured dots beneath each day number in the mini-month. Replaces the
  /// older `eventCountByDay: [Date: Int]` count-based model.
  @State private var eventColorsByDay: [Date: [Color]] = [:]

  /// GL-006 Phase 1.5f — per-day list of SF Symbol names for special-event
  /// icons (birthdays, anniversaries). Rendered alongside the colour dots.
  @State private var specialIconsByDay: [Date: [String]] = [:]

  /// Scroll-position binding for the agenda — drives auto-scroll to today on
  /// appear and when `focusedDate` changes via the mini-cal.
  @State private var scrolledBucketId: Date?

  /// Suppresses the agenda→mini-month sync while we are *programmatically*
  /// scrolling the agenda (e.g., after the user tapped a day in the mini-cal).
  /// Without this flag, the chain `focusedDate → scroll → scrolledBucketId →
  /// focusedDate` would chase its own tail during the animation. Released
  /// ~600 ms later, which covers `.snappy` plus a small buffer.
  @State private var suppressScrollSync: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      MiniMonthCalendar(
        displayedMonth: miniCalMonth,
        focusedDate: $focusedDate,
        eventColorsByDay: eventColorsByDay,
        specialIconsByDay: specialIconsByDay,
        locale: locale,
        onMonthChange: { delta in
          let cal = Calendar.current
          if let new = cal.date(byAdding: .month, value: delta, to: miniCalMonth) {
            miniCalMonth = new
            // Mirror to the rest of the app (synchronous).
            focusedDate = new
          }
        },
        fullWidth: true
      )
      // Fantastical-style: mini-month spans edge-to-edge. The header text +
      // chevrons inside MiniMonthCalendar take care of their own breathing
      // room with the larger font sizing.
      .padding(.top, 8)
      .padding(.bottom, 12)

      Divider()

      AgendaList(
        buckets: buckets,
        locale: locale,
        scrolledBucketId: $scrolledBucketId,
        onSelectDay: { day in focusedDate = day },
        onSelectEvent: { ev in selectedEvent = ev },
        onLoadMore: {
          agendaHorizonDays += 30
          Task { await rebuildBuckets() }
        }
      )
    }
    .task {
      await rebuildAll()
      // Anchor the agenda at today on first appear.
      scrolledBucketId = Calendar.current.startOfDay(for: Date())
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await rebuildAll() }
    }
    // GL-006 Phase 1.5h: react when the Contacts-anniversary store finishes
    // its (async) refresh — without this hook the first rebuild runs with
    // an empty anniversaries array and we never re-render once the data
    // arrives.
    .onChange(of: anniversaryStore.anniversaries) { _, _ in
      Task { await rebuildAll() }
    }
    .onChange(of: focusedDate) { _, newDate in
      let cal = Calendar.current
      if !cal.isDate(newDate, equalTo: miniCalMonth, toGranularity: .month) {
        miniCalMonth = newDate
        Task { await rebuildMiniCalCounts() }
      }
      let key = cal.startOfDay(for: newDate)
      // Skip the programmatic scroll if the agenda is already at this day —
      // that path is taken when the user *scrolled* the agenda and the
      // reverse-sync just bumped focusedDate. Re-animating would yank the
      // scroll position from under their finger.
      if let current = scrolledBucketId, cal.isDate(current, inSameDayAs: key) {
        return
      }
      // Scroll the agenda to the focused day if a bucket exists for it.
      if buckets.contains(where: { $0.id == key }) {
        // Guard the reverse sync while the programmatic scroll animates.
        suppressScrollSync = true
        withAnimation(reduceMotion ? nil : .snappy) {
          scrolledBucketId = key
        }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(600))
          suppressScrollSync = false
        }
      }
    }
    // Fantastical-style reverse sync: as the agenda scrolls, the mini-month
    // follows the day at the top of the visible region. `scrolledBucketId` is
    // the `.scrollPosition(id:)` binding inside `AgendaList`; it fires both
    // when the user drags AND when we programmatically scroll. The
    // `suppressScrollSync` flag breaks the latter loop.
    .onChange(of: scrolledBucketId) { _, newDate in
      guard let newDate, !suppressScrollSync else { return }
      let cal = Calendar.current
      if !cal.isDate(focusedDate, inSameDayAs: newDate) {
        focusedDate = newDate
      }
    }
  }

  // MARK: - Loading
  //
  // TODO (Phase 1.5): extract into a shared `@Observable AgendaController` so
  // SidebarView and IPhoneRootView don't duplicate this logic.

  private func rebuildAll() async {
    await rebuildBuckets()
    await rebuildMiniCalCounts()
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  /// Aggregate events for `today ... today + agendaHorizonDays` into per-day
  /// buckets. Multi-day events are repeated on every day they touch (matches
  /// Fantastical). ATOLL assignments are bucketed by `course.allDates`.
  private func rebuildBuckets() async {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let end = cal.date(byAdding: .day, value: agendaHorizonDays, to: start) ?? start
    let range = DateInterval(start: start, end: end)

    // ATOLL: trigger a reload covering an *extended* range — courses with
    // start_date in the past month but additional course_dates within the
    // agenda window would otherwise be filtered out by the Supabase query
    // (which checks courses.start_date against the requested range).
    if sourceFilter.includesATOLL, atollEnabled, case .signedIn(let user) = auth.status {
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: start) ?? start,
        end:   cal.date(byAdding: .month, value:  1, to: end)   ?? end
      )
      await atollLoader.reload(for: user.legacyInstructorId, range: extendedRange)
    }

    let sysIds = enabledCalendarIds()
    let sysEvents: [EKEvent] = sourceFilter.includesSystem
      ? calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
      : []

    var allDayByDay: [Date: [CalendarEvent]] = [:]
    var timedByDay: [Date: [CalendarEvent]] = [:]

    for ek in sysEvents {
      let ev = CalendarEvent.system(ek)
      if ev.isAllDay || isMultiDay(ev) {
        // Repeat across every covered day.
        var d = cal.startOfDay(for: ev.startDate)
        let endDay = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))
        while d <= endDay && d < range.end {
          if d >= range.start {
            allDayByDay[d, default: []].append(ev)
          }
          d = cal.date(byAdding: .day, value: 1, to: d) ?? d
        }
      } else {
        let key = cal.startOfDay(for: ev.startDate)
        timedByDay[key, default: []].append(ev)
      }
    }

    if sourceFilter.includesATOLL, atollEnabled {
      for assignment in atollLoader.assignments {
        for ev in CalendarEvent.expandATOLL(assignment, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          if ev.isAllDay {
            allDayByDay[key, default: []].append(ev)
          } else {
            timedByDay[key, default: []].append(ev)
          }
        }
      }
    }

    // GL-006 Phase 1.5h: anniversaries from Contacts framework. Apple
    // doesn't mirror these into EventKit; we synthesise yearly all-day
    // events so they land alongside birthdays in the agenda. They count as
    // "personal" content, so the `.atollOnly` filter hides them.
    if sourceFilter.includesSystem {
      for ann in anniversaryStore.anniversaries {
        for ev in CalendarEvent.expandAnniversary(ann, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          allDayByDay[key, default: []].append(ev)
        }
      }
    }

    // Build buckets: keep days with at least one event, plus today and
    // tomorrow as anchors even if empty (so the user always sees their
    // immediate context).
    var result: [DayBucket] = []
    var d = start
    while d < range.end {
      let allDay = allDayByDay[d] ?? []
      let timed = (timedByDay[d] ?? []).sorted { $0.startDate < $1.startDate }
      let isAnchor = cal.isDateInToday(d) || cal.isDateInTomorrow(d)
      if !allDay.isEmpty || !timed.isEmpty || isAnchor {
        result.append(DayBucket(
          id: d,
          date: d,
          allDayEvents: allDay,
          timedEvents: timed
        ))
      }
      d = cal.date(byAdding: .day, value: 1, to: d) ?? d
    }

    buckets = result
  }

  /// Collect distinct event colours per day across a 3-month window around
  /// the displayed month (prev / current / next). Drives the mini-calendar's
  /// coloured dot row beneath each day. Deduped per-day; first occurrence
  /// wins so the dot order is stable.
  private func rebuildMiniCalCounts() async {
    let cal = Calendar.current
    guard let monthStart = cal.dateInterval(of: .month, for: miniCalMonth)?.start,
          let windowStart = cal.date(byAdding: .month, value: -1, to: monthStart),
          let windowEnd = cal.date(byAdding: .month, value: 2, to: monthStart) else { return }
    let range = DateInterval(start: windowStart, end: windowEnd)

    let sysIds = enabledCalendarIds()
    let sysEvents: [EKEvent] = sourceFilter.includesSystem
      ? calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
      : []

    var colorsByDay: [Date: [Color]] = [:]
    var iconsByDay: [Date: [String]] = [:]

    func appendIfNew(_ color: Color, on key: Date) {
      var list = colorsByDay[key] ?? []
      // Dedupe by description — Color isn't Hashable on older SDKs, so we
      // compare its localised description for stable equality.
      if !list.contains(where: { $0.description == color.description }) {
        list.append(color)
      }
      colorsByDay[key] = list
    }

    func appendIcon(_ name: String, on key: Date) {
      var list = iconsByDay[key] ?? []
      if !list.contains(name) {
        list.append(name)
      }
      iconsByDay[key] = list
    }

    for ek in sysEvents {
      let key = cal.startOfDay(for: ek.startDate)
      let event = CalendarEvent.system(ek)
      appendIfNew(event.color, on: key)
      if let icon = event.specialIconName {
        appendIcon(icon, on: key)
      }
    }
    if sourceFilter.includesATOLL, atollEnabled {
      for assignment in atollLoader.assignments {
        for ev in CalendarEvent.expandATOLL(assignment, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          appendIfNew(ev.color, on: key)
          // ATOLL events don't surface special icons today (no birthday /
          // anniversary modelling), but the hook is here if we add it.
          if let icon = ev.specialIconName {
            appendIcon(icon, on: key)
          }
        }
      }
    }
    // Anniversaries surface as heart icons in the mini-month — same dot+icon
    // pattern as birthdays. The store's `anniversaries` list is empty until
    // the user grants Contacts access, so this is a no-op without consent.
    if sourceFilter.includesSystem {
      for ann in anniversaryStore.anniversaries {
        for ev in CalendarEvent.expandAnniversary(ann, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          appendIfNew(ev.color, on: key)
          if let icon = ev.specialIconName {
            appendIcon(icon, on: key)
          }
        }
      }
    }
    eventColorsByDay = colorsByDay
    specialIconsByDay = iconsByDay
  }

  private func isMultiDay(_ ev: CalendarEvent) -> Bool {
    let cal = Calendar.current
    let s = cal.startOfDay(for: ev.startDate)
    let e = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))
    return !cal.isDate(s, inSameDayAs: e)
  }
}
