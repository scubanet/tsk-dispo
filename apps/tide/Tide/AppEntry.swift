import SwiftUI
import Core

@main
struct TideApp: App {
  @NSApplicationDelegateAdaptor(TideAppDelegate.self) var delegate

  var body: some Scene {
    Settings { EmptyView() }
  }
}

final class TideAppDelegate: NSObject, NSApplicationDelegate {
  @MainActor private var menubarController: MenubarController?
  @MainActor private var conversationStore: ConversationStore?

  func applicationDidFinishLaunching(_ notification: Notification) {
    Task { @MainActor in
      do {
        let store = try ConversationStore()
        self.conversationStore = store
        self.menubarController = MenubarController(conversationStore: store)
      } catch {
        NSLog("Tide: failed to init store: \(error)")
      }
    }
  }
}
