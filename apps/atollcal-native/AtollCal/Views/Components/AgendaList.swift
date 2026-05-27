import SwiftUI
import AtollCore
import AtollDesign

// MARK: - Data structs

/// One day's worth of agenda content, used as a row in the scroll list.
///
/// Originally lived inside `SidebarView.swift`. Extracted in Pragmatic Phase 1
/// (GL-006) so the iPhone root layout can reuse the same bucket model.
struct DayBucket: Identifiable, Hashable {
  let id: Date
  let date: Date
  let allDayEvents: [CalendarEvent]
  let timedEvents: [CalendarEvent]

  static func == (lhs: DayBucket, rhs: DayBucket) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Agenda list

/// Fantastical-style endless-scroll agenda.
///
/// Renders a vertically scrolling list of `DayBucket` rows. Each bucket has a
/// tappable header (label + date), all-day chips, and one row per timed event.
/// A clear sentinel at the bottom triggers `onLoadMore` when it scrolls into view.
///
/// Layout-agnostic: the macOS `SidebarView` and the iPhone root layout both
/// embed this component. The caller owns the data plumbing (rebuildBuckets).
struct AgendaList: View {
  let buckets: [DayBucket]
  let locale: Locale
  @Binding var scrolledBucketId: Date?
  let onSelectDay: (Date) -> Void
  let onSelectEvent: (CalendarEvent) -> Void
  let onLoadMore: () -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        ForEach(buckets) { bucket in
          DayBucketRow(
            bucket: bucket,
            locale: locale,
            onSelectDay: onSelectDay,
            onSelectEvent: onSelectEvent
          )
          .id(bucket.id)
        }
        // Sentinel — triggers the next chunk to load when it scrolls into view.
        Color.clear
          .frame(height: 1)
          .onAppear { onLoadMore() }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 14)
      .scrollTargetLayout()
    }
    .scrollPosition(id: $scrolledBucketId, anchor: .top)
  }
}

// MARK: - Bucket row + event rows

private struct DayBucketRow: View {
  let bucket: DayBucket
  let locale: Locale
  let onSelectDay: (Date) -> Void
  let onSelectEvent: (CalendarEvent) -> Void

  /// GL-006 Phase 1.5d: weather store provides daily forecast for the
  /// hardcoded Zürich location. `nil`-safe — sidebar / pre-fetch renders
  /// without weather and the layout collapses cleanly.
  @Environment(WeatherStore.self) private var weatherStore

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button { onSelectDay(bucket.date) } label: {
        HStack(spacing: 6) {
          // GL-005 H2: Dynamic-Type aware. `.caption` ≈ 12 pt at default,
          // scales with the user's preferred content-size category.
          Text(headerLabel)
            .font(.caption.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
          Spacer(minLength: 0)
          if let f = weatherStore.forecast(for: bucket.date) {
            weatherChip(forecast: f)
          }
        }
      }
      .buttonStyle(.plain)

      // Fantastical-style: all-day chips flow inline and wrap to the next
      // row when the line is full. Single-event days look like a small pill;
      // busy days fill the row.
      if !bucket.allDayEvents.isEmpty {
        AllDayFlow(spacing: 6, lineSpacing: 4) {
          ForEach(bucket.allDayEvents) { ev in
            AllDayChip(event: ev)
              .onTapGesture { onSelectEvent(ev) }
          }
        }
      }

      ForEach(bucket.timedEvents) { ev in
        TimedEventRow(event: ev, locale: locale)
          .onTapGesture { onSelectEvent(ev) }
      }
    }
  }

  private var isToday: Bool {
    Calendar.current.isDateInToday(bucket.date)
  }

  private var headerLabel: String {
    let cal = Calendar.current
    let f = DateFormatter()
    f.locale = locale
    if cal.isDateInToday(bucket.date) {
      f.dateFormat = "dd.MM.yy"
      return "HEUTE  ·  \(f.string(from: bucket.date))"
    }
    if cal.isDateInTomorrow(bucket.date) {
      f.dateFormat = "dd.MM.yy"
      return "MORGEN  ·  \(f.string(from: bucket.date))"
    }
    f.dateFormat = "EEEE  ·  dd.MM.yy"
    return f.string(from: bucket.date).uppercased()
  }

  /// Compact weather chip — high/low temperatures (e.g., "23°/9°") + the
  /// day's SF Symbol. Symbol uses its multicolour rendering so the sun is
  /// yellow, cloud is grey, moon is white — matches Fantastical's chip.
  @ViewBuilder
  private func weatherChip(forecast: DailyForecast) -> some View {
    HStack(spacing: 4) {
      Text(forecast.tempLabel())
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(.secondary)
      Image(systemName: forecast.symbolName)
        .symbolRenderingMode(.multicolor)
        .font(.footnote)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Wetter: Höchsttemperatur \(Int(forecast.highC.rounded()))°, Tiefsttemperatur \(Int(forecast.lowC.rounded()))°")
  }
}

