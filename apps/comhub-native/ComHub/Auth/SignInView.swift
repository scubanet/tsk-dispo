import SwiftUI
import AtollCore
import AtollHub

/// Zweistufiger OTP-Login: E-Mail eingeben → Code anfordern → Code eingeben → anmelden.
struct SignInView: View {
  @Environment(AuthState.self) private var auth

  private enum Step { case email, code }
  @State private var step: Step = .email
  @State private var email = ""
  @State private var code = ""
  @State private var busy = false
  @State private var errorText: String?

  var body: some View {
    VStack(spacing: 16) {
      Text(verbatim: "ComHub").font(.largeTitle.weight(.semibold))
      Text("Anmelden mit deiner Atoll-E-Mail").foregroundStyle(.secondary)

      switch step {
      case .email:
        TextField("E-Mail", text: $email)
          .textContentType(.emailAddress)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 320)
          #if os(iOS)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          #endif
        Button(action: requestCode) {
          Text(busy ? "Sende…" : "Code anfordern")
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || !email.contains("@"))

      case .code:
        Text("Code aus der E-Mail an \(email)").font(.callout).foregroundStyle(.secondary)
        TextField("6-stelliger Code", text: $code)
          .textContentType(.oneTimeCode)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 220)
          #if os(iOS)
          .keyboardType(.numberPad)
          #endif
          .onChange(of: code) { _, new in code = OTPCode.sanitize(new) }
        Button(action: verify) {
          Text(busy ? "Prüfe…" : "Anmelden")
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || !OTPCode.isValid(code))
        Button("E-Mail ändern") { step = .email; code = ""; errorText = nil }
          .buttonStyle(.plain).font(.footnote)
      }

      if let errorText {
        Text(errorText).font(.footnote).foregroundStyle(.red)
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func requestCode() {
    busy = true; errorText = nil
    Task {
      do {
        try await auth.sendEmailCode(to: email.trimmingCharacters(in: .whitespaces))
        step = .code
      } catch {
        errorText = "Konnte keinen Code senden: \(error.localizedDescription)"
      }
      busy = false
    }
  }

  private func verify() {
    busy = true; errorText = nil
    Task {
      do {
        try await auth.verifyEmailCode(email: email.trimmingCharacters(in: .whitespaces), code: code)
        // Bei Erfolg schaltet RootView via auth.status automatisch auf die Shell.
      } catch {
        errorText = "Code ungültig oder abgelaufen."
      }
      busy = false
    }
  }
}
