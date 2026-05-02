import SwiftUI

@main
struct ATOLLApp: App {
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
        .preferredColorScheme(nil) // System (light/dark/auto)
    }
  }
}
