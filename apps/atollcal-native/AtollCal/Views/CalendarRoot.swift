import SwiftUI
import AtollCore

struct CalendarRoot: View {
  @State private var selectedView: CalendarViewKind = .week
  @State private var focusedDate: Date = Date()

  var body: some View {
    #if os(iOS)
    NavigationStack {
      content
        .navigationTitle(formattedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Heute") { focusedDate = Date() }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Picker("Ansicht", selection: $selectedView) {
              ForEach(CalendarViewKind.allCases) { kind in
                Text(kind.label).tag(kind)
              }
            }
            .pickerStyle(.segmented)
          }
        }
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
        .toolbar {
          ToolbarItem {
            Button("Heute") { focusedDate = Date() }
          }
        }
    }
    #endif
  }

  @ViewBuilder
  private var content: some View {
    switch selectedView {
    case .day:   DayView(date: $focusedDate)
    case .week:  WeekView(anchor: $focusedDate)
    case .month: MonthView(anchor: $focusedDate)
    }
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
