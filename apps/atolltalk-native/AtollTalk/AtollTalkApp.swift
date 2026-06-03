import SwiftUI
import SwiftData

@main
struct AtollTalkApp: App {
  @State private var settings = SettingsStore()
  @State private var glossary = GlossaryStore()
  let container: ModelContainer

  init() {
    container = try! ModelContainer(for: Turn.self)
  }

  var body: some Scene {
    WindowGroup {
      RootView(settings: settings, glossary: glossary)
        .modelContainer(container)
    }
  }
}
