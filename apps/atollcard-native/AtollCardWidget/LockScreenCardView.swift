import SwiftUI
import WidgetKit

/// Rectangular Lock-Screen widget view (~158×54pt visible).
/// Renders in iOS vibrancy/tinted mode — keep visuals monochrome,
/// no gradients, no images.
struct LockScreenCardView: View {
  let entry: CardSnapshotEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      Link(destination: deepLink(for: snapshot)) {
        haveCardLayout(snapshot)
      }
    } else {
      Link(destination: URL(string: "atollcard://")!) {
        fallbackLayout
      }
    }
  }

  // MARK: - Have-card layout

  private func haveCardLayout(_ snapshot: SharedCardSnapshot) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "qrcode")
        .font(.system(size: 22, weight: .regular))
        .widgetAccentable()

      VStack(alignment: .leading, spacing: 2) {
        Text(headerLine(snapshot))
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
        Text("Tippen → QR")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .containerBackground(.clear, for: .widget)
  }

  private func headerLine(_ snapshot: SharedCardSnapshot) -> String {
    if let badge = snapshot.badge, !badge.isEmpty {
      return "\(snapshot.title) · \(badge)"
    }
    return snapshot.title
  }

  // MARK: - Fallback layout

  private var fallbackLayout: some View {
    HStack(spacing: 8) {
      Image(systemName: "qrcode")
        .font(.system(size: 22, weight: .regular))
        .widgetAccentable()

      VStack(alignment: .leading, spacing: 2) {
        Text("AtollCard")
          .font(.system(size: 13, weight: .semibold))
        Text("Karte einrichten")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .containerBackground(.clear, for: .widget)
  }

  // MARK: - Deep link

  private func deepLink(for snapshot: SharedCardSnapshot) -> URL {
    URL(string: "atollcard://card/\(snapshot.slug)/qr")!
  }
}

#Preview("Have card", as: .accessoryRectangular) {
  LockScreenCardWidget()
} timeline: {
  CardSnapshotEntry(date: .now, snapshot: SharedCardSnapshot(
    slug: "dominik-cd",
    title: "PADI Course Director",
    badge: "PADI CD",
    personInitials: "DW",
    publicURL: URL(string: "https://atoll-os.com/c/dominik-cd")!,
    updatedAt: .now
  ))
}

#Preview("No card", as: .accessoryRectangular) {
  LockScreenCardWidget()
} timeline: {
  CardSnapshotEntry(date: .now, snapshot: nil)
}
