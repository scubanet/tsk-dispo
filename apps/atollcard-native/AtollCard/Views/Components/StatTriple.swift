import SwiftUI
import AtollDesign

/// 3-column stat strip used in the persona detail card.
struct StatTriple: View {
  let items: [Item]

  struct Item: Identifiable {
    var id: String { label }
    let number: String
    let label: String
  }

  var body: some View {
    HStack(spacing: 12) {
      ForEach(items) { item in
        VStack(alignment: .leading, spacing: 4) {
          Text(item.number)
            .font(.system(size: 22, weight: .bold))
            .tracking(-0.5)
          Text(item.label)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(Color.cardTextMuted)
            .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 12)
    .overlay(alignment: .top) {
      Divider().background(Color(hex: 0xF0EBE2))
    }
    .overlay(alignment: .bottom) {
      Divider().background(Color(hex: 0xF0EBE2))
    }
  }
}

/// Quick-action grid (QR · Share · NFC · Wallet).
struct QuickActionGrid: View {
  let items: [Item]

  struct Item: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let label: String
    var primary: Bool = false
    var action: (() -> Void)? = nil

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: Item, rhs: Item) -> Bool { lhs.id == rhs.id }
  }

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: items.count),
              spacing: 8) {
      ForEach(items) { item in
        Button {
          item.action?()
        } label: {
          VStack(spacing: 6) {
            Image(systemName: item.icon)
              .font(.system(size: 18, weight: .semibold))
            Text(item.label)
              .font(.system(size: 11, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(item.primary ? Color.primary : Color.cardSoftBackground)
          .foregroundStyle(item.primary ? Color.white : Color.primary)
          .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    StatTriple(items: [
      .init(number: "34",  label: "Scans"),
      .init(number: "11",  label: "Leads"),
      .init(number: "32%", label: "Conv.")
    ])
    QuickActionGrid(items: [
      .init(icon: "qrcode",          label: "QR",     primary: true),
      .init(icon: "square.and.arrow.up", label: "Share"),
      .init(icon: "wave.3.right",    label: "NFC"),
      .init(icon: "creditcard",      label: "Wallet")
    ])
  }
  .padding()
  .background(Color.cardPageBackground)
}
