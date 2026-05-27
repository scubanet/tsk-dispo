import Foundation
import UIKit
import UserNotifications
import Supabase
import AtollCore
import OSLog

/// Captures the APNs device token and upserts it into `device_tokens` so
/// the server can push notifications to this device.
///
/// **Flow:**
///   1. `register()` calls `UIApplication.shared.registerForRemoteNotifications()`.
///   2. UIApplicationDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
///      forwards the token here via `record(token:)`.
///   3. We upsert the token + auth_user_id into Supabase.
///
/// Without an APNs Auth Key in Supabase (see README "Phase 6"), nothing
/// actually pushes — but the device-token table is filled so the
/// switch-over later is a server-side change, not an app update.
///
/// **AppDelegate bridge:** SwiftUI apps don't have a native AppDelegate,
/// so we use an `@UIApplicationDelegateAdaptor` in `AtollCardApp.swift`
/// (added in this phase) that forwards the device-token callback to
/// `PushTokenService.shared`.
@MainActor
public final class PushTokenService {
  public static let shared = PushTokenService()
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "push")

  private init() {}

  /// Asks iOS for an APNs token. Idempotent — safe to call on every launch.
  /// The token comes back via the AppDelegate callback (see
  /// `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`).
  public func register() {
    UIApplication.shared.registerForRemoteNotifications()
  }

  /// Called from the AppDelegate when iOS delivers a fresh token. Upserts
  /// the row in Supabase. No-op if the user isn't signed in (RLS blocks
  /// the write).
  public func record(token: Data) async {
    let hexToken = token.map { String(format: "%02x", $0) }.joined()
    Self.logger.debug("APNs token captured: \(hexToken, privacy: .private)")

    do {
      let session = try await SupabaseClient.shared.auth.session
      try await SupabaseClient.shared
        .from("atollcard_device_tokens")
        .upsert([
          "auth_user_id": session.user.id.uuidString,
          "device_token": hexToken,
          "platform":     "ios",
          "app_bundle_id": "swiss.atoll.card",
        ])
        .execute()
      Self.logger.debug("device token persisted")
    } catch {
      Self.logger.error("token upsert failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  public func failedToRegister(error: Error) {
    Self.logger.error("APNs register failed: \(error.localizedDescription, privacy: .public)")
  }
}
