import SwiftUI
import AtollCore
import AtollDesign

struct SignInView: View {
  @Environment(AuthState.self) var auth
  @State private var email: String = ""
  @State private var sendStatus: SendStatus = .idle

  enum SendStatus: Equatable {
    case idle
    case sending
    case sent
    case error(String)
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      BrandHeader(appName: Config.appName, tenantName: Config.tenantName)

      VStack(spacing: 12) {
        TextField("Email-Adresse", text: $email)
          .textFieldStyle(.roundedBorder)
          #if os(iOS)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          #endif
          .textContentType(.emailAddress)
          .autocorrectionDisabled()
          .padding(.horizontal)

        Button(action: sendLink) {
          Text(sendStatus == .sending ? "Sende..." : "Magic-Link senden")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(email.isEmpty || sendStatus == .sending)
        .padding(.horizontal)

        switch sendStatus {
        case .sent:
          Text("Link gesendet — bitte Mail-App öffnen")
            .foregroundColor(.secondary)
            .font(.caption)
        case .error(let msg):
          Text(msg).foregroundColor(.red).font(.caption)
        default:
          EmptyView()
        }
      }

      Spacer()
    }
    .padding()
  }

  private func sendLink() {
    sendStatus = .sending
    Task {
      do {
        try await auth.sendMagicLink(to: email)
        await MainActor.run { sendStatus = .sent }
      } catch {
        await MainActor.run { sendStatus = .error(error.localizedDescription) }
      }
    }
  }
}
