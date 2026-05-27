import SwiftUI
import AtollCore
import AtollDesign

/// Fantastical-style mini-month grid.
///
/// 6 weeks × 7 days with a left-column ISO week number ("KW"), single-letter
/// weekday header, and an accent-coloured circle for today / outline for the
/// selected day. Event dots appear under each day (cap 3).
///
/// Originally lived as a `private struct` inside `SidebarView.swift`.
/// Extracted in Pragmatic Phase 1 (GL-006) so the iPhone root layout can
/// reuse it alongside the agenda. macOS sidebar still owns the data plumbing
/// (`eventCountByDay`); this view is a pure renderer.
///
/// **Pixel-locked grid (default):** `columnWidth: 30` and `dayHeight: 34` are
/// intentional — Dynamic-Type expansion would break the 6-row × 7-column shape.
/// Day numbers, KW labels, and weekday letters use `.minimumScaleFactor(0.75)`
/// so AX users still get something legible without overflow. See GL-005 H2.
///
/// **Full-width mode (iPhone):** when `fullWidth` is true, a `GeometryReader`
/// reads the offered width and computes an exact per-day column width so the
/// grid fills its container edge to edge. The narrower KW column stays fixed at
/// `kwColumnWidth`; the 7 day columns share the remainder equally. The 6-row
/// grid height stays at `6 × 34 pt` (plus header/spacing) — this is a *mini*-
/// month, not a full-screen month view. The today / selected circle remains
/// 22 pt centred in each cell.
struct MiniMonthCalendar: View {
  let displayedMonth: Date
  @Binding var focusedDate: Date
  /// Per-day list of distinct event colours (max 3). The mini-month renders
  /// one dot per colour beneath the day number, matching Fantastical's
  /// "one dot per calendar" convention.
  let eventColorsByDay: [Date: [Color]]
  /// Per-day list of SF Symbol names for special-event icons (birthdays,
  /// anniversaries). Rendered alongside the colour dots, deduped per day.
  let specialIconsByDay: [Date: [String]]
  let locale: Locale
  let onMonthChange: (Int) -> Void
  /// When true (iPhone), day cells flex to fill the container width.
  /// When false (default, macOS sidebar), day cells stay at the fixed 30 pt
  /// width that suits the sidebar's narrow column.
  let fullWidth: Bool

  private let columnWidth: CGFloat = 30
  private let kwColumnWidth: CGFloat = 24

  /// Day-cell sizing scales with the layout mode. Sidebar stays dense (34 pt
  /// rows, 22 pt today circle, 12 pt day numbers); iPhone full-width gets a
  /// slightly larger Fantastical-style layout (38 pt rows, 28 pt circle,
  /// 16 pt day numbers) — tuned so the mini-month stays around 40 % of the
  /// iPhone screen height rather than half.
  private var dayHeight: CGFloat { fullWidth ? 38 : 34 }
  private var todayCircleSize: CGFloat { fullWidth ? 28 : 22 }
  private var dayNumberFontSize: CGFloat { fullWidth ? 16 : 12 }

  init(
    displayedMonth: Date,
    focusedDate: Binding<Date>,
    eventColorsByDay: [Date: [Color]],
    specialIconsByDay: [Date: [String]] = [:],
    locale: Locale,
    onMonthChange: @escaping (Int) -> Void,
    fullWidth: Bool = false
  ) {
    self.displayedMonth = displayedMonth
    self._focusedDate = focusedDate
    self.eventColorsByDay = eventColorsByDay
    self.specialIconsByDay = specialIconsByDay
    self.locale = locale
    self.onMonthChange = onMonthChange
    self.fullWidth = fullWidth
  }

  var body: some View {
    if fullWidth {
      // GL-006 Phase 1: iPhone takes the GeometryReader path so we can compute
      // an exact `dayColumnWidth` from the offered width. Trying to flow
      // `.frame(maxWidth: .infinity)` through nested HStacks is finicky in
      // SwiftUI — the explicit-pixel path is bulletproof.
      GeometryReader { proxy in
        gridBody(dayColumnWidth: max(0, (proxy.size.width - kwColumnWidth) / 7))
      }
      // Tuned for ~40 % of an iPhone 17 screen: largeTitle header (~40) +
      // spacing 4 + weekday strip (~14) + spacing 4 + 6 rows × 38 + 5 × 4
      // = ~310 pt. Buffer for AX text sizes.
      .frame(height: 330)
    } else {
      gridBody(dayColumnWidth: columnWidth)
    }
  }

