import SwiftUI
import AtollHub

/// Eine Aufgaben-Zeile (lese-only Checkbox = Status-Anzeige).
struct TaskRow: View {
  let task: UnifiedTask
  var showList: Bool = true
  var onToggle: (() -> Void)? = nil
  var onEdit: (() -> Void)? = nil

  private var listColor: Color {
    if let hex = task.listColorHex, let c = Color(hex: hex) { return c }
    return task.source.type == .atoll ? CoColor.accent : .secondary
  }
  private static let due: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM."
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 11) {
      Button { onToggle?() } label: {
        ZStack {
          Circle().strokeBorder(task.isDone ? Color.clear : .secondary, lineWidth: 1.8)
            .background(Circle().fill(task.isDone ? listColor : Color.clear))
            .frame(width: 20, height: 20)
          if task.isDone { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
        }
        .frame(width: 30, height: 30)        // groessere, voll klickbare Treffer-Flaeche
        .contentShape(Rectangle())           // ganzer Bereich klickbar (nicht nur der Ring)
      }
      .buttonStyle(.plain)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 7) {
          Text(task.title).font(.system(size: 13.5))
            .foregroundStyle(task.isDone ? .tertiary : .primary)
            .strikethrough(task.isDone)
          if task.isFlagged && !task.isDone {
            Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.62, blue: 0.04))
          }
        }
        if let notes = task.notes, !notes.isEmpty {
          Text(notes).font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
        }
        HStack(spacing: 8) {
          if let d = task.due {
            Text(Self.due.string(from: d)).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
          }
          if showList, let name = task.listName {
            HStack(spacing: 4) {
              Circle().fill(listColor).frame(width: 7, height: 7)
              Text(name).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
          }
        }
      }
      .contentShape(Rectangle())
      .onTapGesture { onEdit?() }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 9)
  }
}

/// Hex -> Color Helfer (z.B. "#34C759").
extension Color {
  init?(hex: String) {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    self = Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                 blue: Double(v & 0xFF) / 255)
  }
}
