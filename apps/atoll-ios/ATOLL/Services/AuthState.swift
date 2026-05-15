import Foundation
import Supabase
import SwiftUI

/// App-weiter Auth-Zustand. Verwaltet Session, lädt aktuellen Instructor aus
/// `contact_instructor` (canonical) + `instructors` (legacy fallback).
@MainActor
@Observable
final class AuthState {
  enum Status {
    case loading
    case signedOut
    case signedIn(currentUser: CurrentUser)
  }

  private(set) var status: Status = .loading

  private let supabase = SupabaseClient.shared

  init() {
    Task { await bootstrap() }
    Task { await listenToAuthChanges() }
  }

  // MARK: – Bootstrap

  func bootstrap() async {
    do {
      let session = try await supabase.auth.session
      await loadCurrentUser(authUserId: session.user.id)
    } catch {
      status = .signedOut
    }
  }

  // MARK: – Sign in

  func sendMagicLink(to email: String) async throws {
    try await supabase.auth.signInWithOTP(
      email: email,
      redirectTo: Config.authRedirectURL
    )
  }

  /// Wird aufgerufen wenn die App mit `atoll://auth/callback?...` geöffnet wird.
  func handleAuthCallback(url: URL) async throws {
    let session = try await supabase.auth.session(from: url)
    await loadCurrentUser(authUserId: session.user.id)
  }

  // MARK: – Sign out

  func signOut() async {
    try? await supabase.auth.signOut()
    status = .signedOut
  }

  // MARK: – Listener

  private func listenToAuthChanges() async {
    for await change in supabase.auth.authStateChanges {
      switch change.event {
      case .signedIn, .tokenRefreshed, .userUpdated:
        if let user = change.session?.user {
          await loadCurrentUser(authUserId: user.id)
        }
      case .signedOut:
        status = .signedOut
      default:
        break
      }
    }
  }

  // MARK: – Load user (contact_instructor + legacy instructors)

  /// PostgREST-Row-Wrapper für den primären `contact_instructor`-Lookup.
  private struct ContactInstructorRow: Decodable {
    let padiLevel: String?
    let appRole: String?
    let preferredLanguage: String?
    let initials: String?
    let contact: ContactRow

    enum CodingKeys: String, CodingKey {
      case padiLevel = "padi_level"
      case appRole = "app_role"
      case preferredLanguage = "preferred_language"
      case initials
      case contact = "contacts"
    }

    struct ContactRow: Decodable {
      let id: UUID
      let firstName: String
      let lastName: String
      let primaryEmail: String?

      enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case primaryEmail = "primary_email"
      }
    }
  }

  /// PostgREST-Row-Wrapper für den Legacy-Fallback aus `instructors`.
  private struct InstructorLegacyRow: Decodable {
    let id: UUID
    let color: String?
  }

  private func loadCurrentUser(authUserId: UUID) async {
    // Primary: contact_instructor → contacts (canonical)
    let primary: ContactInstructorRow?
    do {
      primary = try await supabase
        .from("contact_instructor")
        .select("padi_level, app_role, preferred_language, initials, contacts!inner(id, first_name, last_name, primary_email)")
        .eq("auth_user_id", value: authUserId)
        .single()
        .execute()
        .value
    } catch {
      #if DEBUG
      print("⚠️ AuthState: contact_instructor query failed for \(authUserId): \(error)")
      #endif
      primary = nil
    }

    // Legacy: instructors.id für rückwärtskompatible Stores
    let legacy: InstructorLegacyRow? = try? await supabase
      .from("instructors")
      .select("id, color")
      .eq("auth_user_id", value: authUserId)
      .single()
      .execute()
      .value

    #if DEBUG
    if legacy == nil {
      print("ℹ️ AuthState: no instructors row for auth_user_id \(authUserId) — legacyInstructorId will fall back to contacts.id; legacy stores will return empty results")
    }
    #endif

    guard let p = primary else {
      // Account existiert in auth.users aber kein contact_instructor.
      status = .signedIn(currentUser: CurrentUser.unlinked(authUserId: authUserId))
      return
    }

    let role = CurrentUser.Role(rawValue: p.appRole ?? "instructor") ?? .instructor

    let user = CurrentUser(
      id: p.contact.id,
      instructorId: legacy?.id,
      firstName: p.contact.firstName,
      lastName: p.contact.lastName,
      email: p.contact.primaryEmail,
      padiLevel: p.padiLevel ?? "—",
      role: role,
      authUserId: authUserId,
      preferredLanguage: p.preferredLanguage,
      initials: p.initials,
      color: legacy?.color
    )
    status = .signedIn(currentUser: user)
  }
}
