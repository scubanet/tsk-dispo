import SwiftUI
import AtollHub

/// Nur-Lesen-Ansicht fuer Atoll-Termine (Kurse aus dem CRM — nicht editierbar).
/// Zeigt die Eckdaten + Quelle und einen „Schliessen"-Knopf.
struct EventReadOnlySheet: View {
  let event: UnifiedEvent
  @Environment(\.dismiss) private var dismiss

  private var tint: Color {
    event.colorHex.flatMap(Color.init(hex:)) ?? CoColor.module(.kalender)
  }

  private static let dayTime: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE, d. MMM · HH:mm"
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()
  private static let day: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE, d. MMM"
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var timeText: String {
    if event.isAllDay {
      let start = Self.day.string(from: event.start)
      // Mehrtaegig: Bereich; sonst nur Tag.
      let lastDay = event.end.addingTimeInterval(-1)
      let endDay = Self.day.string(from: lastDay)
      return start == endDay ? "\(start) · ganztägig" : "\(start) – \(endDay)"
    }
    let start = Self.dayTime.string(from: event.start)
    let endTime = DateFormatter()
    endTime.dateFormat = "HH:mm"; endTime.timeZone = TimeZone(identifier: "Europe/Zurich")
    return "\(start)–\(endTime.string(from: event.end))"
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "calendar")
          .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
          .frame(width: 34, height: 34).background(tint, in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 1) {
          Text(event.title).font(.system(size: 16, weight: .bold)).lineLimit(2)
          Text("Aus Atoll · nur Lesen").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)
      Divider()

      VStack(alignment: .leading, spacing: 0) {
        row("clock", "Zeit", timeText)
        if let loc = event.location, !loc.isEmpty { Divider(); row("mappin.and.ellipse", "Ort", loc) }
      }
      .padding(.horizontal, 18).padding(.vertical, 8)

      Spacer(minLength: 0)
      Divider()
      HStack {
        Spacer()
        Button("Schliessen") { dismiss() }.buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 18).padding(.vertical, 12)
    }
    .tint(CoColor.accent)
    #if os(macOS)
    .frame(minWidth: 420, minHeight: 280)
    #endif
    #if os(iOS)
    .presentationDragIndicator(.visible)
    #endif
  }

  private func row(_ icon: String, _ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 11) {
      Image(systemName: icon).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 18)
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.system(size: 11)).foregroundStyle(.tertiary)
        Text(value).font(.system(size: 14)).textSelection(.enabled)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 8)
  }
}
