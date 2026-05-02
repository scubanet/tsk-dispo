import SwiftUI

struct CalendarView: View {
    let user: CurrentUser
    @State private var store = AssignmentsStore()
    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "de_CH")
        c.firstWeekday = 2 // Montag
        return c
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                daysGrid
                Divider().padding(.top, 4)
                ScrollView { dayDetails.padding() }
            }
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Assignment.self) { AssignmentDetailView(assignment: $0) }
            .refreshable { await store.load(instructorId: user.id) }
            .task { await store.load(instructorId: user.id) }
        }
    }

    // MARK: – Month Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(visibleMonth, format: .dateTime.month(.wide).year().locale(Locale(identifier: "de_CH")))
                    .font(.title2.bold())
                if !cal.isDate(visibleMonth, equalTo: .now, toGranularity: .month) {
                    Button("Heute") {
                        withAnimation { visibleMonth = cal.startOfMonth(for: .now) }
                    }
                    .font(.caption)
                }
            }
            Spacer()
            Button { shiftMonth(+1) } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: – Weekday Header

    private var weekdayHeader: some View {
        let symbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: – Days Grid

    private var daysGrid: some View {
        let days = monthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    day: day,
                    isCurrentMonth: cal.isDate(day, equalTo: visibleMonth, toGranularity: .month),
                    isToday: cal.isDateInToday(day),
                    isSelected: selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false,
                    assignmentCount: assignmentCount(on: day)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { selectedDay = cal.isDate(day, inSameDayAs: selectedDay ?? .distantPast) ? nil : day }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: – Day Details (untere Hälfte)

    @ViewBuilder
    private var dayDetails: some View {
        let target = selectedDay
        let assignments = target.map { dayAssignments(on: $0) } ?? upcomingThisMonth()

        if let target {
            VStack(alignment: .leading, spacing: 10) {
                Text(target, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_CH")))
                    .font(.headline)
                if assignments.isEmpty {
                    Text("Keine Einsätze an diesem Tag.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } else {
                    ForEach(assignments) { a in
                        NavigationLink(value: a) { AssignmentCard(assignment: a, dateLabel: "Tag") }
                            .buttonStyle(.plain)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Anstehend in diesem Monat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if assignments.isEmpty {
                    Text("Keine weiteren Einsätze.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assignments) { a in
                        NavigationLink(value: a) {
                            AssignmentCard(
                                assignment: a,
                                dateLabel: a.course?.nextDateOnOrAfter(.now)
                                    .map { AppDate.relativeLabel($0) } ?? "—"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: – Helpers

    private func shiftMonth(_ delta: Int) {
        guard let new = cal.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        withAnimation { visibleMonth = cal.startOfMonth(for: new); selectedDay = nil }
    }

    private func monthDays() -> [Date] {
        // 6 Wochen × 7 Tage = 42 Zellen, beginnend Mo der ersten ISO-Woche dieses Monats.
        let monthStart = visibleMonth
        let weekday = cal.component(.weekday, from: monthStart)
        // Mo = firstWeekday (2). Wenn monthStart Mo ist → offset 0. Wenn So → offset 6.
        let offset = (weekday - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -offset, to: monthStart)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func dayAssignments(on day: Date) -> [Assignment] {
        store.assignments.filter { a in
            (a.course?.allDates ?? []).contains { cal.isDate($0, inSameDayAs: day) }
        }
    }

    private func assignmentCount(on day: Date) -> Int {
        dayAssignments(on: day).count
    }

    private func upcomingThisMonth() -> [Assignment] {
        let monthEnd = cal.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
        let today = cal.startOfDay(for: .now)
        return store.assignments
            .filter { a in
                (a.course?.allDates ?? []).contains { d in
                    let day = cal.startOfDay(for: d)
                    return day >= today && day < monthEnd
                }
            }
            .sorted {
                let na = $0.course?.nextDateOnOrAfter(.now) ?? .distantFuture
                let nb = $1.course?.nextDateOnOrAfter(.now) ?? .distantFuture
                return na < nb
            }
    }
}

// MARK: – Day Cell

private struct DayCell: View {
    let day: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let assignmentCount: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(Calendar.current.component(.day, from: day).description)
                .font(.system(.callout, design: .rounded).weight(isToday ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.15) : .clear))
                )
                .foregroundStyle(isSelected ? Color.white : textColor)

            // Assignment-Indikator
            if assignmentCount > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<min(assignmentCount, 3), id: \.self) { _ in
                        Circle().fill(Color.accentColor).frame(width: 4, height: 4)
                    }
                    if assignmentCount > 3 {
                        Text("+").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.accentColor)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer().frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return isCurrentMonth ? .primary : Color(.tertiaryLabel)
    }
}

// MARK: – Calendar extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
