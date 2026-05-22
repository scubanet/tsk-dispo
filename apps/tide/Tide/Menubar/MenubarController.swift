import AppKit
import SwiftUI
import Core

@MainActor
final class MenubarController {
  private let statusItem: NSStatusItem
  private let panel: PanelWindow
  private let conversationStore: ConversationStore

  init(conversationStore: ConversationStore) {
    self.conversationStore = conversationStore
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    panel = PanelWindow()
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "wave.3.right.circle",
        accessibilityDescription: "Tide"
      )
      button.image?.isTemplate = true
      button.target = self
      button.action = #selector(togglePanel)
    }
    let view = PanelView(conversationStore: conversationStore)
    panel.contentViewController = NSHostingController(rootView: view)
  }

  @objc private func togglePanel() {
    if panel.isVisible {
      panel.orderOut(nil)
    } else {
      positionPanelBelowStatusItem()
      panel.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func positionPanelBelowStatusItem() {
    guard let button = statusItem.button,
          let buttonWindow = button.window else { return }
    let buttonFrameOnScreen = buttonWindow.convertToScreen(button.frame)
    let x = buttonFrameOnScreen.midX - panel.frame.width / 2
    let y = buttonFrameOnScreen.minY - panel.frame.height - 4
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }
}
