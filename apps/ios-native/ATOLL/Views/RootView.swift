import SwiftUI

struct RootView: View {
  @Environment(AuthState.self) private var auth

  var body: some View {
    ZStack {
      // Liquid-Glass Hintergrund (subtiler Verlauf, passt zur Web-App-Aesthetik)
      LinearGradient(
        colors: [
          Color(.systemBackground),
          Color(red: 0.94, green: 0.96, blue: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      switch auth.status {
      case .loading:
        ProgressView()
          .scaleEffect(1.4)
      case .signedOut:
        SignInView()
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
      case .signedIn(let user):
        MainTabView(user: user)
          .transition(.opacity)
      }
    }
    .animation(.smooth, value: stateKey(auth.status))
  }

  // Stable identity für Animationen ohne CurrentUser-Equality
  private func stateKey(_ status: AuthState.Status) -> String {
    switch status {
    case .loading: return "loading"
    case .signedOut: return "out"
    case .signedIn(let u): return "in-\(u.id.uuidString)"
    }
  }
}
