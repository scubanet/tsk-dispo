import SwiftUI
import AtollCore
import AtollDesign
import EventKit
#if canImport(UIKit)
import UIKit
#endif

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

  /// GL-005 H1: Reduced Motion respect. `.blurReplace` and `.snappy` are
  /// motion-heavy; vestibular-sensitive users disable them via Settings →
  /// Accessibility → Motion. Read once at the top of the view; the helpers
  /// below substitute a plain opacity transition / no animation when set.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Motion-aware transition for the calendar view-kind switcher.
  /// Falls back to a plain crossfade when Reduce Motion is on.
  ///
  /// Why a hand-built modifier instead of `.blurReplace`?
  /// `.blurReplace` isn't a static member of `AnyTransition` — it lives on
  /// the `Transition` protocol as `BlurReplaceTransition`. With an explicit
  /// `AnyTransition` return type the compiler resolves `.blurReplace` against
  /// the wrong namespace and errors out. Bridging through `AnyTransition(_:)`
  /// isn't available on every SDK either. The custom `BlurReplaceModifier`
  /// below reproduces the same visual effect (radial blur + opacity) using
  /// the long-stable `AnyTransition.modifier(active:identity:)` API.
  private var viewSwitchTransition: AnyTransition {
    if reduceMotion {
      return .opacity
    }
    let blur = AnyTransition.modifier(
      active: BlurReplaceModifier(blurRadius: 12, opacity: 0),
      identity: BlurReplaceModifier(blurRadius: 0, opacity: 1)
    )
    return .opacity.combined(with: blur)
  }

  /// Motion-aware animation curve. `.snappy` is dropped when Reduce Motion
  /// is on; callers wrap their state mutation with this.
  private var motionAnimation: Animation? {
    reduceMotion ? nil : .snappy
  }

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
  #else
  /// GL-006 Phase 1: iPhone root layout is Mini-Month + Agenda (Fantastical-
  /// style). These two `@State` props back the iPhone-specific sheets:
  /// - `iPhoneSelectedEvent` mirrors macOS `sidebarSelectedEvent` — drives the
  ///   detail sheet when a user taps an agenda row.
  /// - `iPhonePresentedTimeView` opens Day/Week/Month/Quarter/Year as full-
  ///   screen sheets from the toolbar Menu, since they're no longer the root.
  @State private var iPhoneSelectedEvent: CalendarEvent?
  @State private var iPhonePresentedTimeView: CalendarViewKind?
  /// iPad in regular size class also gets the macOS-style sidebar via
  /// `NavigationSplitView`. Tracks visibility for parity with macOS.
  @State private var iPadSidebarVisibility: NavigationSplitViewVisibility = .all
  @State private var iPadSidebarSelectedEvent: CalendarEvent?
  /// Drives the iPad-regular vs. iPhone-compact layout fork in `body`.
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    // iPad regular size class → macOS-style NavigationSplitView with Sidebar.
    // iPhone (and iPad compact / Slide Over) → Mini-Month + Agenda root.
    if horizontalSizeClass == .regular {
      iPadRegularBody
    } else {
      iPhoneBody
    }
    #endif
  }

  // MARK: - iPad regular body (GL-006 Phase 1)

  #if !os(macOS)
  /// iPad with regular horizontal size class — same `NavigationSplitView` shape
  /// as macOS. Sidebar is the existing `SidebarView`; detail is the time-grid
  /// `mainContent`. Falls back to iPhone layout when compact (portrait Split
  /// View, Slide Over).
  private var iPadRegularBody: some View {
    NavigationSplitView(columnVisibility: $iPadSidebarVisibility) {
      SidebarView(
        focusedDate: focusedDate,
        selectedEvent: $iPadSidebarSelectedEvent,
        onOpenSettings: { showingSettings = true }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
    } detail: {
      NavigationStack {
        mainContent
      }
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(item: $iPadSidebarSelectedEvent) { ev in
      EventDetailSheet(event: ev)
    }
  }
  #endif

  // MARK: - iPhone body (GL-006 Phase 1)

  #if !os(macOS)
  /// Fantastical-style iPhone root. Mini-Month + Agenda is the home screen;
  /// Day/Week/Month/Quarter/Year are reachable as sheets from the toolbar Menu.
  private var iPhoneBody: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Keep the banners (error + permission) on top so they remain visible
        // above the Mini-Month + Agenda. Empty states still take over the full
        // body when no events / no sources are available.
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
          IPhoneRootView(
            focusedDate: focusedDate,
            selectedEvent: $iPhoneSelectedEvent
          )
        }
      }
      .navigationTitle(formattedTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { iPhoneToolbar }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        iPhoneBottomBar
      }
      .sheet(isPresented: $showingSettings) {
        SettingsView()
      }
      .sheet(isPresented: $showingEventEditor) {
        EventEditorSheet(initialDate: focusedDate.wrappedValue)
      }
      .sheet(isPresented: $showingDatePicker) {
        datePickerSheet
      }
      .sheet(item: $iPhoneSelectedEvent) { ev in
        EventDetailSheet(event: ev)
      }
      .sheet(item: $iPhonePresentedTimeView) { kind in
        timeGridSheet(for: kind)
      }
      .focusable()
      .focusEffectDisabled()
      .onKeyPress(.leftArrow)  { navigate(by: -1); return .handled }
      .onKeyPress(.rightArrow) { navigate(by:  1); return .handled }
      .background(globalKeyboardShortcuts)
    }
  }

  /// GL-006 Phase 1.5c — Fantastical-style top bar: just Heute + a loading
  /// pulse. All secondary actions (view kinds, source filter, add, settings,
  /// sign out) moved to the floating bottom bar.
  @ToolbarContentBuilder
  private var iPhoneToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) { todayButton }
    ToolbarItem(placement: .principal) { titleButton }
    if atollLoader.loading {
      ToolbarItem(placement: .topBarTrailing) {
        ProgressView()
          .controlSize(.small)
          .symbolEffect(.pulse)
      }
    }
  }

  // MARK: - iPhone bottom bar (GL-006 Phase 1.5c)

  /// Two floating capsule pills at the bottom edge — left holds the
  /// hamburger menu and the user-account chip; right holds the disabled
  /// search placeholder and the `+`-new-event button. Matches Fantastical's
  /// iOS chrome and aligns with iOS 26's Liquid-Glass capsule controls.
  private var iPhoneBottomBar: some View {
    HStack(spacing: 12) {
      leftBottomPill
      Spacer()
      rightBottomPill
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
    .accessibilityElement(children: .contain)
  }

  /// Left pill: hamburger menu + account chip.
  @ViewBuilder
  private var leftBottomPill: some View {
    HStack(spacing: 4) {
      bottomHamburgerMenu
      if case .signedIn(let user) = auth.status {
        bottomAccountChip(user: user)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.regularMaterial, in: Capsule())
    .overlay(
      Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
    )
  }

  /// Right pill: search placeholder + `+` add event.
  @ViewBuilder
  private var rightBottomPill: some View {
    HStack(spacing: 4) {
      // Search is a placeholder for now — disabled until we ship the
      // search Phase 2.5. The icon stays visible so the layout matches
      // Fantastical and so we don't move buttons around when search lands.
      Button { } label: {
        Image(systemName: "magnifyingglass")
          .font(.title3)
          .frame(width: 40, height: 36)
          .foregroundStyle(.tertiary)
      }
      .disabled(true)
      .accessibilityHidden(true)

      Button { showingEventEditor = true } label: {
        Image(systemName: "plus")
          .font(.title3.weight(.semibold))
          .frame(width: 40, height: 36)
          .foregroundStyle(.primary)
      }
      .accessibilityLabel("Neuer Termin")
      .accessibilityHint("Öffnet den Editor für einen neuen Termin")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.regularMaterial, in: Capsule())
    .overlay(
      Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
    )
  }

  /// Hamburger menu — collects all the "secondary nav" items that used to
  /// live in the top toolbar trailing edge.
  @ViewBuilder
  private var bottomHamburgerMenu: some View {
    Menu {
      // Time-grid views
      Section("Ansicht") {
        ForEach(CalendarViewKind.allCases) { kind in
          Button {
            iPhonePresentedTimeView = kind
          } label: {
            Label(kind.label, systemImage: kind.systemImage)
          }
        }
      }
      // Source filter
      Section("Kalenderquellen") {
        ForEach(CalendarSourceFilter.allCases) { f in
          Button {
            sourceFilter = f
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
          } label: {
            if sourceFilter == f {
              Label(f.label, systemImage: "checkmark")
            } else {
              Label(f.label, systemImage: f.systemImage)
            }
          }
        }
      }
      // Settings
      Section {
        Button {
          showingSettings = true
        } label: {
          Label("Einstellungen", systemImage: "gearshape")
        }
      }
    } label: {
      Image(systemName: "line.3.horizontal")
        .font(.title3.weight(.medium))
        .frame(width: 40, height: 36)
        .foregroundStyle(.primary)
    }
    .menuStyle(.borderlessButton)
    .accessibilityLabel("Mehr")
    .accessibilityHint("Öffnet Ansichten, Kalenderquellen und Einstellungen")
  }

  /// Account chip — avatar + first name. Tapping opens a small menu with
  /// settings + sign-out (settings is duplicated for discoverability).
  @ViewBuilder
  private func bottomAccountChip(user: CurrentUser) -> some View {
    Menu {
      Button {
        showingSettings = true
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
        Text(initials(for: user))
          .font(.system(size: 11, weight: .heavy))
          .minimumScaleFactor(0.75)
          .lineLimit(1)
          .foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(Color.padiLevel(user.padiLevel))
          .clipShape(Circle())
        Text(user.firstName)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 4)
    }
    .menuStyle(.borderlessButton)
    .accessibilityLabel("Account \(user.firstName)")
  }

  private func initials(for user: CurrentUser) -> String {
    if let i = user.initials, !i.isEmpty { return i.uppercased() }
    let f = user.firstName.first.map(String.init) ?? ""
    let l = user.lastName.first.map(String.init) ?? ""
    return (f + l).uppercased()
  }

  /// Builds the time-grid view that a `CalendarViewKind` represents, wrapped
  /// in its own `NavigationStack` so it gets a Close button and title.
  @ViewBuilder
  private func timeGridSheet(for kind: CalendarViewKind) -> some View {
    NavigationStack {
      Group {
        switch kind {
        case .day:
          DayView(date: focusedDate)
        case .week:
          WeekView(anchor: focusedDate)
        case .month:
          MonthView(anchor: focusedDate, onDayTap: { day in
            focusedDate.wrappedValue = day
            iPhonePresentedTimeView = .day
          })
        case .quarter:
          QuarterView(anchor: focusedDate, onSelectDay: { day in
            focusedDate.wrappedValue = day
            iPhonePresentedTimeView = .day
          })
        case .year:
          YearView(anchor: focusedDate, onSelectMonth: { month in
            focusedDate.wrappedValue = month
            iPhonePresentedTimeView = .month
          })
        }
      }
      .navigationTitle(kind.label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Fertig") { iPhonePresentedTimeView = nil }
        }
      }
    }
  }
  #endif

  // MARK: - Main content + toolbar

  @ViewBuilder
  private var mainContent: some View {
    contentStack
      .navigationTitle(formattedTitle)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { sharedToolbar }
      #if !os(macOS)
      // macOS uses the standard `Settings { ... }` scene declared in AtollCalApp;
      // on iOS / iPadOS Settings opens as a sheet because the OS has no
      // dedicated Settings-window concept here.
      .sheet(isPresented: $showingSettings) {
        SettingsView()
      }
      #endif
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
        withAnimation(motionAnimation) {
          sidebarVisibility = (sidebarVisibility == .detailOnly) ? .all : .detailOnly
        }
      } label: {
        Image(systemName: "sidebar.leading")
      }
      .help("Sidebar ein-/ausblenden")
      .accessibilityLabel(sidebarVisibility == .detailOnly ? "Sidebar einblenden" : "Sidebar ausblenden")
      .accessibilityHint("Zeigt oder versteckt die linke Seitenleiste")
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
    .accessibilityLabel("Kalenderquellen filtern")
    .accessibilityValue(sourceFilter.label)
    .accessibilityHint("Filtert die angezeigten Kalenderquellen")
  }

  // MARK: - Shared toolbar items

  private var todayButton: some View {
    Button {
      withAnimation(motionAnimation) {
        focusedDate.wrappedValue = Date()
      }
    } label: {
      Text("Heute")
    }
    .help("Springe zu heute (⌘T)")
    .accessibilityLabel("Heute")
    .accessibilityHint("Springt zum heutigen Datum")
  }

  private var titleButton: some View {
    Button { showingDatePicker = true } label: {
      Text(formattedTitle)
        .font(.headline)
        .foregroundStyle(.primary)
    }
    .buttonStyle(.plain)
    .help("Datum wählen")
    .accessibilityLabel("Aktuelles Datum: \(formattedTitle)")
    .accessibilityHint("Öffnet die Datumsauswahl")
  }

  private var viewPicker: some View {
    // Menu-style picker — compact and fully readable inside the iOS top bar
    // (segmented would truncate "Woche"/"Monat" on the iPhone).
    Menu {
      ForEach(CalendarViewKind.allCases) { kind in
        Button {
          withAnimation(motionAnimation) { selectedView = kind }
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
    .accessibilityLabel("Ansicht: \(selectedView.label)")
    .accessibilityHint("Wählt die Kalenderansicht (Tag, Woche, Monat, Quartal, Jahr)")
  }

  private var addEventButton: some View {
    Button { showingEventEditor = true } label: {
      Image(systemName: "plus")
    }
    .help("Neuer Termin (⌘N)")
    .accessibilityLabel("Neuer Termin")
    .accessibilityHint("Öffnet den Editor für einen neuen Termin")
  }

  private var settingsButton: some View {
    #if os(macOS)
    // On macOS, SettingsLink opens the Settings scene declared in AtollCalApp —
    // wires to the same window that the system "AtollCal → Settings…" menu
    // item and ⌘, open.
    SettingsLink {
      Image(systemName: "gearshape")
    }
    .help("Einstellungen (⌘,)")
    .accessibilityLabel("Einstellungen")
    .accessibilityHint("Öffnet das Einstellungen-Fenster")
    #else
    Button { showingSettings = true } label: {
      Image(systemName: "gearshape")
    }
    .help("Einstellungen (⌘,)")
    .accessibilityLabel("Einstellungen")
    .accessibilityHint("Öffnet die Einstellungen")
    #endif
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
      #if !os(macOS)
      // ⌘, on macOS is auto-wired to the `Settings { ... }` scene in AtollCalApp;
      // installing our own sink would conflict.
      shortcutSink(key: ",") { showingSettings = true }
      #endif
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
              .transition(viewSwitchTransition)
          case .week:
            WeekView(anchor: focusedDate)
              .id(CalendarViewKind.week)
              .transition(viewSwitchTransition)
          case .month:
            MonthView(anchor: focusedDate, onDayTap: { day in
              focusedDate.wrappedValue = day
              withAnimation(motionAnimation) { selectedView = .day }
            })
            .id(CalendarViewKind.month)
            .transition(viewSwitchTransition)
          case .quarter:
            QuarterView(anchor: focusedDate, onSelectDay: { day in
              focusedDate.wrappedValue = day
              withAnimation(motionAnimation) { selectedView = .day }
            })
            .id(CalendarViewKind.quarter)
            .transition(viewSwitchTransition)
          case .year:
            YearView(anchor: focusedDate, onSelectMonth: { month in
              focusedDate.wrappedValue = month
              withAnimation(motionAnimation) { selectedView = .month }
            })
            .id(CalendarViewKind.year)
            .transition(viewSwitchTransition)
          }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: selectedView)
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
    withAnimation(motionAnimation) {
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
  /// GL-005 L2: Opens the System Calendar settings so the user can grant
  /// access / add an account. The exact URL differs per platform —
  /// see `systemCalendarSettingsURL`.
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 12) {
      // GL-005 H2: Hero icon stays at a fixed 48 pt — empty-state SF Symbols
      // are illustrative and intentionally larger than body copy. Surrounding
      // labels (`.headline`/`.callout`) carry the Dynamic-Type scaling.
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .symbolEffect(.pulse)
        .accessibilityHidden(true)
      Text("Keine Kalender konfiguriert")
        .font(.headline)
      Text("Lege in den Systemeinstellungen mindestens einen Kalender an.")
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)

      // GL-005 L2: Direct action — opens the system-level setting so the
      // user doesn't have to hunt for it in Settings → Privacy.
      Button {
        if let url = systemCalendarSettingsURL {
          openURL(url)
        }
      } label: {
        Label("System-Einstellungen öffnen", systemImage: "gear")
      }
      .buttonStyle(.bordered)
      .padding(.top, 4)
      .accessibilityHint("Öffnet die System-Einstellungen für Kalender-Zugriff")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Platform-specific deep link into the system's Calendar privacy / settings
  /// surface. `openURL` accepts these schemes on both macOS and iOS.
  private var systemCalendarSettingsURL: URL? {
    #if os(macOS)
    // macOS: jump to the Calendar privacy pane.
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    #else
    // iOS: deep-link into this app's row inside Settings.
    URL(string: UIApplication.openSettingsURLString)
    #endif
  }
}

private struct NoSourcesEmptyState: View {
  #if os(macOS)
  @Environment(\.openSettings) private var openSettings
  #endif
  @State private var showingSettings = false

  var body: some View {
    VStack(spacing: 12) {
      // GL-005 H2: Hero icon — see note in NoCalendarsEmptyState above.
      Image(systemName: "eye.slash")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .symbolEffect(.pulse)
        .accessibilityHidden(true)
      Text("Keine Quelle aktiv")
        .font(.headline)
      Text("Aktiviere mindestens eine Kalender-Quelle oder ATOLL in den Einstellungen.")
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)

      // GL-005 L2: Direct action — opens the in-app Settings where source
      // toggles live. On macOS this routes to the Settings scene; on iOS we
      // present the existing SettingsView as a sheet (matches the toolbar
      // gear behavior).
      #if os(macOS)
      Button {
        openSettings()
      } label: {
        Label("Einstellungen öffnen", systemImage: "gearshape")
      }
      .buttonStyle(.bordered)
      .padding(.top, 4)
      .accessibilityHint("Öffnet das Einstellungen-Fenster")
      #else
      Button {
        showingSettings = true
      } label: {
        Label("Einstellungen öffnen", systemImage: "gearshape")
      }
      .buttonStyle(.bordered)
      .padding(.top, 4)
      .accessibilityHint("Öffnet die Einstellungen")
      .sheet(isPresented: $showingSettings) {
        SettingsView()
      }
      #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Transition helpers (GL-005 H1)

/// Custom view modifier that reproduces the visual of SwiftUI's
/// `.blurReplace` transition (radial blur fading in/out alongside opacity).
///
/// Used by `CalendarRoot.viewSwitchTransition` because `AnyTransition` has
/// no static `.blurReplace` member on the SDK this project compiles
/// against — and we need a transition value that can flow through an
/// `AnyTransition`-typed conditional without protocol-resolution snags.
private struct BlurReplaceModifier: ViewModifier {
  let blurRadius: CGFloat
  let opacity: Double

  func body(content: Content) -> some View {
    content
      .blur(radius: blurRadius)
      .opacity(opacity)
  }
}
