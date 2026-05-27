import SwiftUI

/// Visual sheet around `NFCWriterController`. The system already shows its
/// own translucent NFC prompt while the session is active, so this sheet
/// mostly explains the flow + surfaces success / error state afterwards.
struct NFCWriteSheet: View {
  let card: Card

  @Environment(\.dismiss) private var dismiss
  @Environment(ToastCenter.self) private var toast

  @State private var writer = NFCWriterController()
  @State private var state: WriteState = .idle

  enum WriteState {
    case idle
    case writing
    case success(NFCTagWriteResult)
    case error(String)
  }

  var body: some View {
    VStack(spacing: 20) {
      Capsule().fill(Color.gray.opacity(0.3))
        .frame(width: 36, height: 5)
        .padding(.top, 8)

      icon
        .font(.system(size: 64, weight: .regular))
        .foregroundStyle(Color.cardPillBlueText)
        .frame(height: 80)

      Text(title)
        .font(.system(size: 20, weight: .bold))
        .multilineTextAlignment(.center)
      Text(detail)
        .font(.system(.callout))
        .foregroundStyle(Color.cardTextSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      Spacer()

      switch state {
      case .idle:
        Button("NFC schreiben starten", action: start)
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      case .writing:
        ProgressView("Wartet auf Tag…")
      case .success:
        Button("Schliessen", action: { dismiss() })
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      case .error:
        HStack {
          Button("Abbrechen") { dismiss() }
          Button("Erneut versuchen", action: start)
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .padding(.bottom, 28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.cardPageBackground.ignoresSafeArea())
  }

  @ViewBuilder
  private var icon: some View {
    switch state {
    case .idle, .writing:
      Image(systemName: "wave.3.right.circle.fill")
        .foregroundStyle(Color.cardPillBlueText)
    case .success:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Color.cardPillGreenText)
    case .error:
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.cardPillRoseText)
    }
  }

  private var title: String {
    switch state {
    case .idle, .writing:        "NFC-Tag beschreiben"
    case .success(let r):        "Geschrieben ✓ (UID \(r.tagUID.prefix(8))…)"
    case .error(let msg):        "Fehler"
    }
  }

  private var detail: String {
    switch state {
    case .idle:
      "Halte einen leeren NFC-Tag bereit. Sobald du startest, hält dein iPhone die URL „\(card.publicURL.host ?? "")\(card.publicURL.path)“ auf dem Tag."
    case .writing:
      "Halte das iPhone an den Tag und warte, bis dieser Bildschirm sich aktualisiert."
    case .success(let r):
      "Kapazität: \(r.capacity) Bytes. Du kannst den Tag jetzt aufkleben."
    case .error(let msg):
      msg
    }
  }

  private func start() {
    state = .writing
    writer.write(url: card.publicURL) { result in
      switch result {
      case .success(let res):
        state = .success(res)
        toast.show("NFC-Tag geschrieben", kind: .success)
      case .failure(let err):
        if case NFCWriterError.userCancelled = err {
          state = .idle
        } else {
          state = .error(err.localizedDescription)
        }
      }
    }
  }
}
