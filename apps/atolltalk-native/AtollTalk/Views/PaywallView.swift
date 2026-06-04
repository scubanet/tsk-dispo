import SwiftUI
import StoreKit

struct PaywallView: View {
  let subscription: SubscriptionStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 20) {
      Text("AtollTalk Pro").font(.largeTitle.bold())
      Text("Premium-Übersetzung (Claude) + natürliche Stimmen. Alle Sprachen, inkl. Tagalog & Bisaya.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)

      ForEach(subscription.products.sorted { $0.price < $1.price }, id: \.id) { product in
        Button {
          Task {
            try? await subscription.purchase(product)
            if subscription.isPro { dismiss() }
          }
        } label: {
          HStack {
            Text(product.displayName)
            Spacer()
            Text(product.displayPrice)
          }
          .font(.headline)
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.brandBlue50)
          .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
      }

      Button("Käufe wiederherstellen") {
        Task { await subscription.restore(); if subscription.isPro { dismiss() } }
      }
      .font(.footnote)

      HStack(spacing: 16) {
        Link("Nutzungsbedingungen", destination: URL(string: "https://atoll-os.com/terms")!)
        Link("Datenschutz", destination: URL(string: "https://atoll-os.com/privacy")!)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding()
  }
}
