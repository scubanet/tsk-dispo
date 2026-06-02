import SwiftUI
import AtollHub

/// Outlook-artige 3-Spalten-Shell: Modul-Leiste · Liste · Detail.
/// Phase 0 zeigt Platzhalter pro Modul; echte Inhalte folgen in Phase 1+.
struct HubShell: View {
  @State private var selectedModule: ComHubModule = .heute

  var body: some View {
    NavigationSplitView {
      List(ComHubModule.allCases, selection: $selectedModule) { module in
        Label(module.title, systemImage: module.systemImage)
          .tag(module)
      }
      .navigationTitle("ComHub")
      #if os(macOS)
      .frame(minWidth: 200)
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
        // NavigationStack, damit NavigationLink/navigationDestination in der
        // Content-Spalte das Kontakt-Detail tatsaechlich pushen koennen.
        NavigationStack { ContactsModuleView() }
          #if os(macOS)
          .frame(minWidth: 320)
          #endif
      default:
        ModulePlaceholder(module: selectedModule, pane: "Liste")
          #if os(macOS)
          .frame(minWidth: 280)
          #endif
      }
    } detail: {
      switch selectedModule {
      case .heute, .kalender, .kontakte:
        // Diese Module rendern ihr Detail intern (NavigationSplitView-
        // Detailspalte bleibt fuer sie leer/kontextuell).
        Color.clear
      default:
        ModulePlaceholder(module: selectedModule, pane: "Detail")
      }
    }
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
