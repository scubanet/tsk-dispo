import SwiftUI

/// A single pastel pill — matches the AtollCal context-pill styling.
struct PillView: View {
  let label: String
  let tone: PillTone
  var badge: String? = nil   // optional dark left-side badge ("LEAD" / "CD")

  var body: some View {
    HStack(spacing: 6) {
      if let badge {
        Text(badge)
          .font(.system(size: 10, weight: .heavy))
          .kerning(0.8)
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(tone.foreground, in: Capsule())
      }
      Text(label)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tone.foreground)
    }
    .padding(.horizontal, badge == nil ? 12 : 12)
    .padding(.leading, badge == nil ? 12 : 4)
    .padding(.vertical, 6)
    .background(tone.background, in: Capsule())
  }
}

/// Wrapping row of pills — wraps into multiple lines instead of scrolling.
struct PillRow: View {
  let items: [PillItem]

  struct PillItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let tone: PillTone
    var badge: String? = nil
  }

  var body: some View {
    FlowLayout(spacing: 6) {
      ForEach(items) { item in
        PillView(label: item.label, tone: item.tone, badge: item.badge)
      }
    }
  }
}

/// Minimal FlowLayout — wraps children to new lines when they overflow.
/// SwiftUI doesn't ship a built-in wrap layout for arbitrary views; this is
/// the documented Apple recipe (Layout protocol).
struct FlowLayout: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    return arrange(subviews: subviews, in: width).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                     subviews: Subviews, cache: inout ()) {
    let arr = arrange(subviews: subviews, in: bounds.width)
    for (idx, item) in arr.placements.enumerated() {
      subviews[idx].place(
        at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y),
        proposal: .unspecified
      )
    }
  }

  private struct Arrangement {
    var size: CGSize
    var placements: [Placement]
  }
  private struct Placement {
    var x: CGFloat
    var y: CGFloat
  }

  private func arrange(subviews: Subviews, in width: CGFloat) -> Arrangement {
    var placements: [Placement] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      if x + size.width > width, x > 0 {
        x = 0
        y += lineHeight + spacing
        lineHeight = 0
      }
      placements.append(Placement(x: x, y: y))
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
      lineHeight = max(lineHeight, size.height)
    }
    return Arrangement(size: CGSize(width: maxX, height: y + lineHeight), placements: placements)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 12) {
    PillView(label: "Deep", tone: .blue)
    PillView(label: "CD · TL/DM", tone: .blue, badge: "LEAD")
    PillRow(items: [
      .init(label: "Deep", tone: .blue),
      .init(label: "Nitrox", tone: .green),
      .init(label: "Wreck", tone: .amber),
      .init(label: "+8", tone: .purple)
    ])
  }
  .padding()
  .background(Color.cardPageBackground)
}
