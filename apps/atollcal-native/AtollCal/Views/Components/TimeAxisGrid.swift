import SwiftUI

/// Vertikale 24-Stunden-Achse mit Stunden-Labels links und horizontalen Grid-Linien.
/// Children werden als overlay positioniert — Caller berechnet y = stunde * hourHeight.
///
/// Layout:
///   ┌───────────────────────────────┐
///   │ 00:00 ─────────────────────── │
///   │                               │
///   │ 01:00 ─────────────────────── │
///   │           [Event-Bar]         │
///   │ 02:00 ─────────────────────── │
///   │  ...                          │
struct TimeAxisGrid<Content: View>: View {
  let hourHeight: CGFloat
  let hourLabelWidth: CGFloat
  @ViewBuilder let content: () -> Content

  init(hourHeight: CGFloat = 60, hourLabelWidth: CGFloat = 50, @ViewBuilder content: @escaping () -> Content) {
    self.hourHeight = hourHeight
    self.hourLabelWidth = hourLabelWidth
    self.content = content
  }

  var body: some View {
    ScrollView {
      ZStack(alignment: .topLeading) {
        // Grid-Background: Hour labels + horizontale Linien
        VStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { hour in
            HStack(alignment: .top, spacing: 0) {
              Text(String(format: "%02d:00", hour))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: hourLabelWidth, alignment: .trailing)
                .padding(.trailing, 6)
                .padding(.top, -6)
              Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.top, 0)
              Spacer(minLength: 0)
            }
            .frame(height: hourHeight, alignment: .top)
          }
        }

        // Caller content: events + now-indicator als overlay
        HStack(spacing: 0) {
          Spacer().frame(width: hourLabelWidth + 6)  // Gutter überspringen
          content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      }
    }
  }
}
