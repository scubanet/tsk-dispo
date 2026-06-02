import SwiftUI

/// Kleines Label: grau (Default) oder mit farbigem Punkt + Toenung.
struct CoChip: View {
  let text: String
  var color: Color? = nil

  var body: some View {
    HStack(spacing: 5) {
      if let color {
        Circle().fill(color).frame(width: 6, height: 6)
      }
      Text(text)
        .font(.system(size: 11, weight: .medium))
    }
    .padding(.horizontal, 7)
    .frame(height: 18)
    .foregroundStyle(color ?? .secondary)
    .background(color == nil ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(color?.opacity(0.33) ?? .clear, lineWidth: color == nil ? 0 : 1)
    )
  }
}

/// Zaehl-Badge (Pille) fuer Sidebar/Widget-Header.
struct CoCountBadge: View {
  let count: Int
  var body: some View {
    Text("\(count)")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 5)
      .frame(minWidth: 18, minHeight: 18)
      .background(.quaternary, in: Capsule())
  }
}
