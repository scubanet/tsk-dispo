import AppKit
import ApplicationServices
import OSLog

private let log = Logger(subsystem: "swiss.weckherlin.tide", category: "selection")

/// Reads the currently selected text from the frontmost application via
/// the macOS Accessibility API. Requires the user to grant Tide
/// Accessibility permission (System Settings → Privacy & Security →
/// Accessibility). Without that permission `readFromFrontmostApp()`
/// always returns `nil` — call sites should treat that as "no context",
/// not an error.
public enum SelectionReader {
  /// Best-effort read of the user's current selection. Returns `nil` if
  /// AX trust is missing, no app is frontmost, no focused element, or
  /// the focused element exposes no selected text.
  public static func readFromFrontmostApp() -> SelectedText? {
    guard AXIsProcessTrusted() else {
      log.debug("not AX-trusted")
      return nil
    }
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
      log.debug("no frontmost app")
      return nil
    }
    let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

    var focused: CFTypeRef?
    let focusStatus = AXUIElementCopyAttributeValue(
      appElement, kAXFocusedUIElementAttribute as CFString, &focused
    )
    guard focusStatus == .success, let focused = focused else {
      log.debug("no focused element")
      return nil
    }

    // Force-cast is safe — AXUIElement is the documented type for AX values.
    let focusedElement = focused as! AXUIElement
    var value: CFTypeRef?
    let valueStatus = AXUIElementCopyAttributeValue(
      focusedElement, kAXSelectedTextAttribute as CFString, &value
    )
    guard valueStatus == .success,
          let text = value as? String,
          !text.isEmpty else {
      log.debug("no selected text")
      return nil
    }

    return SelectedText(
      text: text,
      sourceAppBundleID: frontApp.bundleIdentifier ?? "",
      sourceAppName: frontApp.localizedName ?? ""
    )
  }

  /// Prompt macOS to ask the user for Accessibility permission. Safe to
  /// call repeatedly — no dialog appears if permission is already
  /// granted or already explicitly denied.
  ///
  /// We hard-code the option key as a string literal instead of
  /// referencing `kAXTrustedCheckOptionPrompt`. Under Swift 6 strict
  /// concurrency that CFString constant is flagged as shared mutable
  /// state and won't compile. The constant's documented value never
  /// changes — `"AXTrustedCheckOptionPrompt"`.
  public static func requestAccessibilityPermission() {
    let opts: NSDictionary = [
      "AXTrustedCheckOptionPrompt" as NSString: true
    ]
    _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
  }
}