/// Fantastical-style inline pill for an all-day or multi-day event.
/// Sizes to content so multiple chips can flow side-by-side in `AllDayFlow`.
private struct AllDayChip: View {
  let event: CalendarEvent

  var body: some View {
    HStack(spacing: 6) {
      if let role = event.atollRole {
        // GL-005 H2: Capsule pill — uses `.caption2` so it scales with
        // Dynamic Type while keeping the heavy weight for legibility.
        Text(roleAbbrev(role))
          .font(.caption2.weight(.heavy))
          .tracking(0.3)
          .foregroundStyle(.white)
          .padding(.horizontal, 5)
          .padding(.vertical, 1.5)
          .background(Color.atollRole(role))
          .clipShape(Capsule())
      }
      // GL-005 H2: Dynamic Type — `.footnote` ≈ 13 pt at default.
      Text(event.title)
        .font(.footnote.weight(.medium))
        .lineLimit(1)
        .foregroundStyle(.primary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(event.color.opacity(0.22))
    .overlay(
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(event.color.opacity(0.28), lineWidth: 0.5)
    )
    .clipShape(.rect(cornerRadius: 7))
    .contentShape(Rectangle())
  }

  private func roleAbbrev(_ role: AssignmentRole) -> String {
    switch role {
    case .haupt:  return "LEAD"
    case .assist: return "ASS"
    case .opfer:  return "STBY"
    case .dmt:    return "DMT"
    }
  }
}

private struct TimedEventRow: View {
  let event: CalendarEvent
  let locale: Locale

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(event.color)
        .frame(width: 7, height: 7)
      // GL-005 H2: Dynamic Type-aware. `minWidth: 42` lets the time slot grow
      // a bit with AX sizes; long titles still ellipsise.
      Text(timeString)
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: 42, alignment: .leading)
      Text(event.title)
        .font(.footnote)
        .lineLimit(1)
        .foregroundStyle(.primary)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 1)
    .contentShape(Rectangle())
  }

  private var timeString: String {
    let f = DateFormatter()
    f.locale = locale
    f.timeStyle = .short
    return f.string(from: event.startDate)
  }
}

// MARK: - Wrapping flow layout for all-day chips

/// Simple flow layout — children flow left-to-right and wrap to a new row
/// when the line is full. Used by `DayBucketRow` so multiple all-day chips
/// sit side-by-side like Fantastical instead of stacking vertically.
///
/// `spacing` is the horizontal gap between chips on the same line;
/// `lineSpacing` is the vertical gap between wrapped rows.
private struct AllDayFlow: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 4

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    let arrangement = arrange(subviews: subviews, in: maxWidth)
    return CGSize(width: maxWidth.isFinite ? maxWidth : arrangement.naturalWidth, height: arrangement.totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let arrangement = arrange(subviews: subviews, in: bounds.width)
    for (subview, position) in zip(subviews, arrangement.positions) {
      let size = subview.sizeThatFits(.unspecified)
      subview.place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: ProposedViewSize(size)
      )
    }
  }

  private struct Arrangement {
    var positions: [CGPoint]
    var totalHeight: CGFloat
    var naturalWidth: CGFloat
  }

  private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> Arrangement {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widestRow: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > maxWidth {
        // wrap to next line
        widestRow = max(widestRow, x - spacing)
        x = 0
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    widestRow = max(widestRow, x - spacing)
    let totalHeight = y + rowHeight
    return Arrangement(positions: positions, totalHeight: totalHeight, naturalWidth: widestRow)
  }
}
