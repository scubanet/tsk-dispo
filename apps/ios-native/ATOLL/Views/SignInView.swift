import SwiftUI

struct SignInView: View {
  @Environment(AuthState.self) private var auth

  @State private var email = ""
  @State private var status: SendStatus = .idle
  @State private var errorMessage: String?

  enum SendStatus {
    case idle, sending, sent
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // Logo + Branding Hero
      VStack(spacing: 12) {
        AtollLogo(size: 88)
          .shadow(color: .accentColor.opacity(0.25), radius: 14, x: 0, y: 4)
        Text(Config.appName)
          .font(.system(size: 32, weight: .heavy))
          .tracking(6)
        Text(Config.appTagline)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .leading, spacing: 14) {
        Text("Magic-Link an deine Email")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("login@email.ch", text: $email)
          .textFieldStyle(.plain)
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.send)
          .onSubmit { Task { await send() } }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
        }

        Button {
          Task { await send() }
        } label: {
          Group {
            switch status {
            case .idle:    Label("Magic-Link senden", systemImage: "envelope.fill")
            case .sending: ProgressView().tint(.white)
            case .sent:    Label("Link gesendet — schau in die Inbox", systemImage: "checkmark.circle.fill")
            }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(email.isEmpty || status == .sending)
      }
      .padding(20)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
      .padding(.horizontal, 24)

      Spacer()

      Text(Config.tenantName)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 32)
  }

  private func send() async {
    guard !email.isEmpty else { return }
    status = .sending
    errorMessage = nil
    do {
      try await auth.sendMagicLink(to: email.trimmingCharacters(in: .whitespacesAndNewlines))
      status = .sent
    } catch {
      errorMessage = error.localizedDescription
      status = .idle
    }
  }
}
