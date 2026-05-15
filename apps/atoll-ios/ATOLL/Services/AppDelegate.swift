import SwiftUI
import UserNotifications
import UIKit

/// AppDelegate hooks für Push-Notifications.
/// Wird in `ATOLLApp.swift` via `@UIApplicationDelegateAdaptor` eingehängt.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: – Token erhalten → an Supabase

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushManager.shared.handleNewToken(tokenString) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Im Simulator schlägt das immer fehl — Push-Notifications funktionieren nur auf echten Geräten.
        #if DEBUG
        print("⚠️ Push registration failed (normal im Simulator): \(error.localizedDescription)")
        #endif
    }

    // MARK: – Notification handling (App im Foreground)

    /// Zeigt Notifications auch wenn die App offen ist (sonst verschluckt iOS sie).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// User tippt auf eine Notification → später hier Deep-Link zum Assignment öffnen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let assignmentId = userInfo["assignment_id"] as? String {
            // TODO Phase 2: Deep-Link via NotificationCenter posten, RootView öffnet die DetailView.
            print("📬 Notification tapped: assignment_id=\(assignmentId)")
        }
    }
}
