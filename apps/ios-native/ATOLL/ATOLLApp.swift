import SwiftUI

@main
struct ATOLLApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var auth = AuthState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .onOpenURL { url in
          // Magic-Link callback: atoll://auth/callback?token_hash=...&type=...
          guard url.scheme == "atoll" else { return }
          Task {
            try? await auth.handleAuthCallback(url: url)
          }
        }
        // Push-Manager kennt den eingeloggten Instructor — sodass Tokens der richtigen Person zugeordnet werden.
        .onChange(of: instructorId(from: auth.status)) { _, newId in
          PushManager.shared.currentInstructorId = newId
          if newId != nil {
            // Beim ersten Login: Push-Permission abfragen.
            Task { await PushManager.shared.requestAuthorizationIfNeeded() }
          }
        }
        .preferredColorScheme(nil) // System (light/dark/auto)
    }
  }

  private func instructorId(from status: AuthState.Status) -> UUID? {
    if case .signedIn(let user) = status { return user.id }
    return nil
  }
}
