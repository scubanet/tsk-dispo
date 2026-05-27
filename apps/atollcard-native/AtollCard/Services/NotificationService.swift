import Foundation
import UserNotifications
import OSLog

/// Wraps `UNUserNotificationCenter` for the two things AtollCard actually
/// uses notifications for:
///   1. Lead-arrived alerts (live via Realtime-Subscription, see LeadStore).
///   2. Remote-Push deliveries from Atoll-OS-Server (Phase 6 — when APNs
///      Auth Key is configured).
///
/// Authorization is requested lazily on first use, not on app launch. Apple
/// recommends asking only when there's an immediate need so users
/// understand the value.
@MainActor
public final class NotificationService {
  public static let shared = NotificationService()
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "notifications")

  private init() {}

  /// Returns `true` if the user has granted permission, asking once if the
  /// status is still `.notDetermined`. Idempotent — safe to call on every
  /// new-lead event.
  public func ensureAuthorization() async -> Bool {
    let center = UNUserNotificationCenter.current()
    let current = await center.notificationSettings().authorizationStatus
    switch current {
    case .authorized, .provisional, .ephemeral:
      return true
    case .denied:
      return false
    case .notDetermined:
      do {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted
      } catch {
        Self.logger.error("auth request failed: \(error.localizedDescription, privacy: .public)")
        return false
      }
    @unknown default:
      return false
    }
  }

  /// Schedules a local notification for an incoming lead. Title carries the
  /// lead's name, body carries the topic ("IDC Anfrage", "Trial Dive", …).
  /// Tap → opens the app to the Leads tab (handled by the
  /// `UNUserNotificationCenterDelegate` later).
  public func scheduleLeadNotification(_ lead: Lead, cardTitle: String) async {
    guard await ensureAuthorization() else { return }

    let content = UNMutableNotificationContent()
    content.title = "Neuer Lead — \(lead.fullName.isEmpty ? lead.firstName : lead.fullName)"
    content.body = [cardTitle, lead.topic].compactMap { $0 }.joined(separator: " · ")
    content.sound = .default
    content.userInfo = [
      "lead_id": lead.id.uuidString,
      "card_id": lead.cardId.uuidString,
    ]

    // Immediate trigger (1 sec) — using nil throws on Mac Catalyst,
    // 1-second TimeInterval works on all platforms.
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: "lead-\(lead.id.uuidString)",
      content: content,
      trigger: trigger
    )

    do {
      try await UNUserNotificationCenter.current().add(request)
      Self.logger.debug("scheduled local notification for lead \(lead.id, privacy: .public)")
    } catch {
      Self.logger.error("notification scheduling failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
