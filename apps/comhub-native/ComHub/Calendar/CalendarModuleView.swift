import SwiftUI
import AtollHub

/// Kalender-Modul: Tag/Woche/Monat über die gemergten Hub-Events.
struct CalendarModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CalendarStore()

  private static let title: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    @Bindable var bindStore = store
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Picker("Ansicht", selection: $bindStore.kind) {
          ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)

        Spacer()

        Text(Self.title.string(from: store.anchor))
          .font(.headline)

        Spacer()

        Button { store.step(-1) } label: { Image(systemName: "chevron.left") }
        Button("Heute") { store.goToToday() }
        Button { store.step(1) } label: { Image(systemName: "chevron.right") }
        if store.loading { ProgressView().controlSize(.small) }
      }
      .padding(8)
      Divider()
      content
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  // Lädt neu, wenn sich Ansicht oder Anker ändert.
  private var reloadKey: String {
    "\(store.kind.rawValue)-\(store.anchor.timeIntervalSince1970)"
  }

  @ViewBuilder
  private var content: some View {
    switch store.kind {
    case .day:   DayColumnView(store: store)
    case .week:  WeekGridView(store: store)
    case .month: MonthGridView(store: store)
    }
  }
}
