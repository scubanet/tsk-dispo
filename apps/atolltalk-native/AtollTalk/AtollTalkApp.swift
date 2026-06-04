import SwiftUI
import SwiftData

@main
struct AtollTalkApp: App {
  @State private var settings = SettingsStore()
  @State private var glossary = GlossaryStore()
  let container: ModelContainer

  init() {
    do {
      container = try ModelContainer(for: Turn.self)
    } catch {
      // Last-resort in-memory store so the app still launches and can surface
      // the problem instead of hard-crashing on a migration/disk error.
      container = try! ModelContainer(
        for: Turn.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView(settings: settings, glossary: glossary)
        .modelContainer(container)
    }
  }
}
