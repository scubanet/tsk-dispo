import SwiftUI
import AtollHub

/// Kalender-Modul im CoHub-Look: Header (Segmented Tag/Woche/Monat · Titel ·
/// ‹ Heute ›) ueber dem Zeitgitter bzw. Monatsraster.
struct CalendarModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CalendarStore()

  private static let title: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      header(store: store)
      Divider()
      content
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  private var reloadKey: String { "\(store.kind.rawValue)-\(store.anchor.timeIntervalSince1970)" }

  private func header(store: CalendarStore) -> some View {
    HStack(spacing: 12) {
      Picker("Ansicht", selection: $store.kind) {
        ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented).frame(maxWidth: 240)
      Spacer()
      Text(Self.title.string(from: store.anchor)).font(.system(size: 16, weight: .bold))
      Spacer()
      HStack(spacing: 2) {
        Button { store.step(-1) } label: { Image(systemName: "chevron.left") }
        Button("Heute") { store.goToToday() }
          .font(.system(size: 12.5, weight: .semibold))
        Button { store.step(1) } label: { Image(systemName: "chevron.right") }
      }
      .buttonStyle(.bordered)
      if store.loading { ProgressView().controlSize(.small) }
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var content: some View {
    switch store.kind {
    case .day:
      DayGridView(store: store, days: [store.calendar.startOfDay(for: store.anchor)])
    case .week:
      DayGridView(store: store, days: CalendarLayout.weekDays(of: store.anchor, calendar: store.calendar))
    case .month:
      MonthGridView(store: store, onPickDay: { day in
        store.anchor = day
        store.kind = .day
      })
    }
  }
}
