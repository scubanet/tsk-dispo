import SwiftUI

/// Toggle-Liste der Kalender-Quellen (Apple-Kalender + Atoll).
struct CalendarFilterPopover: View {
  let store: CalendarSourcesStore
  let onChange: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Kalender").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
      ForEach(store.sources) { src in
        Button { store.toggle(src.id); onChange() } label: {
          HStack(spacing: 9) {
            Circle().fill(Color(hex: src.colorHex ?? "") ?? .secondary).frame(width: 10, height: 10)
            Text(src.title).font(.system(size: 13)).foregroundStyle(.primary)
            Spacer(minLength: 12)
            if store.isEnabled(src.id) {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(CoColor.accent)
            } else {
              Image(systemName: "circle").foregroundStyle(.tertiary)
            }
          }
          .padding(.horizontal, 14).padding(.vertical, 7).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(width: 260).padding(.bottom, 8)
  }
}
