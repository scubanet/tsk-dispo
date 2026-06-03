import SwiftUI
import AtollHub
import EventKit

/// Kalender-Modul im CoHub-Look: Header (Segmented Tag/Woche/Monat · Titel ·
/// ‹ Heute ›) ueber dem Zeitgitter bzw. Monatsraster.
struct CalendarModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CalendarStore()
  @State private var sources: CalendarSourcesStore?
  @State private var showFilter = false
  @State private var editingEvent: UnifiedEvent?
  @State private var showCreate = false

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
    .task(id: reloadKey) {
      if sources == nil { sources = CalendarSourcesStore(store: EKEventStore()) }
      store.enabledCalendarIds = sources?.enabledIds
      hub.disabledCalendarIds = sources?.disabledIds ?? []
      await store.reload(using: hub)
    }
    .sheet(isPresented: $showCreate) {
      EventEditSheet(existing: nil, sources: sources, onSave: { draft in
        Task { await store.create(draft, using: hub) }
      }, onDelete: nil)
    }
    .sheet(item: $editingEvent) { ev in
      // Atoll-Events sind CRM-Daten (nur Lesen); nur Apple-Termine sind editierbar.
      if ev.source.type == .atoll {
        EventReadOnlySheet(event: ev)
      } else {
        EventEditSheet(existing: ev, sources: sources, onSave: { draft in
          Task { await store.update(id: ev.id, with: draft, using: hub) }
        }, onDelete: {
          Task { await store.delete(id: ev.id, using: hub) }
        })
      }
    }
  }

  private var reloadKey: String { "\(store.kind.rawValue)-\(store.anchor.timeIntervalSince1970)" }

  private func applyFilter() {
    store.enabledCalendarIds = sources?.enabledIds
    hub.disabledCalendarIds = sources?.disabledIds ?? []
    Task { await store.reload(using: hub) }
  }

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
      Button { showFilter.toggle() } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
        .buttonStyle(.bordered)
        .popover(isPresented: $showFilter) {
          Group {
            if let sources { CalendarFilterPopover(store: sources) { applyFilter() } }
          }
          #if os(iOS)
          .presentationCompactAdaptation(.popover)
          #endif
        }
      Button { showCreate = true } label: { Image(systemName: "plus") }
        .buttonStyle(.bordered)
      if store.loading { ProgressView().controlSize(.small) }
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var content: some View {
    switch store.kind {
    case .day:
      DayGridView(store: store, days: [store.calendar.startOfDay(for: store.anchor)],
                  onEventTap: { editingEvent = $0 })
    case .week:
      DayGridView(store: store, days: CalendarLayout.weekDays(of: store.anchor, calendar: store.calendar),
                  onEventTap: { editingEvent = $0 })
    case .month:
      MonthGridView(store: store, onPickDay: { day in
        store.anchor = day
        store.kind = .day
      })
    }
  }
}
