import SwiftUI
import AtollCore

/// Magic-Link-Login: E-Mail eingeben → Link anfordern → Link in der Mail klicken
/// → die App oeffnet via `comhub://auth/callback` (siehe `ComHubApp.onOpenURL`)
/// → `AuthState.handleAuthCallback` meldet an. RootView schaltet dann auf die Shell.
struct SignInView: View {
  @Environment(AuthState.self) private var auth

  @State private var email = ""
  @State private var busy = false
  @State private var sent = false
  @State private var errorText: String?

  var body: some View {
    VStack(spacing: 16) {
      Text(verbatim: "ComHub").font(.largeTitle.weight(.semibold))
      Text("Anmelden mit deiner Atoll-E-Mail").foregroundStyle(.secondary)

      TextField("E-Mail", text: $email)
        .textContentType(.emailAddress)
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .frame(maxWidth: 320)
        #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        #endif

      Button(action: sendLink) {
        Text(busy ? "Sende…" : "Magic-Link senden")
      }
      .buttonStyle(.borderedProminent)
      .disabled(busy || !email.contains("@"))

      if sent {
        Text("Link gesendet — öffne die Mail und klick den Link.")
          .font(.callout).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      if let errorText {
        Text(errorText).font(.footnote).foregroundStyle(.red)
          .multilineTextAlignment(.center)
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func sendLink() {
    busy = true; errorText = nil; sent = false
    Task {
      do {
        try await auth.sendMagicLink(to: email.trimmingCharacters(in: .whitespaces))
        sent = true
      } catch {
        errorText = "Konnte den Link nicht senden: \(error.localizedDescription)"
      }
      busy = false
    }
  }
}
