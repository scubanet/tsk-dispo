import SwiftUI
import AtollHub

/// Aufgaben-Modul: Filter-Rail (Alle/Heute/Markiert + Meine Listen) + Liste.
struct AufgabenModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = AufgabenStore()
  @State private var showNew = false

  var body: some View {
    @Bindable var store = store
    CompactWidthReader { compact in
      Group {
        if compact { compactBody(store) } else { wideBody(store) }
      }
      .task { await store.reload(using: hub) }
      .sheet(isPresented: $showNew) {
        TaskEditSheet { title, due, listId in
          Task { await store.create(title: title, due: due, listId: listId, using: hub) }
        }
      }
    }
  }

  private func wideBody(_ store: AufgabenStore) -> some View {
    HStack(spacing: 0) {
      rail(store: store)
        #if os(macOS)
        .frame(width: 210)
        #endif
      Divider()
      list
    }
  }

  private func compactBody(_ store: AufgabenStore) -> some View {
    NavigationStack {
      list
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Menu {
              ForEach(TaskSmartFilter.allCases) { f in
                Button { store.list = nil; store.smart = f } label: { Label(f.title, systemImage: icon(f)) }
              }
              if !store.lists.isEmpty {
                Divider()
                ForEach(store.lists) { l in
                  Button { store.list = l.name } label: { Text(l.name) }
                }
              }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
          }
          ToolbarItem(placement: .automatic) {
            Button { showNew = true } label: { Image(systemName: "plus") }
          }
        }
    }
  }

  private func rail(store: AufgabenStore) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          ForEach(TaskSmartFilter.allCases) { f in
            let active = store.list == nil && store.smart == f
            Button { store.list = nil; store.smart = f } label: {
              VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon(f)).font(.system(size: 16))
                  .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(smartColor(f)))
                HStack(alignment: .firstTextBaseline) {
                  Text(f.title).font(.system(size: 11.5, weight: .semibold))
                  Spacer()
                  Text("\(store.smartOpenCount(f))").font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(active ? .white : .primary)
              }
              .padding(9).frame(maxWidth: .infinity, alignment: .leading)
              .background(active ? AnyShapeStyle(CoColor.accent) : AnyShapeStyle(.quaternary),
                          in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
          }
        }
        if !store.lists.isEmpty {
          Text("MEINE LISTEN").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary).padding(.horizontal, 8)
          ForEach(store.lists) { l in
            let active = store.list == l.name
            Button { store.list = l.name } label: {
              HStack(spacing: 9) {
                Circle().fill(active ? Color.white : (Color(hex: l.colorHex ?? "") ?? .secondary)).frame(width: 11, height: 11)
                Text(l.name).font(.system(size: 13, weight: active ? .semibold : .medium))
                Spacer(minLength: 0)
                Text("\(l.openCount)").font(.system(size: 12)).foregroundStyle(active ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
              }
              .foregroundStyle(active ? .white : .primary)
              .padding(.horizontal, 10).frame(height: 32)
              .background(active ? AnyShapeStyle(CoColor.accent) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(12)
    }
  }

  private var list: some View {
    let r = store.result
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        Text(headerTitle).font(.system(size: 20, weight: .bold))
        Spacer()
        if store.loading { ProgressView().controlSize(.small) }
        Button { showNew = true } label: { Image(systemName: "plus") }
          .buttonStyle(.plain)
      }
      .padding(.horizontal, 26).frame(height: 52)
      if let err = store.lastError {
        Text(err).font(.system(size: 12)).foregroundStyle(.red)
          .padding(.horizontal, 26).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading)
      }
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if r.open.isEmpty && r.done.isEmpty {
            ContentUnavailableView("Keine Aufgaben", systemImage: "checklist")
              .padding(.top, 40)
          } else {
            ForEach(r.open) { t in
              TaskRow(task: t, showList: store.list == nil) {
                Task { await store.toggleDone(t, using: hub) }
              }
              Divider()
            }
            if !r.done.isEmpty {
              Text("\(r.done.count) erledigt").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary).padding(.top, 16).padding(.bottom, 4)
              ForEach(r.done) { t in
                TaskRow(task: t, showList: store.list == nil) {
                  Task { await store.toggleDone(t, using: hub) }
                }
                Divider()
              }
            }
          }
        }
        .padding(.horizontal, 26).padding(.bottom, 30).frame(maxWidth: 680, alignment: .leading)
      }
    }
  }

  private var headerTitle: String {
    if let l = store.list { return l }
    return store.smart.title
  }
  private func icon(_ f: TaskSmartFilter) -> String {
    switch f { case .all: return "checklist"; case .today: return "clock"; case .flagged: return "flag" }
  }
  private func smartColor(_ f: TaskSmartFilter) -> Color {
    switch f { case .all: return .secondary; case .today: return Color(red: 1, green: 0.62, blue: 0.04); case .flagged: return Color(red: 1, green: 0.27, blue: 0.23) }
  }
}
