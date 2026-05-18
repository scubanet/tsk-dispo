import SwiftUI

/// Reusable compact month grid used by QuarterView and YearView.
///
/// - `month` is any date in the target month; the grid renders the 6-week
///   Mo–So layout containing the first of that month.
/// - `eventCountByDay` drives the small accent-coloured dot row beneath each
///   day number. Pass an empty dict to hide dots.
/// - `compact` shrinks day cells for the year view (4 × 3 grid of 12 months).
/// - `onTapDay` / `onTapTitle` are optional — if both are nil the preview is
///   purely informational.
struct MonthPreview: View {
  let month: Date
  var eventCountByDay: [Date: Int] = [:]
  var compact: Bool = false
  var onTapDay: ((Date) -> Void)? = nil
  var onTapTitle: (() -> Void)? = nil

  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: compact ? 3 : 6) {
      titleView
      weekdayHeader
      ForEach(monthWeeks, id: \.first) { week in
        if week.first != nil {
          HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
              dayCell(day).frame(maxWidth: .infinity)
            }
          }
        }
      }
    }
  }

  // MARK: - Pieces

  @ViewBuilder
  private var titleView: some View {
    if let onTapTitle {
      Button(action: onTapTitle) {
        titleText
      }
      .buttonStyle(.plain)
    } else {
      titleText
    }
  }

  private var titleText: some View {
    Text(monthTitle)
      .font(compact ? .system(size: 12, weight: .semibold) : .headline)
      .foregroundStyle(isCurrentMonth ? Color.accentColor : .primary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, compact ? 2 : 4)
  }

  private var weekdayHeader: some View {
    HStack(spacing: 0) {
      ForEach(weekdayLabels, id: \.self) { lbl in
        Text(lbl)
          .font(compact ? .system(size: 7, weight: .semibold) : .system(size: 9, weight: .semibold))
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder
  private func dayCell(_ day: Date) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let weekday = cal.component(.weekday, from: day)
    let isWeekend = weekday == 1 || weekday == 7
    let maxDots = compact ? 1 : 3
    let dotCount = min(maxDots, eventCountByDay[cal.startOfDay(for: day)] ?? 0)

    let dayNumSize: CGFloat = compact ? 9 : 12
    let circleSize: CGFloat = compact ? 14 : 22

    VStack(spacing: 1) {
      ZStack {
        if isToday {
          Circle().fill(Color.accentColor).frame(width: circleSize, height: circleSize)
        }
        Text("\(cal.component(.day, from: day))")
          .font(.system(size: dayNumSize, weight: isToday ? .bold : .regular))
          .foregroundStyle(dayColor(
            isToday: isToday,
            isCurrentMonth: isCurrentMonth,
            isWeekend: isWeekend
          ))
      }
      .frame(height: circleSize)

      // Dot row — only renders space if there are dots or we're non-compact.
      HStack(spacing: 1.5) {
        ForEach(0..<dotCount, id: \.self) { _ in
          Circle()
            .fill(isToday ? Color.accentColor : Color.accentColor.opacity(0.55))
            .frame(width: compact ? 2.5 : 3.5, height: compact ? 2.5 : 3.5)
        }
      }
      .frame(height: compact ? 3 : 4)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      onTapDay?(day)
    }
  }

  private func dayColor(isToday: Bool, isCurrentMonth: Bool, isWeekend: Bool) -> Color {
    if isToday { return .white }
    if !isCurrentMonth { return Color.secondary.opacity(0.4) }
    if isWeekend { return Color.secondary.opacity(0.8) }
    return .primary
  }

  // MARK: - Date helpers

  private var isCurrentMonth: Bool {
    Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
  }

  private var monthTitle: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = compact ? "MMMM" : "MMMM yyyy"
    return f.string(from: month)
  }

  private var weekdayLabels: [String] {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "EE"
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    guard let ref = cal.date(from: DateComponents(year: 2026, month: 1, day: 5)) else {
      return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    }
    return (0..<7).compactMap { offset in
      cal.date(byAdding: .day, value: offset, to: ref).map(f.string(from:))
    }
  }

  private var monthWeeks: [[Date]] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let comps = cal.dateComponents([.year, .month], from: month)
    guard let monthStart = cal.date(from: comps) else { return [] }
    let weekday = cal.component(.weekday, from: monthStart)
    let daysFromMonday = (weekday + 5) % 7
    guard let firstMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }
    return (0..<6).map { weekIdx in
      (0..<7).compactMap { dayIdx in
        cal.date(byAdding: .day, value: weekIdx * 7 + dayIdx, to: firstMonday)
      }
    }
  }
}
