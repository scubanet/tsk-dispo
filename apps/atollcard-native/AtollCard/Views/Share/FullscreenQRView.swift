import SwiftUI
import UIKit
import AtollDesign

/// Fullscreen QR sheet — large dark QR with Atoll logo overlay, name + role,
/// quick AirDrop / NFC / WhatsApp / Wallet row. Brightens the display while
/// visible so scanning succeeds even outdoors.
struct FullscreenQRView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(ToastCenter.self) private var toast

  let card: Card
  let person: Person

  @State private var previousBrightness: CGFloat?
  @State private var showShareSheet = false
  @State private var showNFC = false

  var body: some View {
    VStack(spacing: 16) {
      // Top bar
      HStack {
        Text("Karte teilen")
          .font(.system(.headline, weight: .bold))
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color.cardTextMuted, Color(hex: 0xEDEAE2))
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 8)

      Spacer(minLength: 0)

      // QR card
      QRCodeView(url: card.publicURL, logoFraction: 0.2)
        .padding(20)
        .background(Color(hex: 0x1A1F2E), in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: 280, maxHeight: 280)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)

      VStack(spacing: 4) {
        Text(person.fullName)
          .font(.system(size: 20, weight: .bold))
          .tracking(-0.3)
        HStack(spacing: 6) {
          Text(card.title)
          if let badge = card.badge {
            Text("·")
              .foregroundStyle(Color.cardTextMuted)
            Text(badge)
              .foregroundStyle(Color.cardPillBlueText)
              .fontWeight(.semibold)
          }
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.cardTextMuted)
      }

      Spacer(minLength: 0)

      // Action row
      HStack(spacing: 4) {
        actionTile("AirDrop", icon: "airplayaudio") { showShareSheet = true }
        actionTile("NFC", icon: "wave.3.right") {
          if NFCWriterController.isAvailable {
            showNFC = true
          } else {
            toast.show("NFC nicht verfügbar (Simulator?)", kind: .error)
          }
        }
        actionTile("WhatsApp", icon: "bubble.right") { showShareSheet = true }
        actionTile("Kopieren", icon: "doc.on.doc") {
          UIPasteboard.general.url = card.publicURL
          toast.show("Link kopiert", kind: .success)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 32)
    }
    .background(Color(hex: 0xF5F1E8).ignoresSafeArea())
    .sheet(isPresented: $showShareSheet) {
      CardShareSheet(card: card, person: person)
    }
    .sheet(isPresented: $showNFC) {
      NFCWriteSheet(card: card)
        .presentationDetents([.medium])
    }
    .onAppear {
      previousBrightness = UIScreen.main.brightness
      UIScreen.main.brightness = 1.0
    }
    .onDisappear {
      if let prev = previousBrightness {
        UIScreen.main.brightness = prev
      }
    }
  }

  @ViewBuilder
  private func actionTile(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .medium))
          .frame(width: 52, height: 52)
          .background(.white, in: RoundedRectangle(cornerRadius: 18))
          .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        Text(label)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Color.cardTextSecondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
  }
}
