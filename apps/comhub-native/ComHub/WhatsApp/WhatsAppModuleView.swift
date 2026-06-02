import SwiftUI

/// Privat-WhatsApp: WhatsApp Web im WebView, getrennt von der Atoll-Kombox.
struct WhatsAppModuleView: View {
  @State private var coordinator = WhatsAppWebView.Coordinator()

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "phone.bubble.fill").foregroundStyle(CoColor.module(.whatsapp))
        Text("WhatsApp").font(.system(size: 15, weight: .bold))
        Text("privat · WhatsApp Web").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button { coordinator.reload() } label: { Image(systemName: "arrow.clockwise") }
          .buttonStyle(.borderless)
      }
      .padding(.horizontal, 16).frame(height: 52)
      Divider()
      WhatsAppWebView(coordinator: coordinator)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
