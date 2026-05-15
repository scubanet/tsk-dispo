import SwiftUI
import AtollCore

struct RootView: View {
  @Environment(AuthState.self) var auth

  var body: some View {
    switch auth.status {
    case .loading:
      ProgressView()
    case .signedOut:
      SignInView()
    case .signedIn:
      CalendarRoot()
    }
  }
}
