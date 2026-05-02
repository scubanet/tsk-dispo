import Foundation
import UIKit
import UserNotifications
import Supabase

/// Verwaltet Push-Permission, APNs-Token-Capturing und Sync zur DB.
@MainActor
final class PushManager {
    static let shared = PushManager()

    private let supabase = SupabaseClient.shared
    private var pendingToken: String?

    /// Aktueller Auth-Status — wird vom RootView gesetzt sobald ein Instructor eingeloggt ist.
    /// Damit der PushManager weiss zu welchem Instructor der Token gehört.
    var currentInstructorId: UUID? {
        didSet {
            // Falls Token schon da ist und User sich gerade eingeloggt hat: Sync nachholen.
            if let token = pendingToken, currentInstructorId != nil {
                Task { await persistToken(token) }
                pendingToken = nil
            }
        }
    }

    // MARK: – Permission Flow

    /// Vom UI getriggert (z.B. erstes Mal nach Login). Fragt User um Permission und registriert für Push.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            // User hat schon entschieden — falls zugesagt, sicherstellen dass registriert
            if settings.authorizationStatus == .authorized {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            return
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            #if DEBUG
            print("⚠️ Notification authorization error: \(error)")
            #endif
        }
    }

    // MARK: – Token Lifecycle

    /// Vom AppDelegate aufgerufen wenn APNs einen Token liefert.
    func handleNewToken(_ token: String) async {
        if currentInstructorId != nil {
            await persistToken(token)
        } else {
            // Login noch nicht abgeschlossen — Token zwischenspeichern bis instructorId da ist.
            pendingToken = token
        }
    }

    private func persistToken(_ token: String) async {
        guard let instructorId = currentInstructorId else { return }

        struct TokenRow: Encodable {
            let instructor_id: UUID
            let apns_token: String
            let platform: String
            let app_version: String?
            let os_version: String?
            let device_name: String?
            let last_seen: String  // ISO-8601
        }

        let now = ISO8601DateFormatter().string(from: .now)
        let row = TokenRow(
            instructor_id: instructorId,
            apns_token: token,
            platform: "ios",
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            os_version: UIDevice.current.systemVersion,
            device_name: UIDevice.current.name,
            last_seen: now
        )

        do {
            // UPSERT auf apns_token (UNIQUE) — bestehender Token bekommt last_seen aktualisiert.
            try await supabase
                .from("device_tokens")
                .upsert(row, onConflict: "apns_token")
                .execute()
            #if DEBUG
            print("✓ APNs token persisted: \(token.prefix(12))…")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Could not persist APNs token: \(error)")
            #endif
        }
    }

    /// Vor Logout aufrufen — entfernt den Token damit das Device keine Pushes für andere User mehr kriegt.
    func unregisterCurrentDevice() async {
        guard let instructorId = currentInstructorId else { return }
        // Lösche alle Tokens dieses Devices für diesen Instructor.
        // (Wir wissen nicht welcher Token "unser" ist ohne ihn zu kennen — daher löschen wir alle dieses Instructors.
        // Konservativ: das verhindert dass alte Devices weiter Pushes kriegen.)
        try? await supabase
            .from("device_tokens")
            .delete()
            .eq("instructor_id", value: instructorId)
            .execute()
        currentInstructorId = nil
    }
}
