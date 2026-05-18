import SwiftUI
import AtollCore
import AtollDesign

/// Single-day timeline with a separate all-day zone above the hour grid.
///
/// - All-day zone caps at 3 visible rows; a "+N weitere" button opens a sheet
///   listing every all-day event for the day.
/// - Hour grid uses `TimeAxisGrid` with the iOS 26 `scrollPosition(id:)` API
///   so we open with "now" anchored at ~1/3 from the top (or 08:00 on days
///   that aren't today).
struct DayView: View {
  @Binding var date: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @Environment(\.locale) var locale

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var events: [CalendarEvent] = []
  @State private var selectedEvent: CalendarEvent?
  @State private var showingAllDaySheet: Bool = false
  @State private var scrolledHour: Int? = nil

  private let hourHeight: CGFloat = 60
  private let maxAllDayVisible: Int = 3

  var body: some View {
    VStack(spacing: 0) {
      allDayZone

      TimeAxisGrid(hourHeight: hourHeight,
                   scrolledHour: $scrolledHour) {
        ZStack(alignment: .topLeading) {
          ForEach(timedEvents) { ev in
            eventLayout(for: ev)
          }
          if Calendar.current.isDateInToday(date) {
            NowIndicator(hourHeight: hourHeight)
          }
        }
      }
    }
    .refreshable { await loadAll() }
    .task(id: date) {
      await loadAll()
      // Position scroll on every date change.
      scrolledHour = preferredOpeningHour
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .sheet(item: $selectedEvent) { ev in
      EventDetailSheet(event: ev)
    }
    .sheet(isPresented: $showingAllDaySheet) {
      AllDayListSheet(events: allDayEvents) { tapped in
        // Dismiss-then-present pattern. SwiftUI can't stack two .sheet
        // modifiers on the same View reliably, so we delay the second sheet.
        showingAllDaySheet = false
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          selectedEvent = tapped
        }
      }
    }
  }

  // MARK: - All-day zone

  @ViewBuilder
  private var allDayZone: some View {
    if !allDayEvents.isEmpty {
      let visible = Array(allDayEvents.prefix(maxAllDayVisible))
      let hidden = allDayEvents.count - visible.count

      VStack(spacing: 2) {
        ForEach(visible) { ev in
          allDayRow(ev)
        }
        if hidden > 0 {
          Button {
            showingAllDaySheet = true
          } label: {
            Text("+\(hidden) weitere")
              .font(.caption2)
              .fontWeight(.medium)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial)
      .clipShape(.rect(cornerRadius: 8))
      .padding(.horizontal, 6)
      .padding(.top, 4)
    }
  }

  private func allDayRow(_ ev: CalendarEvent) -> some View {
    HStack(spacing: 6) {
      Rectangle().fill(ev.color).frame(width: 3, height: 14)
      Text(ev.title).font(.caption).lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 2)
    .background(ev.color.opacity(0.15))
    .clipShape(.rect(cornerRadius: 4))
    .contentShape(Rectangle())
    .onTapGesture { selectedEvent = ev }
  }

  // MARK: - Timed event layout

  private func eventLayout(for ev: CalendarEvent) -> some View {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, dayEnd)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = max(15, evEnd.timeIntervalSince(evStart) / 60)
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = durationMinutes / 60.0 * Double(hourHeight)

    return EventBar(event: ev, measuredHeight: height, onTap: { selectedEvent = ev })
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .offset(y: yOffset)
  }

  // MARK: - Helpers

  private var allDayEvents: [CalendarEvent] { events.filter { $0.isAllDay } }
  private var timedEvents: [CalendarEvent] { events.filter { !$0.isAllDay } }

  /// Hour to scroll to on mount / date change:
  /// - today  → current hour (live)
  /// - other  → 08:00 (sensible workday start)
  private var preferredOpeningHour: Int {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
      return cal.component(.hour, from: Date())
    }
    return 8
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let range = DateInterval(start: dayStart, end: dayEnd)

    var combined: [CalendarEvent] = []

    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
    combined.append(contentsOf: sysEvents.map { .system($0) })

    if atollEnabled, case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start) ?? range.start,
        end:   cal.date(byAdding: .month, value: 1, to: range.end) ?? range.end
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates where cal.isDate(d, inSameDayAs: date) {
          combined.append(.atoll(assignment: assignment, dayDate: d))
        }
      }
    }

    events = combined.sorted(by: { $0.startDate < $1.startDate })
  }
}

// MARK: - All-day list sheet

private struct AllDayListSheet: View {
  let events: [CalendarEvent]
  let onTap: (CalendarEvent) -> Void
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      List(events) { ev in
        Button {
          onTap(ev)
        } label: {
          HStack(spacing: 8) {
            Rectangle().fill(ev.color).frame(width: 3, height: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(ev.title).foregroundStyle(.primary)
              if let loc = ev.location, !loc.isEmpty {
                Text(loc).font(.caption).foregroundStyle(.secondary)
              }
            }
            Spacer()
          }
        }
        .buttonStyle(.plain)
      }
      .navigationTitle("Ganztägige Termine")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
