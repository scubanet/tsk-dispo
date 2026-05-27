import SwiftUI
import EventKit
import AtollCore
import AtollDesign

/// Fantastical-style sidebar for the macOS calendar.
///
/// Layout (top to bottom):
/// - **MiniMonthCalendar** — 6 × 7 grid with KW column, today marker, event-dots.
///   Tap a day → updates `focusedDate`. Chevrons step the displayed month.
/// - **AgendaList** — vertically scrolling list of day buckets. Each bucket has
///   a tappable header (label + date) that jumps `focusedDate`, all-day chips,
///   and one row per timed event. Endless scroll: every 30-day chunk is loaded
///   lazily when the sentinel row appears at the bottom.
///
/// The sidebar is **synced** with the main view via `focusedDate`. Changing
/// `focusedDate` elsewhere in the app updates the mini-cal's displayed month;
/// tapping a day in the sidebar feeds back into `focusedDate`.
///
/// All-day, multi-day, and ATOLL events appear as **chips**. Single-day timed
/// events appear as a bulleted row with the start time.
struct SidebarView: View {
  @Binding var focusedDate: Date
  @Binding var selectedEvent: CalendarEvent?
  /// Triggered by the footer's account menu "Einstellungen" item — opens the
  /// same Settings sheet that the main-toolbar gear button uses.
  let onOpenSettings: () -> Void

  @Environment(SystemCalendarStore.self) private var calendarStore
  @Environment(AtollEventLoader.self) private var atollLoader
  @Environment(ContactsAnniversaryStore.self) private var anniversaryStore
  @Environment(AuthState.self) private var auth
  @Environment(\.locale) private var locale
  /// GL-005 H1: Reduced Motion respect — drops the `.snappy` curve on the
  /// agenda auto-scroll for vestibular-sensitive users.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all

  /// Month displayed in the mini-calendar header. Driven by `focusedDate`
  /// changes (synced) but can also be advanced via chevrons; chevrons set
  /// `focusedDate` so the main view follows.
  @State private var miniCalMonth: Date = Calendar.current.startOfDay(for: Date())

  /// Agenda horizon — total days loaded forward from today. Grows as the
  /// endless-scroll sentinel triggers.
  @State private var agendaHorizonDays: Int = 30

  /// Snapshot of buckets for the agenda. Rebuilt whenever events change.
  @State private var buckets: [DayBucket] = []

  /// Event count per day (start-of-day) for the mini-cal's three months window.
  /// Drives the dots beneath day numbers.
  /// Per-day list of distinct event colours (max 3, deduped). Drives the
  /// coloured dots beneath each day number in the mini-month.
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
            // Mirror to main view per user spec (synchronous).
            focusedDate = new
          }
        }
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 10)

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

      Divider()
      SidebarFooter(onOpenSettings: onOpenSettings)
    }
    .frame(maxHeight: .infinity)
    // GL-005 M2: Sidebar background uses Apple's native `.regularMaterial`
    // per HIG. Glass-card tokens are for floating content, not for the
    // sidebar chrome itself.
    .background(.regularMaterial)
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

// MARK: - Extracted components
//
// `DayBucket`, `MiniMonthCalendar`, `AgendaList`, `DayBucketRow`, `AllDayChip`,
// `TimedEventRow` were extracted in Pragmatic Phase 1 (GL-006) so the iPhone
// root layout can reuse them alongside the macOS sidebar.
//
// See:
// - `Views/Components/MiniMonthCalendar.swift`
// - `Views/Components/AgendaList.swift` (carries the `DayBucket` struct too)

// MARK: - Footer

private struct SidebarFooter: View {
  let onOpenSettings: () -> Void

  @Environment(AuthState.self) private var auth
  @Environment(\.locale) private var locale

  var body: some View {
    HStack(spacing: 8) {
      accountPill
      Spacer(minLength: 4)
      timezonePill
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  // MARK: Account pill

  @ViewBuilder
  private var accountPill: some View {
    if case .signedIn(let user) = auth.status {
      Menu {
        Button {
          onOpenSettings()
        } label: {
          Label("Einstellungen", systemImage: "gearshape")
        }
        Divider()
        Button(role: .destructive) {
          Task { await auth.signOut() }
        } label: {
          Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
        }
      } label: {
        HStack(spacing: 6) {
          AvatarCircle(user: user)
          // GL-005 H2: Dynamic Type-aware menu label.
          Text(user.firstName)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
          Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quinary, in: Capsule())
      }
      .buttonStyle(.plain)
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
    } else {
      EmptyView()
    }
  }

  // MARK: Timezone pill

  private var timezonePill: some View {
    // GL-005 H2: Dynamic Type-aware. Capsule wraps text so it grows with AX.
    Text(timezoneAbbrev)
      .font(.caption.weight(.semibold))
      .tracking(0.3)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.quinary, in: Capsule())
  }

  private var timezoneAbbrev: String {
    TimeZone.current.localizedName(for: .shortGeneric, locale: locale)
      ?? TimeZone.current.abbreviation()
      ?? TimeZone.current.identifier
  }
}

private struct AvatarCircle: View {
  let user: CurrentUser

  private let size: CGFloat = 20

  var body: some View {
    // GL-005 H2: Avatar is a fixed 20 × 20 circle — Dynamic-Type expansion
    // would overflow the bounds. Keep the system size and shrink with
    // `.minimumScaleFactor` if AX users hit two-character initials.
    Text(initialsString)
      .font(.system(size: 9, weight: .heavy))
      .minimumScaleFactor(0.75)
      .lineLimit(1)
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Color.padiLevel(user.padiLevel))
      .clipShape(Circle())
  }

  private var initialsString: String {
    if let i = user.initials, !i.isEmpty { return i.uppercased() }
    let f = user.firstName.first.map(String.init) ?? ""
    let l = user.lastName.first.map(String.init) ?? ""
    return (f + l).uppercased()
  }
}
