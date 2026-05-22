import SwiftUI

/// Tide is a menubar-only app. `LSUIElement = true` in Info.plist suppresses
/// the Dock icon. We declare a `Settings { EmptyView() }` scene to satisfy
/// SwiftUI's App contract without creating any user-facing window — the
/// MenubarController owns the real UI.
@main
struct TideApp: App {
  @NSApplicationDelegateAdaptor(TideAppDelegate.self) var delegate

  var body: some Scene {
    Settings { EmptyView() }
  }
}

final class TideAppDelegate: NSObject, NSApplicationDelegate {
  private var menubarController: MenubarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    menubarController = MenubarController()
  }
}
