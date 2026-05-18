import SwiftUI
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
  @Environment(AuthState.self) private var auth
  @Environment(\.locale) private var locale

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

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
  @State private var eventCountByDay: [Date: Int] = [:]

  /// Scroll-position binding for the agenda — drives auto-scroll to today on
  /// appear and when `focusedDate` changes via the mini-cal.
  @State private var scrolledBucketId: Date?

  var body: some View {
    VStack(spacing: 0) {
      MiniMonthCalendar(
        displayedMonth: miniCalMonth,
        focusedDate: $focusedDate,
        eventCountByDay: eventCountByDay,
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
    .background(.regularMaterial)
    .task {
      await rebuildAll()
      // Anchor the agenda at today on first appear.
      scrolledBucketId = Calendar.current.startOfDay(for: Date())
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await rebuildAll() }
    }
    .onChange(of: focusedDate) { _, newDate in
      let cal = Calendar.current
      if !cal.isDate(newDate, equalTo: miniCalMonth, toGranularity: .month) {
        miniCalMonth = newDate
        Task { await rebuildMiniCalCounts() }
      }
      // Scroll the agenda to the focused day if a bucket exists for it.
      let key = cal.startOfDay(for: newDate)
      if buckets.contains(where: { $0.id == key }) {
        withAnimation(.snappy) {
          scrolledBucketId = key
        }
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

    // ATOLL: trigger a reload covering the agenda range.
    if atollEnabled, case .signedIn(let user) = auth.status {
      await atollLoader.reload(for: user.legacyInstructorId, range: range)
    }

    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(
      in: range,
      calendarIds: sysIds.isEmpty ? nil : sysIds
    )

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

    if atollEnabled {
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates {
          let key = cal.startOfDay(for: d)
          if key >= range.start && key < range.end {
            allDayByDay[key, default: []].append(.atoll(assignment: assignment, dayDate: d))
          }
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

  /// Count events per day across a 3-month window around the displayed month
  /// (prev / current / next). Used for the mini-calendar's event dots.
  private func rebuildMiniCalCounts() async {
    let cal = Calendar.current
    guard let monthStart = cal.dateInterval(of: .month, for: miniCalMonth)?.start,
          let windowStart = cal.date(byAdding: .month, value: -1, to: monthStart),
          let windowEnd = cal.date(byAdding: .month, value: 2, to: monthStart) else { return }
    let range = DateInterval(start: windowStart, end: windowEnd)

    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(
      in: range,
      calendarIds: sysIds.isEmpty ? nil : sysIds
    )

    var counts: [Date: Int] = [:]
    for ek in sysEvents {
      let key = cal.startOfDay(for: ek.startDate)
      counts[key, default: 0] += 1
    }
    if atollEnabled {
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates {
          let key = cal.startOfDay(for: d)
          if key >= range.start && key < range.end {
            counts[key, default: 0] += 1
          }
        }
      }
    }
    eventCountByDay = counts
  }

  private func isMultiDay(_ ev: CalendarEvent) -> Bool {
    let cal = Calendar.current
    let s = cal.startOfDay(for: ev.startDate)
    let e = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))
    return !cal.isDate(s, inSameDayAs: e)
  }
}

// MARK: - Data structs

/// One day's worth of agenda content, used as a row in the scroll list.
struct DayBucket: Identifiable, Hashable {
  let id: Date
  let date: Date
  let allDayEvents: [CalendarEvent]
  let timedEvents: [CalendarEvent]

  static func == (lhs: DayBucket, rhs: DayBucket) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Mini month calendar

private struct MiniMonthCalendar: View {
  let displayedMonth: Date
  @Binding var focusedDate: Date
  let eventCountByDay: [Date: Int]
  let locale: Locale
  let onMonthChange: (Int) -> Void

  private let columnWidth: CGFloat = 30
  private let dayHeight: CGFloat = 34
  private let todayCircleSize: CGFloat = 22

  var body: some View {
    VStack(spacing: 6) {
      // Header
      HStack(spacing: 4) {
        Text(monthTitle)
          .font(.headline)
        Spacer()
        Button { onMonthChange(-1) } label: {
          Image(systemName: "chevron.left")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .help("Vormonat")
        Button { onMonthChange(1) } label: {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .help("Folgemonat")
      }

      // Column labels (KW + Mo–So)
      HStack(spacing: 0) {
        Text("KW")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.tertiary)
          .frame(width: columnWidth - 6, alignment: .center)
        ForEach(weekdayLabels, id: \.self) { lbl in
          Text(lbl)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: columnWidth, alignment: .center)
        }
      }

      // Week rows
      ForEach(monthWeeks, id: \.first) { week in
        if let first = week.first {
          HStack(spacing: 0) {
            Text("\(weekNumber(first))")
              .font(.system(size: 9))
              .foregroundStyle(.tertiary)
              .frame(width: columnWidth - 6, alignment: .center)
            ForEach(week, id: \.self) { day in
              dayCell(day)
                .frame(width: columnWidth, height: dayHeight)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func dayCell(_ day: Date) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let isSelected = cal.isDate(day, inSameDayAs: focusedDate) && !isToday
    let weekday = cal.component(.weekday, from: day)
    let isWeekend = weekday == 1 || weekday == 7
    let dotCount = min(3, eventCountByDay[cal.startOfDay(for: day)] ?? 0)

    VStack(spacing: 2) {
      ZStack {
        if isToday {
          Circle().fill(Color.accentColor).frame(width: todayCircleSize, height: todayCircleSize)
        } else if isSelected {
          Circle()
            .strokeBorder(Color.accentColor, lineWidth: 1.4)
            .frame(width: todayCircleSize, height: todayCircleSize)
        }
        Text("\(cal.component(.day, from: day))")
          .font(.system(size: 12, weight: isToday ? .bold : .regular))
          .foregroundStyle(dayNumberColor(
            isToday: isToday,
            isCurrentMonth: isCurrentMonth,
            isWeekend: isWeekend
          ))
      }
      HStack(spacing: 2) {
        ForEach(0..<dotCount, id: \.self) { _ in
          Circle()
            .fill(isToday ? Color.accentColor : Color.accentColor.opacity(0.55))
            .frame(width: 4, height: 4)
        }
      }
      .frame(height: 5)
    }
    .contentShape(Rectangle())
    .onTapGesture { focusedDate = day }
  }

  private func dayNumberColor(isToday: Bool, isCurrentMonth: Bool, isWeekend: Bool) -> Color {
    if isToday { return .white }
    if !isCurrentMonth { return Color.secondary.opacity(0.45) }
    if isWeekend { return Color.secondary.opacity(0.85) }
    return .primary
  }

  // MARK: - Date helpers

  private var monthTitle: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "MMMM yyyy"
    return f.string(from: displayedMonth)
  }

  private var weekdayLabels: [String] {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "EEEEE"  // single-letter / short weekday
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    guard let ref = cal.date(from: DateComponents(year: 2026, month: 1, day: 5)) else {
      return ["M", "D", "M", "D", "F", "S", "S"]
    }
    return (0..<7).compactMap { offset in
      cal.date(byAdding: .day, value: offset, to: ref).map { d in
        // Use 2-letter shorter form
        let g = DateFormatter()
        g.locale = locale
        g.dateFormat = "EE"
        return g.string(from: d)
      }
    }
  }

  private var monthWeeks: [[Date]] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let comps = cal.dateComponents([.year, .month], from: displayedMonth)
    guard let monthStart = cal.date(from: comps) else { return [] }
    let weekday = cal.component(.weekday, from: monthStart)
    let daysFromMonday = (weekday + 5) % 7
    guard let firstMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }
    return (0..<6).map { weekIdx in
      (0..<7).compactMap { dayIdx in
        cal.date(byAdding: .day, value: weekIdx * 7 + dayIdx, to: firstMonday)
      }
    }
  }

  private func weekNumber(_ d: Date) -> Int {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    return cal.component(.weekOfYear, from: d)
  }
}

// MARK: - Agenda list

private struct AgendaList: View {
  let buckets: [DayBucket]
  let locale: Locale
  @Binding var scrolledBucketId: Date?
  let onSelectDay: (Date) -> Void
  let onSelectEvent: (CalendarEvent) -> Void
  let onLoadMore: () -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        ForEach(buckets) { bucket in
          DayBucketRow(
            bucket: bucket,
            locale: locale,
            onSelectDay: onSelectDay,
            onSelectEvent: onSelectEvent
          )
          .id(bucket.id)
        }
        // Sentinel — triggers the next chunk to load when it scrolls into view.
        Color.clear
          .frame(height: 1)
          .onAppear { onLoadMore() }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 14)
      .scrollTargetLayout()
    }
    .scrollPosition(id: $scrolledBucketId, anchor: .top)
  }
}

private struct DayBucketRow: View {
  let bucket: DayBucket
  let locale: Locale
  let onSelectDay: (Date) -> Void
  let onSelectEvent: (CalendarEvent) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button { onSelectDay(bucket.date) } label: {
        HStack(spacing: 6) {
          Text(headerLabel)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
          Spacer(minLength: 0)
        }
      }
      .buttonStyle(.plain)

      ForEach(bucket.allDayEvents) { ev in
        AllDayChip(event: ev)
          .onTapGesture { onSelectEvent(ev) }
      }

      ForEach(bucket.timedEvents) { ev in
        TimedEventRow(event: ev, locale: locale)
          .onTapGesture { onSelectEvent(ev) }
      }
    }
  }

  private var isToday: Bool {
    Calendar.current.isDateInToday(bucket.date)
  }

  private var headerLabel: String {
    let cal = Calendar.current
    let f = DateFormatter()
    f.locale = locale
    if cal.isDateInToday(bucket.date) {
      f.dateFormat = "dd.MM.yy"
      return "HEUTE  ·  \(f.string(from: bucket.date))"
    }
    if cal.isDateInTomorrow(bucket.date) {
      f.dateFormat = "dd.MM.yy"
      return "MORGEN  ·  \(f.string(from: bucket.date))"
    }
    f.dateFormat = "EEEE  ·  dd.MM.yy"
    return f.string(from: bucket.date).uppercased()
  }
}

