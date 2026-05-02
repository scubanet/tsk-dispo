import SwiftUI

struct TodayView: View {
  let user: CurrentUser
  @State private var store = AssignmentsStore()

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          BrandHeader()

          // Greeting
          VStack(alignment: .leading, spacing: 4) {
            Text("Hi, \(user.firstName) 👋")
              .font(.largeTitle.bold())
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_CH")))
              .foregroundStyle(.secondary)
              .font(.subheadline)
          }
          .padding(.horizontal)

          contentSection
        }
        .padding(.bottom, 32)
      }
      .toolbar(.hidden, for: .navigationBar)
      .refreshable { await store.load(instructorId: user.id) }
      .task { await store.load(instructorId: user.id) }
    }
  }

  @ViewBuilder
  private var contentSection: some View {
    switch store.loadState {
    case .idle:
      loadingIndicator
    case .loading where store.assignments.isEmpty:
      loadingIndicator
    case .error:
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(.title)
          .foregroundStyle(.orange)
        Text(store.errorMessage ?? "Fehler beim Laden")
          .font(.callout)
          .foregroundStyle(.secondary)
        Button("Nochmal versuchen") {
          Task { await store.load(instructorId: user.id) }
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
    default:
      todayAndUpcoming
    }
  }

  private var loadingIndicator: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Lade Einsätze…").font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  private var todayAndUpcoming: some View {
    VStack(alignment: .leading, spacing: 24) {
      // Heute
      VStack(alignment: .leading, spacing: 10) {
        sectionHeader("Heute", count: store.today().count)
        if store.today().isEmpty {
          emptyHero(
            icon: "sun.max",
            title: "Heute keine Einsätze",
            subtitle: "Geniess deinen freien Tag."
          )
        } else {
          ForEach(store.today()) { assignment in
            NavigationLink(value: assignment) {
              AssignmentCard(assignment: assignment, dateLabel: "Heute")
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal)

      // Diese Woche
      let upcoming = store.upcomingWeek()
      if !upcoming.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          sectionHeader("Nächste 7 Tage", count: upcoming.count)
          ForEach(upcoming) { assignment in
            NavigationLink(value: assignment) {
              AssignmentCard(
                assignment: assignment,
                dateLabel: dateLabel(for: assignment)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
    }
    .navigationDestination(for: Assignment.self) { a in
      AssignmentDetailView(assignment: a)
    }
  }

  private func dateLabel(for assignment: Assignment) -> String {
    guard let next = assignment.course?.nextDateOnOrAfter(.now) else { return "—" }
    return AppDate.relativeLabel(next)
  }

  private func sectionHeader(_ title: String, count: Int) -> some View {
    HStack {
      Text(title.uppercased())
        .font(.caption.bold())
        .tracking(1)
        .foregroundStyle(.secondary)
      Spacer()
      Text("\(count)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.tertiary)
    }
  }

  private func emptyHero(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title)
        .foregroundStyle(.tertiary)
      Text(title).font(.headline)
      Text(subtitle).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
  }
}

// MARK: – AssignmentCard

struct AssignmentCard: View {
  let assignment: Assignment
  let dateLabel: String

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(dateLabel.uppercased())
          .font(.caption2.bold())
          .tracking(0.5)
          .foregroundStyle(Color.accentColor)
        Text(assignment.course?.courseType?.code ?? "—")
          .font(.caption2.monospaced())
          .foregroundStyle(.tertiary)
      }
      .frame(width: 70, alignment: .leading)

      VStack(alignment: .leading, spacing: 4) {
        Text(assignment.course?.title ?? "Kurs")
          .font(.subheadline.bold())
          .lineLimit(2)
        HStack(spacing: 6) {
          RoleBadge(role: assignment.role)
          if let status = assignment.course?.status, status != .confirmed {
            StatusChip(status: status)
          }
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption.bold())
        .foregroundStyle(.tertiary)
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }
}
