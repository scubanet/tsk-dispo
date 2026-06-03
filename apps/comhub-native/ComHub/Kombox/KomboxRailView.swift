import SwiftUI
import AtollHub

/// Kanal-Rail: Posteingang-Filter Alle/WhatsApp/Mail.
struct KomboxRailView: View {
  @Binding var channel: KomboxChannel

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("POSTEINGANG").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
        .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 8)
      ForEach(KomboxChannel.allCases) { ch in
        Button { channel = ch } label: {
          HStack(spacing: 9) {
            Image(systemName: icon(ch))
              .font(.system(size: 14)).foregroundStyle(channel == ch ? AnyShapeStyle(.white) : AnyShapeStyle(iconColor(ch)))
              .frame(width: 18)
            Text(ch.title).font(.system(size: 13, weight: channel == ch ? .semibold : .medium))
              .foregroundStyle(channel == ch ? .white : .primary)
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 10).frame(height: 32)
          .background(channel == ch ? CoColor.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
    .padding(10)
  }

  private func icon(_ ch: KomboxChannel) -> String {
    switch ch { case .all: return "tray.full"; case .whatsapp: return "bubble.left.fill"; case .mail: return "envelope.fill" }
  }
  private func iconColor(_ ch: KomboxChannel) -> Color {
    switch ch { case .all: return .secondary; case .whatsapp: return CoColor.module(.kombox); case .mail: return CoColor.accent }
  }
}
