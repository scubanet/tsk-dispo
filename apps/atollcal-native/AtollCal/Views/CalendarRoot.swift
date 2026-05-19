import SwiftUI
import AtollCore
import AtollDesign
import EventKit

/// Root container for the calendar surface. Same toolbar on iOS and macOS:
///
///     [Today] [Title→Datepicker] [Day/Week/Month picker] [ProgressView?] [+] [Settings]
///
/// macOS keeps a `NavigationSplitView` so the Sidebar stays reachable for
/// power-users, but it boots collapsed (`.detailOnly`). Toggling it is a
/// toolbar button — the IA matches iOS otherwise.
struct CalendarRoot: View {
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @Environment(\.locale) var locale

  @AppStorage("calendarViewKind") private var selectedView: CalendarViewKind = .week
  @SceneStorage("focusedDateInterval") private var focusedDateInterval: Double = Date().timeIntervalSince1970
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all

  @State private var showingDatePicker = false
  @State private var showingSettings = false
  @State private var showingEventEditor = false

  #if os(macOS)
  /// Sidebar default: visible. The Fantastical-style sidebar is the primary
  /// navigation surface on macOS — collapse is a temporary "focus mode" via
  /// the toolbar sidebar-toggle button.
  @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
  @State private var sidebarSelectedEvent: CalendarEvent?
  #endif

  /// `@SceneStorage` only persists primitives — bridge through TimeInterval.
  private var focusedDate: Binding<Date> {
    Binding(
      get: { Date(timeIntervalSince1970: focusedDateInterval) },
      set: { focusedDateInterval = $0.timeIntervalSince1970 }
    )
  }

  // MARK: - Body

