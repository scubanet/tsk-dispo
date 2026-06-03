import SwiftUI
#if os(iOS)
import UIKit
typealias PlatformAppDelegate = UIApplicationDelegate
#elseif os(macOS)
import AppKit
typealias PlatformAppDelegate = NSApplicationDelegate
#endif

/// Faengt das APNs-Token-Callback ab und reicht es an den PushService weiter.
final class PushAppDelegate: NSObject, PlatformAppDelegate {
  #if os(iOS)
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushService.shared.didRegister(tokenData: deviceToken)
  }
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    PushService.shared.didFail(error)
  }
  #elseif os(macOS)
  func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushService.shared.didRegister(tokenData: deviceToken)
  }
  func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    PushService.shared.didFail(error)
  }
  #endif
}
