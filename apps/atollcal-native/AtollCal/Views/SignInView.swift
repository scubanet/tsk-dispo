import SwiftUI
import AtollCore
import AtollDesign
import OSLog

struct SignInView: View {
  @Environment(AuthState.self) var auth
  @State private var email: String = ""
  @State private var sendStatus: SendStatus = .idle

  private let logger = Logger(subsystem: "swiss.atoll.cal", category: "auth")

  enum SendStatus: Equatable {
    case idle
    case sending
    case sent
    case error(String)
  }

  /// Classify Supabase / network errors into user-safe messages.
  ///
  /// `error.localizedDescription` from supabase-swift can include rate-limit
  /// timing data and occasionally user-existence signals — surfacing it raw
  /// leaks fingerprinting and reads poorly. We map known categories to
  /// neutral, actionable strings and log the real error for diagnostics.
  private func userSafeErrorMessage(_ error: Error) -> String {
    logger.error("sendMagicLink failed: \(error.localizedDescription, privacy: .public)")

    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
      return String(localized: "Keine Verbindung — bitte Internet prüfen.")
    }

    let lower = error.localizedDescription.lowercased()
    if lower.contains("rate") || lower.contains("429") || lower.contains("too many") {
      return String(localized: "Zu viele Versuche — bitte 1 Minute warten und erneut versuchen.")
    }

    return String(localized: "Magic-Link konnte nicht gesendet werden. Bitte Email-Adresse prüfen oder später erneut versuchen.")
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
        let safeMessage = userSafeErrorMessage(error)
        await MainActor.run { sendStatus = .error(safeMessage) }
      }
    }
  }
}