  /// The actual grid body, parametrised on per-day column width so it can be
  /// fed either the sidebar's fixed 30 pt or a GeometryReader-computed flex
  /// width from the iPhone host.
  @ViewBuilder
  private func gridBody(dayColumnWidth: CGFloat) -> some View {
    VStack(spacing: fullWidth ? 4 : 6) {
      // Header — full-width gets a Fantastical-style large title with the
      // year accented in brand red; sidebar keeps the dense `.headline`.
      headerRow

      // Column labels (KW + Mo–So)
      // GL-005 H2: Day-cell heights stay pixel-locked (34 pt) so the 9 pt
      // labels must stay — `.minimumScaleFactor` lets Dynamic Type still scale
      // within the cell bounds for AX users.
      HStack(spacing: 0) {
        Text("KW")
          .font(.system(size: 9, weight: .semibold))
          .minimumScaleFactor(0.75)
          .lineLimit(1)
          .foregroundStyle(.tertiary)
          .frame(width: kwColumnWidth, alignment: .center)
        ForEach(weekdayLabels, id: \.self) { lbl in
          Text(lbl)
            .font(.system(size: 9, weight: .semibold))
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .foregroundStyle(.tertiary)
            .frame(width: dayColumnWidth, alignment: .center)
        }
      }

      // Week rows
      ForEach(monthWeeks, id: \.first) { week in
        if let first = week.first {
          let isCurrentWeek = week.contains { Calendar.current.isDateInToday($0) }
          HStack(spacing: 0) {
            Text("\(weekNumber(first))")
              .font(.system(size: 9))
              .minimumScaleFactor(0.75)
              .lineLimit(1)
              .foregroundStyle(.tertiary)
              .frame(width: kwColumnWidth, alignment: .center)
            ForEach(week, id: \.self) { day in
              dayCell(day)
                .frame(width: dayColumnWidth, height: dayHeight)
            }
          }
          // Fantastical-style subtle highlight on the row containing today —
          // a soft rounded rect using `.quinary` (Apple's lightest tinted fill).
          .background(
            RoundedRectangle(cornerRadius: 10)
              .fill(.quinary)
              .opacity(isCurrentWeek && fullWidth ? 1 : 0)
          )
        }
      }

      // GL-006 Phase 1.5e: visual drag-handle affordance — Fantastical shows
      // a small grey capsule under the mini-month to signal it can be
      // collapsed. We render the indicator now; the actual collapse gesture
      // is a follow-up (would toggle between 6-week and 1-week display).
      if fullWidth {
        Capsule()
          .fill(.tertiary)
          .frame(width: 36, height: 4)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 4)
          .accessibilityHidden(true)
      }
    }
  }

  @ViewBuilder
  private func dayCell(_ day: Date) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let isSelected = cal.isDate(day, inSameDayAs: focusedDate) && !isToday
    let weekday = cal.component(.weekday, from: day)
    let isWeekend = weekday == 1 || weekday == 7
    // Up to 3 distinct event colours per day. Special icons (cake / heart)
    // are drawn AFTER the colour dots so they're always visible — they
    // override the cap so a day with 3 events + a birthday still shows the
    // cake. Total marker count is capped at 4 to keep the row from growing
    // wider than the day cell.
    let key = cal.startOfDay(for: day)
    let dotColors: [Color] = Array((eventColorsByDay[key] ?? []).prefix(3))
    let specialIcons: [String] = Array((specialIconsByDay[key] ?? []).prefix(4 - dotColors.count))

    VStack(spacing: 2) {
      ZStack {
        if isToday {
          Circle().fill(Color.accentColor).frame(width: todayCircleSize, height: todayCircleSize)
        } else if isSelected {
          Circle()
            .strokeBorder(Color.accentColor, lineWidth: 1.4)
            .frame(width: todayCircleSize, height: todayCircleSize)
        }
        // GL-005 H2 + GL-006 Phase 1.5: Day number stays pixel-locked because
        // the grid cell can't accept Dynamic-Type expansion without breaking
        // the 6-row × 7-col layout. `dayNumberFontSize` is 12 for sidebar /
        // 17 for iPhone full-width. `minimumScaleFactor` lets AX scales
        // shrink it within the cell.
        Text("\(cal.component(.day, from: day))")
          .font(.system(
            size: dayNumberFontSize,
            weight: isToday ? .bold : (fullWidth ? .medium : .regular)
          ))
          .minimumScaleFactor(0.75)
          .lineLimit(1)
          .foregroundStyle(dayNumberColor(
            isToday: isToday,
            isCurrentMonth: isCurrentMonth,
            isWeekend: isWeekend
          ))
      }
      HStack(alignment: .center, spacing: 2.5) {
        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, dotColor in
          Circle()
            // On the today cell the dots sit on top of an accent-coloured
            // circle backdrop — render in white so they're always visible.
            .fill(isToday ? Color.white : dotColor)
            .frame(width: 4, height: 4)
        }
        // GL-006 Phase 1.5f follow-up: special-day icons were 6 pt — too
        // small to read as a heart or cake; users saw them as "little
        // piles". Now 8 pt with an explicit 8 × 8 frame, vertically centred
        // against the 4 pt dots. On the today cell we drop to monochrome
        // white so the symbol stays visible on the accent backdrop;
        // otherwise we use multicolor (heart→red, cake→pink natural tint).
        ForEach(Array(specialIcons.enumerated()), id: \.offset) { _, iconName in
          Image(systemName: iconName)
            .font(.system(size: 8))
            .symbolRenderingMode(isToday ? .monochrome : .multicolor)
            .foregroundStyle(isToday ? Color.white : Color.brandRed)
            .frame(width: 8, height: 8)
        }
      }
      .frame(height: 8)
    }
    .contentShape(Rectangle())
    .onTapGesture { focusedDate = day }
  }

  private func dayNumberColor(isToday: Bool, isCurrentMonth: Bool, isWeekend: Bool) -> Color {
    if isToday { return .white }
    if !isCurrentMonth { return Color.secondary.opacity(0.45) }
    if isWeekend { return Color.secondary.opacity(0.85) }
    return .primary
  }

  // MARK: - Date helpers

  private var monthTitle: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "MMMM yyyy"
    return f.string(from: displayedMonth)
  }

  /// Month name only ("Mai") — used in the full-width header where the year
  /// is rendered separately in an accent colour.
  private var monthName: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "MMMM"
    return f.string(from: displayedMonth)
  }

  /// Year as a string ("2026").
  private var yearString: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "yyyy"
    return f.string(from: displayedMonth)
  }

  /// Header row — Fantastical-style large title with red year accent for
  /// `fullWidth`; the dense headline + small chevrons for the macOS sidebar.
  @ViewBuilder
  private var headerRow: some View {
    if fullWidth {
      HStack(spacing: 6) {
        HStack(spacing: 6) {
          Text(monthName)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(.primary)
          Text(yearString)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(Color.brandRed)
        }
        Spacer()
        Button { onMonthChange(-1) } label: {
          Image(systemName: "chevron.left")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vormonat")
        Button { onMonthChange(1) } label: {
          Image(systemName: "chevron.right")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Folgemonat")
      }
    } else {
      HStack(spacing: 4) {
        Text(monthTitle)
          .font(.headline)
        Spacer()
        Button { onMonthChange(-1) } label: {
          Image(systemName: "chevron.left")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .help("Vormonat")
        Button { onMonthChange(1) } label: {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .help("Folgemonat")
      }
    }
  }

  private var weekdayLabels: [String] {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "EEEEE"  // single-letter / short weekday
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    guard let ref = cal.date(from: DateComponents(year: 2026, month: 1, day: 5)) else {
      return ["M", "D", "M", "D", "F", "S", "S"]
    }
    return (0..<7).compactMap { offset in
      cal.date(byAdding: .day, value: offset, to: ref).map { d in
        // Use 2-letter shorter form
        let g = DateFormatter()
        g.locale = locale
        g.dateFormat = "EE"
        return g.string(from: d)
      }
    }
  }

  private var monthWeeks: [[Date]] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let comps = cal.dateComponents([.year, .month], from: displayedMonth)
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

  private func weekNumber(_ d: Date) -> Int {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    return cal.component(.weekOfYear, from: d)
  }
}
