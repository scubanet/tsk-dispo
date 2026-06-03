import SwiftUI
import AtollCore

/// Wurzel-View: schaltet zwischen Lade-Spinner, Login und Shell — gesteuert
/// vom `AuthState.status`.
struct RootView: View {
  @Environment(AuthState.self) private var auth

  var body: some View {
    switch auth.status {
    case .loading:
      ProgressView().controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .signedOut:
      SignInView()
    case .signedIn:
      HubShell()
    }
  }
}
