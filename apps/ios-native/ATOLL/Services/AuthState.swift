import Foundation
import Supabase
import SwiftUI

/// App-weiter Auth-Zustand. Verwaltet Session, lädt aktuellen Instructor.
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
    try await supabase.auth.session(from: url)
    if let userID = try? await supabase.auth.session.user.id {
      await loadCurrentUser(authUserId: userID)
    }
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

  // MARK: – Load user from `instructors` table

  private func loadCurrentUser(authUserId: UUID) async {
    do {
      let user: CurrentUser = try await supabase
        .from("instructors")
        .select("id, name, email, padi_level, role, auth_user_id, color, initials")
        .eq("auth_user_id", value: authUserId)
        .single()
        .execute()
        .value
      status = .signedIn(currentUser: user)
    } catch {
      // Account existiert in auth.users aber kein instructor-Eintrag verknüpft.
      // Nutzer sieht "Kein Instructor verknüpft" Hinweis.
      status = .signedIn(currentUser: CurrentUser.unlinked(authUserId: authUserId))
    }
  }
}
