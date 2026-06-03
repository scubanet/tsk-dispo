import SwiftUI
import AtollHub

/// Globale Suche als Sheet: ein Suchfeld (Autofokus) + gruppierte, gerankte
/// Treffer ueber Kontakte/Termine/Aufgaben. Tippen springt ins jeweilige Modul.
struct SearchOverlay: View {
  let store: SearchStore
  let onOpen: (ComHubModule) -> Void

  @Environment(\.dismiss) private var dismiss
  @FocusState private var focused: Bool

  var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      header($store)
      Divider()
      content
    }
    #if os(macOS)
    .frame(minWidth: 520, idealWidth: 600, minHeight: 440, idealHeight: 560)
    #endif
    #if os(iOS)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    #endif
    .onAppear { focused = true }
  }

  // MARK: - Kopf (Suchfeld + Schliessen)

  @ViewBuilder
  private func header(_ store: Bindable<SearchStore>) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("Suchen…", text: store.query)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .focused($focused)
        #if os(iOS)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        #endif
        .onSubmit { openFirstHit() }
      if !store.wrappedValue.query.isEmpty {
        IconButton(systemName: "xmark.circle.fill", size: 14) { store.wrappedValue.query = "" }
          .foregroundStyle(.tertiary)
      }
      Button("Schliessen") { dismiss() }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .keyboardShortcut(.cancelAction)
    }
    .padding(.horizontal, 16).padding(.vertical, 14)
  }

  // MARK: - Inhalt

  @ViewBuilder
  private var content: some View {
    if store.loading && !store.ready {
      VStack { Spacer(); ProgressView(); Spacer() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      hint
    } else if !store.hasAnyHit {
      ContentUnavailableView("Keine Treffer", systemImage: "magnifyingglass")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          group("Kontakte", hits: store.contactHits)
          group("Termine", hits: store.eventHits)
          group("Aufgaben", hits: store.taskHits)
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var hint: some View {
    VStack(spacing: 10) {
      Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(.tertiary)
      Text("Tippe, um Kontakte, Termine und Aufgaben zu durchsuchen.")
        .font(.system(size: 13.5)).foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Gruppen + Zeilen

  @ViewBuilder
  private func group(_ title: String, hits: [SearchHit]) -> some View {
    if !hits.isEmpty {
      HStack(spacing: 6) {
        Text(title.uppercased())
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.tertiary)
        Text("\(hits.count)")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.quaternary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

      ForEach(hits) { hit in
        Button { open(hit) } label: { row(hit) }
          .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder
  private func row(_ hit: SearchHit) -> some View {
    Group {
      switch hit {
      case .contact(let c, _): contactRow(c)
      case .event(let e, _):   eventRow(e)
      case .task(let t, _):    taskRow(t)
      }
    }
    .contentShape(Rectangle())
  }

  private func contactRow(_ c: MergedContact) -> some View {
    HStack(spacing: 11) {
      CoAvatar(name: c.displayName, size: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(c.displayName).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
        HStack(spacing: 6) {
          ForEach(c.sources, id: \.self) { src in
            Text(src == .atoll ? "Atoll" : "Apple")
              .font(.system(size: 10.5, weight: .medium))
              .padding(.horizontal, 6).padding(.vertical, 1)
              .foregroundStyle(.secondary)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
          }
          if let detail = c.emails.first ?? c.phones.first {
            Text(detail).font(.system(size: 11.5)).foregroundStyle(.tertiary).lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16).padding(.vertical, 7)
  }

  private func eventRow(_ e: UnifiedEvent) -> some View {
    let color = e.colorHex.flatMap(Color.init(hex:)) ?? (e.source.type == .atoll ? CoColor.accent : .secondary)
    return HStack(spacing: 11) {
      RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(e.title.isEmpty ? "(ohne Titel)" : e.title)
          .font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
        HStack(spacing: 6) {
          Text(Self.eventDate(e)).font(.system(size: 11.5)).foregroundStyle(.tertiary)
          if let loc = e.location, !loc.isEmpty {
            Text("· \(loc)").font(.system(size: 11.5)).foregroundStyle(.tertiary).lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16).padding(.vertical, 7)
  }

  private func taskRow(_ t: UnifiedTask) -> some View {
    let listColor = t.listColorHex.flatMap(Color.init(hex:)) ?? (t.source.type == .atoll ? CoColor.accent : .secondary)
    return HStack(spacing: 11) {
      Circle().strokeBorder(t.isDone ? Color.clear : .secondary, lineWidth: 1.6)
        .background(Circle().fill(t.isDone ? listColor : Color.clear))
        .frame(width: 16, height: 16)
        .padding(.horizontal, 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(t.title).font(.system(size: 13.5, weight: .semibold))
          .strikethrough(t.isDone).foregroundStyle(t.isDone ? .secondary : .primary).lineLimit(1)
        HStack(spacing: 8) {
          if let d = t.due {
            Text(Self.taskDue.string(from: d)).font(.system(size: 11)).foregroundStyle(.tertiary)
          }
          if let name = t.listName {
            HStack(spacing: 4) {
              Circle().fill(listColor).frame(width: 7, height: 7)
              Text(name).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16).padding(.vertical, 7)
  }

  // MARK: - Aktionen

  private func open(_ hit: SearchHit) {
    switch hit {
    case .contact: onOpen(.kontakte)
    case .event:   onOpen(.kalender)
    case .task:    onOpen(.tasks)
    }
    dismiss()
  }

  private func openFirstHit() {
    if let h = store.contactHits.first ?? store.eventHits.first ?? store.taskHits.first {
      open(h)
    }
  }

  // MARK: - Formatierung (de_CH / Europe/Zurich)

  private static let taskDue: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM."
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()
  private static let dayTime: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE, d. MMM · HH:mm"
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()
  private static let day: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE, d. MMM"
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private static func eventDate(_ e: UnifiedEvent) -> String {
    if e.isAllDay { return "\(day.string(from: e.start)) · ganztägig" }
    return dayTime.string(from: e.start)
  }
}