private struct AllDayChip: View {
  let event: CalendarEvent

  var body: some View {
    HStack(spacing: 6) {
      if let role = event.atollRole {
        Text(roleAbbrev(role))
          .font(.system(size: 8, weight: .heavy))
          .tracking(0.3)
          .foregroundStyle(.white)
          .padding(.horizontal, 5)
          .padding(.vertical, 1.5)
          .background(Color.atollRole(role))
          .clipShape(Capsule())
      }
      Text(event.title)
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .foregroundStyle(.primary)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(event.color.opacity(0.18))
    .overlay(
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(event.color.opacity(0.25), lineWidth: 0.5)
    )
    .clipShape(.rect(cornerRadius: 7))
    .contentShape(Rectangle())
  }

  private func roleAbbrev(_ role: AssignmentRole) -> String {
    switch role {
    case .haupt:  return "LEAD"
    case .assist: return "ASS"
    case .opfer:  return "STBY"
    case .dmt:    return "DMT"
    }
  }
}

private struct TimedEventRow: View {
  let event: CalendarEvent
  let locale: Locale

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(event.color)
        .frame(width: 7, height: 7)
      Text(timeString)
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: 42, alignment: .leading)
      Text(event.title)
        .font(.system(size: 12))
        .lineLimit(1)
        .foregroundStyle(.primary)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 1)
    .contentShape(Rectangle())
  }

  private var timeString: String {
    let f = DateFormatter()
    f.locale = locale
    f.timeStyle = .short
    return f.string(from: event.startDate)
  }
}

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
          Text(user.firstName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
          Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .semibold))
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
    Text(timezoneAbbrev)
      .font(.system(size: 11, weight: .semibold))
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
    Text(initialsString)
      .font(.system(size: 9, weight: .heavy))
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
