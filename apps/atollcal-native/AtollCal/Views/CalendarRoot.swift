import SwiftUI
import AtollCore
import EventKit

struct CalendarRoot: View {
  @Environment(SystemCalendarStore.self) var calendarStore
  @State private var selectedView: CalendarViewKind = .week
  @State private var focusedDate: Date = Date()
  @State private var showingDatePicker = false
  @State private var showingSettings = false

  var body: some View {
    #if os(iOS)
    NavigationStack {
      content
        .navigationTitle(formattedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Heute") { focusedDate = Date() }
              .keyboardShortcut("t", modifiers: [.command])
          }
          ToolbarItem(placement: .principal) {
            Button {
              showingDatePicker = true
            } label: {
              Text(formattedTitle).font(.headline)
            }
            .sheet(isPresented: $showingDatePicker) {
              NavigationStack {
                DatePicker(
                  "Datum",
                  selection: $focusedDate,
                  displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Datum")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                  ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showingDatePicker = false }
                  }
                }
              }
              .presentationDetents([.medium, .large])
              .presentationDragIndicator(.visible)
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Picker("Ansicht", selection: $selectedView) {
              ForEach(CalendarViewKind.allCases) { kind in
                Text(kind.label).tag(kind)
              }
            }
            .pickerStyle(.segmented)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: {
              Image(systemName: "gearshape")
            }
          }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
    #else
    NavigationSplitView {
      List(CalendarViewKind.allCases, selection: $selectedView) { kind in
        Label(kind.label, systemImage: kind.systemImage).tag(kind)
      }
      .navigationTitle("AtollCal")
    } detail: {
      content
        .navigationTitle(formattedTitle)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { navigateBackward(); return .handled }
        .onKeyPress(.rightArrow) { navigateForward(); return .handled }
        .toolbar {
          ToolbarItem {
            Button("Heute") { focusedDate = Date() }
              .keyboardShortcut("t", modifiers: [.command])
          }
          ToolbarItem {
            Button {
              showingDatePicker = true
            } label: {
              Image(systemName: "calendar")
            }
            .popover(isPresented: $showingDatePicker) {
              DatePicker("Datum", selection: $focusedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            }
          }
          ToolbarItem {
            Button { showingSettings = true } label: {
              Image(systemName: "gearshape")
            }
          }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
    #endif
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 0) {
      if calendarStore.authorizationStatus != .fullAccess {
        PermissionBanner(store: calendarStore)
      }
      Group {
        switch selectedView {
        case .day:   DayView(date: $focusedDate)
        case .week:  WeekView(anchor: $focusedDate)
        case .month: MonthView(anchor: $focusedDate, onDayTap: { day in
          focusedDate = day
          selectedView = .day
        })
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func navigateBackward() {
    let cal = Calendar.current
    let component: Calendar.Component = {
      switch selectedView {
      case .day:   return .day
      case .week:  return .weekOfYear
      case .month: return .month
      }
    }()
    focusedDate = cal.date(byAdding: component, value: -1, to: focusedDate) ?? focusedDate
  }

  private func navigateForward() {
    let cal = Calendar.current
    let component: Calendar.Component = {
      switch selectedView {
      case .day:   return .day
      case .week:  return .weekOfYear
      case .month: return .month
      }
    }()
    focusedDate = cal.date(byAdding: component, value: 1, to: focusedDate) ?? focusedDate
  }

  private var formattedTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    switch selectedView {
    case .day:
      formatter.dateFormat = "EEEE, d. MMMM yyyy"
      return formatter.string(from: focusedDate)
    case .week:
      formatter.dateFormat = "'KW' w yyyy"
      return formatter.string(from: focusedDate)
    case .month:
      formatter.dateFormat = "MMMM yyyy"
      return formatter.string(from: focusedDate)
    }
  }
}

private struct PermissionBanner: View {
  let store: SystemCalendarStore

  var body: some View {
    VStack(spacing: 8) {
      Text("Kalender-Zugriff erforderlich")
        .font(.headline)
      Text("AtollCal braucht Zugriff auf deine System-Kalender (iCloud, Google etc.).")
        .font(.caption)
        .multilineTextAlignment(.center)
      Button("Zugriff erlauben") {
        Task { await store.requestAccess() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.yellow.opacity(0.15))
  }
}
