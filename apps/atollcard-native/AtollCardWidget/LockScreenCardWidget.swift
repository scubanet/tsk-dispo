import SwiftUI
import WidgetKit

// MARK: - Widget configuration

struct LockScreenCardWidget: Widget {
  let kind: String = "swiss.atoll.card.lockscreen"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CardSnapshotProvider()) { entry in
      LockScreenCardView(entry: entry)
    }
    .configurationDisplayName(String(localized: "AtollCard Quick-QR"))
    .description(String(localized: "Default-Karte mit One-Tap zum Vollbild-QR."))
    .supportedFamilies([.accessoryRectangular])
  }
}

// MARK: - Timeline entry

struct CardSnapshotEntry: TimelineEntry {
  let date:     Date
  let snapshot: SharedCardSnapshot?
}

// MARK: - Timeline provider

struct CardSnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> CardSnapshotEntry {
    CardSnapshotEntry(date: .now, snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (CardSnapshotEntry) -> Void) {
    completion(CardSnapshotEntry(date: .now, snapshot: loadFromAppGroup()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CardSnapshotEntry>) -> Void) {
    let entry = CardSnapshotEntry(date: .now, snapshot: loadFromAppGroup())
    completion(Timeline(entries: [entry], policy: .never))
  }

  // MARK: - App-Group I/O

  private func loadFromAppGroup() -> SharedCardSnapshot? {
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: "group.swiss.atoll.card") else {
      return nil
    }
    let url = container.appendingPathComponent("default-card.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)
  }
}
