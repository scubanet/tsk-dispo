import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIActivityViewController` for sharing the card URL
/// via AirDrop / iMessage / Mail / WhatsApp / copy.
struct CardShareSheet: UIViewControllerRepresentable {
  let card: Card
  let person: Person

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let items: [Any] = [
      "Meine \(card.title)-Karte — \(person.fullName):",
      card.publicURL
    ]
    return UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
