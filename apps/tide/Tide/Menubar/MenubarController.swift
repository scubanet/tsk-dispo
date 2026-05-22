import AppKit

/// Owns the menubar `NSStatusItem` and (in later phases) drives the panel
/// open/close lifecycle. Phase 0 version: shows the icon and logs clicks.
@MainActor
final class MenubarController {
  private let statusItem: NSStatusItem

  init() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "wave.3.right.circle",
        accessibilityDescription: "Tide"
      )
      button.image?.isTemplate = true
      button.target = self
      button.action = #selector(handleClick)
    }
  }

  @objc private func handleClick() {
    NSLog("Tide: status item clicked")
  }
}
