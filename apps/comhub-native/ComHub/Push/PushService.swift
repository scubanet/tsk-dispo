import Foundation
import Observation
import UserNotifications
import Supabase
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Verwaltet Push-Permission + APNs-Registrierung + Token-Upsert nach
/// `comhub_device_tokens`. Singleton, weil das AppDelegate-Callback ihn braucht.
@MainActor
@Observable
final class PushService {
  static let shared = PushService()
  private init() {}

  enum Status: Equatable { case unknown, denied, authorized, registering }
  private(set) var status: Status = .unknown
  private(set) var lastError: String?

  /// Aktuelle auth-User-Id (von der App nach Sign-in gesetzt) — fuer den Upsert-Owner.
  var authUserId: UUID?

  /// Liest den aktuellen Permission-Status (zeigt ihn in den Einstellungen).
  func refreshStatus() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral: status = .authorized
    case .denied: status = .denied
    default: status = .unknown
    }
  }

  /// Fragt Permission an; bei Erfolg registriert sich die App fuer Remote-Notifications.
  func enable() async {
    do {
      let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound])
      guard granted else { status = .denied; return }
      status = .registering
      registerForRemote()
    } catch {
      lastError = "Push-Aktivierung fehlgeschlagen: \(error.localizedDescription)"
    }
  }

  private func registerForRemote() {
    #if os(iOS)
    UIApplication.shared.registerForRemoteNotifications()
    #elseif os(macOS)
    NSApplication.shared.registerForRemoteNotifications()
    #endif
  }

  /// AppDelegate-Callback: Token erhalten -> hex -> upsert.
  nonisolated func didRegister(tokenData: Data) {
    let hex = tokenData.map { String(format: "%02x", $0) }.joined()
    Task { @MainActor in await self.upsert(token: hex) }
  }
  nonisolated func didFail(_ error: Error) {
    Task { @MainActor in self.lastError = "APNs-Registrierung fehlgeschlagen: \(error.localizedDescription)" }
  }

  private func upsert(token: String) async {
    guard let uid = authUserId else { lastError = "Nicht angemeldet."; return }
    #if os(iOS)
    let platform = "ios"; let device = UIDevice.current.name
    #else
    let platform = "macos"; let device = Host.current().localizedName ?? "Mac"
    #endif
    struct Row: Encodable {
      let auth_user_id: String; let apns_token: String; let platform: String
      let app_env: String; let device_name: String; let updated_at: String
    }
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
    let row = Row(auth_user_id: uid.uuidString, apns_token: token, platform: platform,
                  app_env: "development", device_name: device, updated_at: iso.string(from: Date()))
    do {
      _ = try await SupabaseClient.shared
        .from("comhub_device_tokens")
        .upsert(row, onConflict: "apns_token")
        .execute()
      status = .authorized
    } catch {
      lastError = "Token speichern fehlgeschlagen: \(error.localizedDescription)"
    }
  }
}