  var body: some View {
    #if os(macOS)
    NavigationSplitView(columnVisibility: $sidebarVisibility) {
      SidebarView(
        focusedDate: focusedDate,
        selectedEvent: $sidebarSelectedEvent,
        onOpenSettings: { showingSettings = true }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
    } detail: {
      mainContent
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(item: $sidebarSelectedEvent) { ev in
      EventDetailSheet(event: ev)
    }
    #else
    NavigationStack {
      mainContent
    }
    #endif
  }

  // MARK: - Main content + toolbar

  @ViewBuilder
  private var mainContent: some View {
    contentStack
      .navigationTitle(formattedTitle)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { sharedToolbar }
      .sheet(isPresented: $showingSettings) {
        SettingsView()
      }
      .sheet(isPresented: $showingEventEditor) {
        EventEditorSheet(initialDate: focusedDate.wrappedValue)
      }
      .sheet(isPresented: $showingDatePicker) {
        datePickerSheet
      }
      .focusable()
      .focusEffectDisabled()
      .onKeyPress(.leftArrow)  { navigate(by: -1); return .handled }
      .onKeyPress(.rightArrow) { navigate(by:  1); return .handled }
      .background(globalKeyboardShortcuts)
  }

  // MARK: - Toolbar (identical structure on iOS and macOS)

  @ToolbarContentBuilder
  private var sharedToolbar: some ToolbarContent {
    #if os(iOS)
    ToolbarItem(placement: .topBarLeading) { todayButton }
    ToolbarItem(placement: .principal) { titleButton }
    ToolbarItem(placement: .topBarTrailing) { viewPicker }
    if atollLoader.loading {
      ToolbarItem(placement: .topBarLeading) {
        ProgressView()
          .controlSize(.small)
          .symbolEffect(.pulse)
      }
    }
    ToolbarItem(placement: .topBarTrailing) { sourceFilterMenu }
    ToolbarItem(placement: .topBarTrailing) { addEventButton }
    ToolbarItem(placement: .topBarTrailing) { settingsButton }
    #else
    ToolbarItem(placement: .navigation) {
      Button {
        withAnimation(.snappy) {
          sidebarVisibility = (sidebarVisibility == .detailOnly) ? .all : .detailOnly
        }
      } label: {
        Image(systemName: "sidebar.leading")
      }
      .help("Sidebar ein-/ausblenden")
    }
    ToolbarItem { todayButton }
    ToolbarItem { titleButton }
    ToolbarItem { viewPicker }
    if atollLoader.loading {
      ToolbarItem {
        ProgressView()
          .controlSize(.small)
      }
    }
    ToolbarItem { sourceFilterMenu }
    ToolbarItem { addEventButton }
    ToolbarItem { settingsButton }
    #endif
  }

  private var sourceFilterMenu: some View {
    Menu {
      ForEach(CalendarSourceFilter.allCases) { f in
        Button {
          sourceFilter = f
          // Nudge all views to reload by broadcasting the EKEvent-changed
          // notification — they already react to it for system-calendar updates.
          NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
        } label: {
          if sourceFilter == f {
            Label(f.label, systemImage: "checkmark")
          } else {
            Label(f.label, systemImage: f.systemImage)
          }
        }
      }
    } label: {
      Image(systemName: sourceFilter == .all
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill")
    }
    .help("Kalenderquellen filtern")
  }

  // MARK: - Shared toolbar items

  private var todayButton: some View {
    Button {
      withAnimation(.snappy) {
        focusedDate.wrappedValue = Date()
      }
    } label: {
      Text("Heute")
    }
    .help("Springe zu heute (⌘T)")
  }

  private var titleButton: some View {
    Button { showingDatePicker = true } label: {
      Text(formattedTitle)
        .font(.headline)
        .foregroundStyle(.primary)
    }
    .buttonStyle(.plain)
    .help("Datum wählen")
  }

  private var viewPicker: some View {
    // Menu-style picker — compact and fully readable inside the iOS top bar
    // (segmented would truncate "Woche"/"Monat" on the iPhone).
    Menu {
      ForEach(CalendarViewKind.allCases) { kind in
        Button {
          withAnimation(.snappy) { selectedView = kind }
        } label: {
          Label(kind.label, systemImage: kind.systemImage)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(selectedView.label)
        Image(systemName: "chevron.down").font(.caption2)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
    .help("Tag / Woche / Monat (⌘1/2/3)")
  }

  private var addEventButton: some View {
    Button { showingEventEditor = true } label: {
      Image(systemName: "plus")
    }
    .help("Neuer Termin (⌘N)")
  }

  private var settingsButton: some View {
    Button { showingSettings = true } label: {
      Image(systemName: "gearshape")
    }
    .help("Einstellungen (⌘,)")
  }

  // MARK: - Sheets

  @ViewBuilder
  private var datePickerSheet: some View {
    VStack(spacing: 0) {
      // Always-visible header with close button — no toolbar trickery, no
      // dependency on detent-aware navigation chrome. Works identically on
      // iOS and macOS.
      HStack {
        Text("Datum wählen")
          .font(.headline)
        Spacer()
        Button {
          showingDatePicker = false
        } label: {
          Text("Fertig")
            .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      DatePicker(
        "Datum",
        selection: focusedDate,
        displayedComponents: .date
      )
      .datePickerStyle(.graphical)
      .environment(\.locale, locale)
      .labelsHidden()
      .padding(.horizontal, 12)
      .padding(.bottom, 16)

      Spacer(minLength: 0)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #if os(macOS)
    .frame(minWidth: 360, minHeight: 440)
    #endif
  }

  // MARK: - Hidden global keyboard shortcuts (⌘1/2/3, ⌘N, ⌘,, ⌘T)
  // SwiftUI Pickers don't expose per-segment shortcuts, so we mount an invisible
  // button group that captures the shortcuts at the view's focus scope.

  private var globalKeyboardShortcuts: some View {
    HStack(spacing: 0) {
      shortcutSink(key: "t") { focusedDate.wrappedValue = Date() }
      shortcutSink(key: "1") { selectedView = .day }
      shortcutSink(key: "2") { selectedView = .week }
      shortcutSink(key: "3") { selectedView = .month }
      shortcutSink(key: "4") { selectedView = .quarter }
      shortcutSink(key: "5") { selectedView = .year }
      shortcutSink(key: "n") { showingEventEditor = true }
      shortcutSink(key: ",") { showingSettings = true }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
    .accessibilityHidden(true)
  }

  private func shortcutSink(key: KeyEquivalent, action: @escaping @MainActor () -> Void) -> some View {
    Button(action: action) { EmptyView() }
      .keyboardShortcut(key, modifiers: .command)
  }

  // MARK: - Content stack with banners and view switching

  @ViewBuilder
  private var contentStack: some View {
    VStack(spacing: 8) {
      if let err = atollLoader.lastError {
        ErrorBanner(message: errorMessage(err)) {
          Task { await reloadAtollNow() }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
      }

      if calendarStore.authorizationStatus != .fullAccess {
        PermissionBanner(store: calendarStore)
          .padding(.horizontal, 12)
          .padding(.top, calendarStore.authorizationStatus == .fullAccess ? 0 : 8)
      }

      if shouldShowNoSourcesEmptyState {
        NoSourcesEmptyState()
      } else if shouldShowNoCalendarsEmptyState {
        NoCalendarsEmptyState()
      } else {
        ZStack {
          switch selectedView {
          case .day:
            DayView(date: focusedDate)
              .id(CalendarViewKind.day)
              .transition(.opacity.combined(with: .blurReplace))
          case .week:
            WeekView(anchor: focusedDate)
              .id(CalendarViewKind.week)
              .transition(.opacity.combined(with: .blurReplace))
          case .month:
            MonthView(anchor: focusedDate, onDayTap: { day in
              focusedDate.wrappedValue = day
              withAnimation(.snappy) { selectedView = .day }
            })
            .id(CalendarViewKind.month)
            .transition(.opacity.combined(with: .blurReplace))
          case .quarter:
            QuarterView(anchor: focusedDate, onSelectDay: { day in
              focusedDate.wrappedValue = day
              withAnimation(.snappy) { selectedView = .day }
            })
            .id(CalendarViewKind.quarter)
            .transition(.opacity.combined(with: .blurReplace))
          case .year:
            YearView(anchor: focusedDate, onSelectMonth: { month in
              focusedDate.wrappedValue = month
              withAnimation(.snappy) { selectedView = .month }
            })
            .id(CalendarViewKind.year)
            .transition(.opacity.combined(with: .blurReplace))
          }
        }
        .animation(.snappy(duration: 0.25), value: selectedView)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Helpers

  private func navigate(by delta: Int) {
    let cal = Calendar.current
    let (component, multiplier): (Calendar.Component, Int) = {
      switch selectedView {
      case .day:     return (.day, 1)
      case .week:    return (.weekOfYear, 1)
      case .month:   return (.month, 1)
      case .quarter: return (.month, 3)
      case .year:    return (.year, 1)
      }
    }()
    withAnimation(.snappy) {
      let new = cal.date(byAdding: component, value: delta * multiplier, to: focusedDate.wrappedValue)
      if let new { focusedDate.wrappedValue = new }
    }
  }

  private var formattedTitle: String {
    let formatter = DateFormatter()
    formatter.locale = locale
    switch selectedView {
    case .day:
      formatter.dateFormat = "EEEE, d. MMMM yyyy"
    case .week:
      formatter.dateFormat = "'KW' w yyyy"
    case .month:
      formatter.dateFormat = "MMMM yyyy"
    case .quarter:
      formatter.dateFormat = "'Q'Q yyyy"
    case .year:
      formatter.dateFormat = "yyyy"
    }
    return formatter.string(from: focusedDate.wrappedValue)
  }

  // MARK: - Empty states

  private var enabledCalendarIds: Set<String> {
    guard let data = enabledCalendarIdsJSON.data(using: .utf8),
          let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return Set(arr)
  }

  private var shouldShowNoCalendarsEmptyState: Bool {
    calendarStore.authorizationStatus == .fullAccess && calendarStore.calendars.isEmpty
  }

  private var shouldShowNoSourcesEmptyState: Bool {
    guard calendarStore.authorizationStatus == .fullAccess else { return false }
    guard !calendarStore.calendars.isEmpty else { return false }
    let allDisabled = !enabledCalendarIds.isEmpty && enabledCalendarIds.intersection(calendarStore.calendars.map { $0.calendarIdentifier }).isEmpty
    return allDisabled && !atollEnabled
  }

  private func errorMessage(_ err: Error) -> String {
    "ATOLL-Daten konnten nicht geladen werden: \(err.localizedDescription)"
  }

  private func reloadAtollNow() async {
    guard case .signedIn(let user) = auth.status else { return }
    let cal = Calendar.current
    let now = focusedDate.wrappedValue
    let start = cal.date(byAdding: .month, value: -2, to: now) ?? now
    let end   = cal.date(byAdding: .month, value:  2, to: now) ?? now
    await atollLoader.reload(for: user.legacyInstructorId,
                             range: DateInterval(start: start, end: end),
                             force: true)
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
  }
}

// MARK: - Permission Banner (Liquid Glass card)

private struct PermissionBanner: View {
  let store: SystemCalendarStore

  var body: some View {
    VStack(spacing: 10) {
      Label("Kalender-Zugriff erforderlich", systemImage: "calendar.badge.exclamationmark")
        .font(.headline)
        .foregroundStyle(.primary)
      Text("AtollCal braucht Zugriff auf deine System-Kalender (iCloud, Google etc.).")
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button("Zugriff erlauben") {
        Task { await store.requestAccess() }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .atollGlassCard(tint: .brandAmber)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(Color.brandAmber.opacity(0.45), lineWidth: 1)
    )
  }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
        .symbolEffect(.pulse)
      Text(message)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineLimit(2)
      Spacer(minLength: 8)
      Button("Erneut versuchen", action: retry)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .atollGlassCard(cornerRadius: 12, tint: .red)
  }
}

// MARK: - Empty State

private struct NoCalendarsEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .symbolEffect(.pulse)
      Text("Keine Kalender konfiguriert")
        .font(.headline)
      Text("Lege in den Systemeinstellungen mindestens einen Kalender an.")
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct NoSourcesEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "eye.slash")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .symbolEffect(.pulse)
      Text("Keine Quelle aktiv")
        .font(.headline)
      Text("Aktiviere mindestens eine Kalender-Quelle oder ATOLL in den Einstellungen.")
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
