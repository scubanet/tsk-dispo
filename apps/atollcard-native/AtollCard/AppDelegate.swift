import UIKit

/// Minimal AppDelegate — exists only to bridge the APNs device-token
/// callback into Swift code. SwiftUI's `@UIApplicationDelegateAdaptor` in
/// `AtollCardApp` wires this in.
///
/// Once iOS gives us a token, we forward it to `PushTokenService.shared`
/// which persists it into `device_tokens` for the server-side push hook
/// to read.
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Task { @MainActor in
      await PushTokenService.shared.record(token: deviceToken)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    Task { @MainActor in
      PushTokenService.shared.failedToRegister(error: error)
    }
  }
}
