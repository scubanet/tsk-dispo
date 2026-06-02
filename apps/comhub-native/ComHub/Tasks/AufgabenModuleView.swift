import SwiftUI
import AtollHub

/// Aufgaben-Modul: Filter-Rail (Alle/Heute/Markiert + Meine Listen) + Liste.
struct AufgabenModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = AufgabenStore()

  var body: some View {
    @Bindable var store = store
    HStack(spacing: 0) {
      rail(store: store)
        #if os(macOS)
        .frame(width: 210)
        #endif
      Divider()
      list
    }
    .task { await store.reload(using: hub) }
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
                  Text("\(count(f, store))").font(.system(size: 16, weight: .bold))
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
      }
      .padding(.horizontal, 26).frame(height: 52)
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if r.open.isEmpty && r.done.isEmpty {
            ContentUnavailableView("Keine Aufgaben", systemImage: "checklist")
              .padding(.top, 40)
          } else {
            ForEach(r.open) { TaskRow(task: $0, showList: store.list == nil); Divider() }
            if !r.done.isEmpty {
              Text("\(r.done.count) erledigt").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary).padding(.top, 16).padding(.bottom, 4)
              ForEach(r.done) { TaskRow(task: $0, showList: store.list == nil); Divider() }
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
  private func count(_ f: TaskSmartFilter, _ store: AufgabenStore) -> Int {
    TaskDigest.filter(store.all, smart: f, list: nil, now: Date(), calendar: .current).open.count
  }
}
