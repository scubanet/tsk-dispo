import SwiftUI
import AtollHub
import AtollCore

/// Outlook-artige 3-Spalten-Shell: Modul-Leiste · Liste · Detail.
/// Phase 0 zeigt Platzhalter pro Modul; echte Inhalte folgen in Phase 1+.
struct HubShell: View {
  @State private var selectedModule: ComHubModule = .heute
  @Environment(AuthState.self) private var auth
  /// Badge-Zahlen je Modul (von Phasen gespeist; vorerst leer).
  private let badges: [ComHubModule: Int] = [:]

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        List(selection: $selectedModule) {
          ForEach(ComHubModule.allCases.filter { $0 != .einstellungen }) { module in
            sidebarRow(module).tag(module)
          }
          Divider().padding(.vertical, 4)
          sidebarRow(.einstellungen).tag(ComHubModule.einstellungen)
        }
        .listStyle(.sidebar)

        Spacer(minLength: 0)
        sidebarFooter
      }
      .navigationTitle("ComHub")
      #if os(macOS)
      .frame(minWidth: 220)
      #endif
    } content: {
      switch selectedModule {
      case .heute:
        CockpitView(onOpenModule: { selectedModule = $0 })
          #if os(macOS)
          .frame(minWidth: 360)
          #endif
      case .kalender:
        CalendarModuleView()
          #if os(macOS)
          .frame(minWidth: 480)
          #endif
      case .kontakte:
        ContactsModuleView()
          #if os(macOS)
          .frame(minWidth: 560)
          #endif
      case .kombox:
        KomboxModuleView()
          #if os(macOS)
          .frame(minWidth: 560)
          #endif
      default:
        ModulePlaceholder(module: selectedModule, pane: "Liste")
          #if os(macOS)
          .frame(minWidth: 280)
          #endif
      }
    } detail: {
      switch selectedModule {
      case .heute, .kalender, .kontakte, .kombox:
        // Diese Module rendern ihr Detail intern (NavigationSplitView-
        // Detailspalte bleibt fuer sie leer/kontextuell).
        Color.clear
      default:
        ModulePlaceholder(module: selectedModule, pane: "Detail")
      }
    }
  }

  @ViewBuilder
  private func sidebarRow(_ module: ComHubModule) -> some View {
    HStack(spacing: 10) {
      Image(systemName: module.systemImage)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(CoColor.module(module))
        .frame(width: 20)
      Text(module.title)
      Spacer(minLength: 0)
      if let n = badges[module], n > 0 { CoCountBadge(count: n) }
    }
  }

  private var sidebarFooter: some View {
    HStack(spacing: 9) {
      CoAvatar(name: footerName, size: 28)
      VStack(alignment: .leading, spacing: 1) {
        Text(footerName).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
        Text("ComHub Konto").font(.system(size: 10.5)).foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
  }

  private var footerName: String {
    if case .signedIn(let user) = auth.status { return user.name }
    return "ComHub"
  }
}

/// Platzhalter-Pane bis das jeweilige Modul gebaut ist.
private struct ModulePlaceholder: View {
  let module: ComHubModule
  let pane: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: module.systemImage).font(.system(size: 40)).foregroundStyle(.secondary)
      Text(module.title).font(.title2.weight(.semibold))
      Text("\(pane) — kommt in einer späteren Phase").foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
