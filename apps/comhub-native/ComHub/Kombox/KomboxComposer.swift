import SwiftUI
import AtollHub

/// Composer: Kanal-Switch (WhatsApp/Mail), Betreff (nur Mail), Eingabe, Senden.
struct KomboxComposer: View {
  let store: KomboxStore

  @State private var channel = "whatsapp"   // "whatsapp" | "email"
  @State private var subject = ""
  @State private var draft = ""

  var body: some View {
    VStack(spacing: 8) {
      if let err = store.actionError {
        Text(err).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: 8) {
        channelButton("WhatsApp", "whatsapp", CoColor.module(.kombox))
        channelButton("E-Mail", "email", CoColor.accent)
        Spacer()
      }
      if channel == "email" {
        TextField("Betreff", text: $subject)
          .textFieldStyle(.plain).font(.system(size: 13))
          .padding(.horizontal, 12).frame(height: 30)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      }
      HStack(spacing: 8) {
        TextField(channel == "email" ? "Antworten…" : "Nachricht…", text: $draft, axis: .vertical)
          .textFieldStyle(.plain).font(.system(size: 13.5)).lineLimit(1...4)
          .padding(.horizontal, 12).padding(.vertical, 7)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        Button(action: sendNow) {
          Image(systemName: "paperplane.fill").font(.system(size: 15)).foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(channel == "email" ? CoColor.accent : CoColor.module(.kombox), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(store.sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(store.sending ? 0.5 : 1)
      }
    }
    .padding(12)
  }

  private func channelButton(_ label: String, _ value: String, _ color: Color) -> some View {
    Button { channel = value } label: {
      Text(label).font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(channel == value ? .white : .secondary)
        .padding(.horizontal, 12).frame(height: 26)
        .background(channel == value ? AnyShapeStyle(color) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
  }

  private func sendNow() {
    let body = draft, subj = subject
    Task {
      let ok = await store.send(channel: channel, body: body, subject: subj)
      if ok { draft = ""; subject = "" }
    }
  }
}
