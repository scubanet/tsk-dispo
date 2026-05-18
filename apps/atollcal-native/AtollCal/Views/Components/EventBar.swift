import SwiftUI
import AtollDesign

/// Visual representation of a CalendarEvent as a bar / card on the time axis.
/// Width + height + position are computed by the caller; the bar adapts its
/// internal rendering to the height it's given to avoid label overlap.
///
/// Rendering tiers:
/// - **height >= 40pt**  → Liquid-Glass surface with role-tint, title + location
/// - **28 <= height < 40** → flat color background, title + location
/// - **height < 28pt**   → flat color background, title only (caption2)
/// - `style == .colorOnly` → just a coloured rectangle (used on narrow WeekView
///   columns where text would never fit anyway).
struct EventBar: View {
  let event: CalendarEvent
  var measuredHeight: CGFloat = 60
  var style: Style = .auto
  var onTap: () -> Void = {}

  enum Style {
    /// Caller hands us a height; we pick the renderer tier.
    case auto
    /// Tiny mode — just the coloured stripe with tap gesture.
    /// Used on iPhone-SE-class WeekView columns (< 50pt wide).
    case colorOnly
  }

  var body: some View {
    Group {
      switch style {
      case .colorOnly:
        Rectangle()
          .fill(event.color)
          .clipShape(.rect(cornerRadius: 2))
          .frame(maxWidth: .infinity)
      case .auto:
        autoStyleBar
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(event.title)
  }

  // MARK: - Auto-style

  @ViewBuilder
  private var autoStyleBar: some View {
    if measuredHeight < 28 {
      titleOnlyCompact
    } else if measuredHeight < 40 {
      fullBarFlat
    } else {
      fullBarGlass
    }
  }

  private var titleOnlyCompact: some View {
    HStack(spacing: 4) {
      Rectangle().fill(event.color).frame(width: 2)
      Text(event.title)
        .font(.caption2)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 1)
    .padding(.horizontal, 3)
    .background(event.color.opacity(0.18))
    .clipShape(.rect(cornerRadius: 3))
  }

  private var fullBarFlat: some View {
    barInner
      .background(event.color.opacity(0.18))
      .clipShape(.rect(cornerRadius: 4))
  }

  private var fullBarGlass: some View {
    barInner
      .atollGlassEventBar(tint: event.color)
  }

  private var barInner: some View {
    HStack(alignment: .top, spacing: 6) {
      Rectangle().fill(event.color).frame(width: 3)
      VStack(alignment: .leading, spacing: 2) {
        Text(event.title).font(.caption).lineLimit(2)
        if let loc = event.location, !loc.isEmpty {
          Text(loc)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 3)
    .padding(.horizontal, 4)
  }
}
